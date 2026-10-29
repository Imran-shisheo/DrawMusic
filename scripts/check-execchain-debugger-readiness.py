#!/usr/bin/env python3
"""Prepared host21 exec/library/thread fixture. Never starts an SDK emulator."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('exec_fixture_owned_trace',HERE/'trace-owned-emulator.py')
TRACE=importlib.util.module_from_spec(spec);spec.loader.exec_module(TRACE)
READY=TRACE.READY
OUTPUT=Path('work/ui-capture-inspect-debugger')
SOURCES={
 'launcher.c':'#include <unistd.h>\nint main(){execl("./owned-worker","owned-worker",(char*)0);return 91;}\n',
 'worker.c':'#include <pthread.h>\nextern void owned_crash(void);\nvoid* owned_thread(void* x){owned_crash();return 0;}\nint main(){pthread_t t;pthread_create(&t,0,owned_thread,0);pthread_join(t,0);return 0;}\n',
 'crash.c':'__attribute__((noinline)) void owned_crash(void){volatile int *p=(int*)0;*p=3;}\n',
}

def run_fixture(host):
    with tempfile.TemporaryDirectory(prefix='doodimo-own-exec-readiness-') as tmp:
        root=Path(tmp)
        for name,source in SOURCES.items():(root/name).write_text(source)
        base=['/usr/bin/cc','-g','-O0','-fno-omit-frame-pointer','-Wl,--build-id=sha1']
        commands=([*base,'-shared','-fPIC','-o',str(root/'libownedcrash.so'),str(root/'crash.c')],
            [*base,'-pthread','-o',str(root/'owned-worker'),str(root/'worker.c'),'-L'+str(root),'-lownedcrash','-Wl,-rpath,$ORIGIN'],
            [*base,'-o',str(root/'owned-launcher'),str(root/'launcher.c')])
        for command in commands:
            result=READY.run_bounded(command,environment=os.environ,timeout=15)
            if result.get('returncode')!=0:raise RuntimeError('AuthoredExecFixtureCompilationUnavailable')
        real=root/'owned-launcher';output=root/'exec-trace.json'
        config={'real':str(real),'argv0':str(real),'arguments':[],'output':str(output),
            'binarySha256':READY.sha(real),'cwd':str(root),
            'restoreDebuggerEnvironment':{key:os.environ.get(key) for key in ('PYTHONHOME','LD_LIBRARY_PATH','LLDB_DEBUGSERVER_PATH')}}
        payload=json.dumps(config).encode()
        if len(payload)>4096:raise ValueError('Own fixture control payload too large')
        readfd,writefd=os.pipe()
        try:
            os.write(writefd,payload);os.close(writefd);writefd=None
            binary=Path(host['binary'])
            result=READY.run_bounded([str(binary),'--no-lldbinit','--batch','-o','command script import '+str(HERE/'emulator_lldb_trace.py'),
                '-o',f'script emulator_lldb_trace.observe({readfd})','-o','quit'],
                environment=READY.debugger_environment(binary,os.environ),timeout=20,pass_fds=(readfd,))
        finally:
            os.close(readfd)
            if writefd is not None:os.close(writefd)
        if not output.is_file() or output.is_symlink() or output.stat().st_size>32768:
            raise RuntimeError('OwnedExecFixtureReportUnavailable')
        value=json.loads(output.read_text())
        faults=value.get('faults',[]);fault=faults[-1] if faults else {}
        mapping=fault.get('ownedPcMapping',{});targets=fault.get('targets',{})
        frames=fault.get('frames',[])
        mapping_ok=(fault.get('ownedPidMatches') is True and mapping.get('rangeMatch') is True and
            mapping.get('mappingBasename')=='libownedcrash.so' and
            mapping.get('backingFile',{}).get('status')=='VerifiedBackingElf' and
            mapping['backingFile'].get('sha256')==READY.sha(root/'libownedcrash.so') and
            type(mapping.get('pcFileOffset')) is int and mapping['pcFileOffset']>=0)
        tracking_ok=(frames and frames[0].get('module')=='libownedcrash.so' and
            frames[0].get('moduleOffset') is not None and
            all(targets.get(key,{}).get('executableBasename')=='owned-worker' for key in ('original','selected','process')))
        READY.write_report(OUTPUT/'execchain-trace.json',value)
        return {'ready':bool(result.get('returncode')==0 and value.get('phase')=='finished' and
            value.get('sigsegvStopsObserved')==1 and mapping_ok and tracking_ok),
            'mappingVerified':bool(mapping_ok),'lldbExecTrackingObserved':bool(tracking_ok),
            'targets':targets,'mapping':mapping,'frameCount':len(frames),
            'actualExitStatus':value.get('actualExitStatus'),'actualExitDescription':value.get('actualExitDescription'),
            'traceBytes':output.stat().st_size,'traceSha256':READY.sha(output)}

def main():
    report={'schema':1,'diagnosticOnly':True,'acceptanceEligible':False,'ready':False,
        'scope':'Authored launcher execs worker; shared-library background-thread fault only. No SDK launch; no product acceptance.'}
    try:
        if os.environ.get('GITHUB_ACTIONS')!='true' or os.environ.get('RUNNER_OS')!='Linux':
            report['reason']='DisposableLinuxActionsOnly'
        else:
            host=TRACE.load_ready()
            if not host['version'].startswith('21.'):
                report.update(reason='VerifiedHost21Required',observedHostVersion=host['version'])
            else:
                report.update(hostVersion=host['version'],debuggerSha256=host['debuggerSha256'],
                    serverSha256=host['serverSha256'],fixture=run_fixture(host))
                report['ready']=report['fixture']['ready']
    except Exception as error:
        report.update(reason='ExecChainReadinessUnavailable',errorCategory=type(error).__name__)
    READY.write_report(OUTPUT/'execchain-readiness.json',report)
    print('HOST21_EXECCHAIN_READINESS '+json.dumps(report,sort_keys=True))

if __name__=='__main__':main()
