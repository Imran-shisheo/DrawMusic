#!/usr/bin/env python3
"""Bounded preinstalled-host-LLDB readiness. No installations or SDK launches."""
import hashlib
import json
import os
from pathlib import Path
import resource
import re
import shutil
import stat
import subprocess
import sys
import sysconfig
import tempfile

SCRIPT = Path(__file__).with_name('emulator_lldb_trace.py').resolve()
OUTPUT = Path('work/ui-capture-inspect-debugger')
PREAPPROVED = Path('/workspace/drawmusic-tools/swift-6.1.2/usr/bin')
TRUSTED = (Path('/usr/share/swift'),Path('/usr/local/swift'),Path('/opt/swift'),Path('/opt/hostedtoolcache/swift'))
FIXED = (Path('/usr/share/swift/usr/bin/lldb'),Path('/usr/local/swift/usr/bin/lldb'),Path('/opt/swift/usr/bin/lldb'),PREAPPROVED/'lldb')
REPORT_LIMIT=32768
FAKE = r'''
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/personality.h>
static volatile sig_atomic_t count=0;
static void handler(int n){count++;}
int main(int argc,char **argv){
  FILE *f=fopen(getenv("DOODIMO_FAKE_WITNESS"),"w");
  if(!f)return 90;
  fprintf(f,"{\"argv0\":\"%s\",\"sentinelMatches\":%s,\"aslrEnabled\":%s}\n",argv[0],
    !strcmp(getenv("DOODIMO_FAKE_SENTINEL"),"OWN_FAKE_SENTINEL")?"true":"false",
    (personality(0xffffffffUL)&ADDR_NO_RANDOMIZE)?"false":"true");fclose(f);
  if(argc>1 && !strcmp(argv[1],"handled")){signal(SIGSEGV,handler);for(int i=0;i<5;i++)raise(SIGSEGV);return count==5?0:9;}
  raise(SIGSEGV);return 7;
}
'''

def sha(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def write_report(path,value):
    if any(item.is_symlink() for item in (path,*path.parents)):
        raise ValueError('Readiness output symlink rejected')
    data=(json.dumps(value,indent=2)+'\n').encode()
    if len(data)>REPORT_LIMIT:raise ValueError('Readiness report exceeds32KiB')
    path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)

def trusted(path):
    path=Path(path)
    try:resolved=path.resolve(strict=True)
    except OSError:return False
    checkout=Path(__file__).resolve().parents[1]
    if resolved.is_relative_to(checkout):return False
    if resolved.parent==PREAPPROVED:return True # Existing explicitly approved cloud toolchain only.
    if not any(resolved.is_relative_to(root) for root in TRUSTED):return False
    workspace=os.environ.get('GITHUB_WORKSPACE')
    if workspace and resolved.is_relative_to(Path(workspace).resolve()):return False
    return True

def regular_executable(path):
    try:
        info=path.stat()
        if not stat.S_ISREG(info.st_mode) or not os.access(path,os.X_OK):return False
        with path.open('rb') as stream:return stream.read(4)==b'\x7fELF'
    except OSError:return False

def candidates():
    values=list(FIXED)
    swift=shutil.which('swift')
    if swift:
        parent=Path(swift).resolve().parent
        values.append(parent/'lldb')
    found=[]
    for path in values:
        if trusted(path) and regular_executable(path) and path.resolve() not in found:
            found.append(path.resolve())
    return found[:5]

def debugger_environment(binary,original):
    environment=dict(original)
    environment['LLDB_DEBUGSERVER_PATH']=str(binary.with_name('lldb-server'))
    # Use only this already running standard Python's existing shared library;
    # no download, package activation, HOME change or inferior env mutation.
    for directory in (Path(sys.base_prefix)/'lib',Path(sysconfig.get_config_var('LIBDIR') or '/nonexistent')):
        library=directory/f'libpython{sys.version_info.major}.{sys.version_info.minor}.so.1.0'
        if library.is_file():
            environment['LD_LIBRARY_PATH']=str(directory)+(':'+original['LD_LIBRARY_PATH'] if original.get('LD_LIBRARY_PATH') else '')
            break
    return environment

def run_bounded(arguments,*,environment,timeout=5,pass_fds=()):
    # Temporary stdout/stderr sinks prevent unbounded in-memory output and are
    # never uploaded. Only small status/marker fields leave readiness.
    with tempfile.TemporaryFile() as out,tempfile.TemporaryFile() as err:
        def no_core():resource.setrlimit(resource.RLIMIT_CORE,(0,0))
        process=subprocess.Popen(arguments,env=environment,stdout=out,stderr=err,
            pass_fds=pass_fds,preexec_fn=no_core)
        try:code=process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill();process.wait(timeout=3)
            return {'returncode':None,'error':'TimeoutExpired','stdout':''}
        out.seek(0);err.seek(0)
        return {'returncode':code,'stdout':out.read(4096).decode(errors='replace'),
                'stderr':err.read(4096).decode(errors='replace')}

def own_probe(binary,mode,root):
    real=root/'owned-readiness-elf';report=root/(mode+'.json');witness=root/(mode+'-witness.json')
    original={**os.environ,'DOODIMO_FAKE_WITNESS':str(witness),'DOODIMO_FAKE_SENTINEL':'OWN_FAKE_SENTINEL'}
    config={'real':str(real),'argv0':str(root/'owned-original-name'),'arguments':[mode],
        'output':str(report),'binarySha256':sha(real),'cwd':str(root),
        'restoreDebuggerEnvironment':{key:original.get(key) for key in ('PYTHONHOME','LD_LIBRARY_PATH','LLDB_DEBUGSERVER_PATH')}}
    readfd,writefd=os.pipe()
    try:
        payload=json.dumps(config).encode()
        if len(payload)>4096:raise ValueError('Owned probe control payload exceeds4KiB')
        os.write(writefd,payload);os.close(writefd);writefd=None
        result=run_bounded([str(binary),'--no-lldbinit','--batch',
            '-o','command script import '+str(SCRIPT),
            '-o',f'script emulator_lldb_trace.observe({readfd})','-o','quit'],
            environment=debugger_environment(binary,original),timeout=20,pass_fds=(readfd,))
    finally:
        os.close(readfd)
        if writefd is not None:os.close(writefd)
    if result.get('error'):return {'ready':False,'reason':result['error']}
    if not report.is_file() or report.is_symlink() or report.stat().st_size>REPORT_LIMIT:
        return {'ready':False,'reason':'MissingOrOversizedOwnProbeReport'}
    value=json.loads(report.read_text())
    if value.get('phase')!='finished':
        return {'ready':False,'reason':'OwnInferiorLaunchOrTraceUnavailable','phase':value.get('phase')}
    actual=json.loads(witness.read_text()) if witness.is_file() and witness.stat().st_size<=4096 else {}
    faults=value.get('faults',[])
    valid=(value.get('diagnosticOnly') is True and value.get('acceptanceEligible') is False and
        actual.get('sentinelMatches') is True and actual.get('aslrEnabled') is True and
        actual.get('argv0') in (str(real),config['argv0']) and len(faults)<=4 and
        all(len(item.get('frames',[]))<=24 for item in faults) and
        'OWN_FAKE_SENTINEL' not in report.read_text())
    if mode=='handled':valid=valid and value.get('actualExitStatus')==0 and value.get('sigsegvStopsObserved')==5 and len(faults)==4
    else:valid=valid and value.get('actualExitStatus')!=0 and value.get('sigsegvStopsObserved')==1 and len(faults)==1
    if valid:write_report(OUTPUT/(mode+'.json'),value)
    return {'ready':bool(valid),'fixture':mode,'actualExitStatus':value.get('actualExitStatus'),
        'actualExitDescription':value.get('actualExitDescription'),
        'stops':value.get('sigsegvStopsObserved'),'storedFaults':len(faults),
        'storedFrameCounts':[len(item.get('frames',[])) for item in faults],
        'argv0MatchesOriginal':actual.get('argv0')==config['argv0'],
        'argv0MatchesRetainedElf':actual.get('argv0')==str(real),
        'aslrEnabled':actual.get('aslrEnabled'),'sentinelMatches':actual.get('sentinelMatches'),
        'reportBytes':report.stat().st_size,'reportSha256':sha(report)}

def readiness():
    result={'schema':1,'diagnosticOnly':True,'acceptanceEligible':False,'ready':False,
        'scope':'Preinstalled matching host LLDB/server plus authored tiny ELF only. No SDK/emulator launch, installation or ptrace-policy change. Debugger timings never establish product motion/performance.',
        'argv0DifferenceAcceptedDiagnosticOnly':True,'attempts':[]}
    if os.environ.get('GITHUB_ACTIONS')!='true' or os.environ.get('RUNNER_OS')!='Linux':
        result['reason']='DisposableLinuxActionsOnly';return result
    compiler=Path('/usr/bin/cc')
    if not compiler.is_file() or not compiler.resolve().is_relative_to(Path('/usr/bin')):
        result['reason']='PreinstalledStandardCCompilerUnavailable';return result
    for binary in candidates():
        server=binary.with_name('lldb-server')
        attempt={'debugger':str(binary),'server':str(server)};result['attempts'].append(attempt)
        if not trusted(server) or not regular_executable(server):
            attempt['reason']='MatchingPreinstalledHostServerUnavailable';continue
        environment=debugger_environment(binary,os.environ)
        versions=[]
        for arguments in ([str(binary),'--no-lldbinit','--version'],[str(server),'version']):
            version=run_bounded(arguments,environment=environment)
            match=re.search(r'lldb version ([0-9][0-9A-Za-z.+_-]{0,60})',version.get('stdout','')+'\n'+version.get('stderr',''))
            versions.append(match.group(1) if version.get('returncode')==0 and match else None)
        if versions[0] is None or versions[0]!=versions[1]:
            attempt['reason']='DebuggerServerVersionMismatchOrUnavailable';continue
        attempt['matchingVersion']=versions[0]
        smoke=run_bounded([str(binary),'--no-lldbinit','--batch','-o',
            'script import lldb; print("DOODIMO_HOST_API_READY",hasattr(lldb,"SBLaunchInfo"),hasattr(lldb,"SBProcess"))','-o','quit'],environment=environment)
        if smoke.get('returncode')!=0 or 'DOODIMO_HOST_API_READY True True' not in smoke.get('stdout',''):
            attempt['reason']='HostPythonApiUnavailable';continue
        attempt.update(debuggerSha256=sha(binary),serverSha256=sha(server))
        with tempfile.TemporaryDirectory(prefix='doodimo-host-debugger-readiness-') as tmp:
            root=Path(tmp);(root/'fake.c').write_text(FAKE)
            compiled=run_bounded([str(compiler),'-g','-o',str(root/'owned-readiness-elf'),str(root/'fake.c')],environment=os.environ,timeout=15)
            if compiled.get('returncode')!=0:
                attempt['reason']='AuthoredFixtureCompilationUnavailable';continue
            attempt['handled']=own_probe(binary,'handled',root)
            if not attempt['handled']['ready']:
                attempt['reason']='OwnHandledSignalProbeUnavailable'
                result['reason']='SelectedHostDebuggerOwnProbeUnavailable';return result
            attempt['fatal']=own_probe(binary,'fatal',root)
            if not attempt['fatal']['ready']:
                attempt['reason']='OwnFatalSignalProbeUnavailable'
                result['reason']='SelectedHostDebuggerOwnProbeUnavailable';return result
        result.update(ready=True,reason='OwnHandledAndFatalHostProbesVerified',selectedDebugger=str(binary))
        return result
    result['reason']='NoVerifiedPreinstalledMatchingHostDebugger'
    return result

def main():
    try:result=readiness()
    except Exception as error:
        result={'schema':1,'diagnosticOnly':True,'acceptanceEligible':False,'ready':False,
            'reason':'ReadinessUnavailable','errorCategory':type(error).__name__}
    write_report(OUTPUT/'readiness.json',result)
    print('HOST_DEBUGGER_READINESS '+json.dumps(result,sort_keys=True))
    # Unavailable is an honest report, never permission to silently trace or
    # replace the accepted observer. A later trace must require ready:true.

if __name__=='__main__':main()
