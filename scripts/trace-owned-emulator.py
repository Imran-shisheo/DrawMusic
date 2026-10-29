#!/usr/bin/env python3
"""Explicit diagnostic-only SDK wrapper. Never installs tools or changes policy.

Action prelaunch: DRAWMUSIC_EMULATOR_TRACE_DIAGNOSTIC=1 python3 scripts/trace-owned-emulator.py install
After Action teardown: same explicit flag, command `collect` (read-only <=10s).
The flag must remain in the Action environment for its launcher invocation.
Normal observer/app workflows do not opt into this tool. LLDB argv0 changes and
raw exit-status ambiguity are intentional disclosed diagnostic differences.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import resource
import signal
import subprocess
import sys
import threading
import time

EXPECTED_SDK_SHA='27e9a8cbd545529ba2c1aca973e5bc060f50b36a68d2c03296b0162291a16b83'
OUTPUT=Path('work/ui-capture/emulator-lldb-trace')
READY_REPORT=Path('work/ui-capture-inspect-debugger/readiness.json')
SCRIPT=Path(__file__).resolve()
CONTROLLER=SCRIPT.with_name('emulator_lldb_trace.py')
spec=importlib.util.spec_from_file_location('owned_trace_readiness',SCRIPT.with_name('check-host-debugger-readiness.py'))
READY=importlib.util.module_from_spec(spec);spec.loader.exec_module(READY)
HEAD=65536
TAIL=262144

def gate():
    if (os.environ.get('GITHUB_ACTIONS')!='true' or os.environ.get('RUNNER_OS')!='Linux' or
        os.environ.get('DRAWMUSIC_EMULATOR_TRACE_DIAGNOSTIC')!='1'):
        raise RuntimeError('Explicit disposable Linux Actions diagnostic trace flag required')

def no_symlinks(path):
    if any(item.is_symlink() for item in (path,*path.parents)):
        raise ValueError('Diagnostic path symlink rejected')

def json_read(path):
    no_symlinks(path)
    if not path.is_file() or path.stat().st_size>32768:raise ValueError('Expected bounded regular diagnostic JSON')
    value=json.loads(path.read_text())
    if not isinstance(value,dict):raise ValueError('Expected diagnostic object')
    return value

def json_write(path,value):
    no_symlinks(path)
    data=(json.dumps(value,indent=2)+'\n').encode()
    if len(data)>32768:raise ValueError('Diagnostic lifecycle exceeds32KiB')
    tmp=path.with_name(path.name+f'.tmp-{os.getpid()}-{threading.get_ident()}')
    no_symlinks(tmp);tmp.write_bytes(data);tmp.replace(path)

def output_path():
    path=Path.cwd()/OUTPUT;no_symlinks(path);path.mkdir(parents=True,exist_ok=True);return path

def load_ready():
    value=json_read(Path.cwd()/READY_REPORT)
    if (value.get('schema')!=1 or value.get('ready') is not True or value.get('diagnosticOnly') is not True or
        value.get('acceptanceEligible') is not False):raise ValueError('Verified diagnostic-only host readiness required')
    binary=Path(value.get('selectedDebugger',''))
    server=binary.with_name('lldb-server')
    if not READY.trusted(binary) or not READY.trusted(server) or not READY.regular_executable(binary) or not READY.regular_executable(server):
        raise ValueError('Selected preinstalled host debugger/server is not trusted regular ELF')
    attempts=value.get('attempts',[])
    if not isinstance(attempts,list) or len(attempts)>5:raise ValueError('Readiness attempts rejected')
    selected=[item for item in attempts if isinstance(item,dict) and item.get('debugger')==str(binary)]
    if len(selected)!=1:raise ValueError('Exact selected readiness attempt required')
    selected=selected[0];version=selected.get('matchingVersion')
    if (not isinstance(version,str) or not version or len(version)>64 or selected.get('server')!=str(server) or
        selected.get('debuggerSha256')!=READY.sha(binary) or selected.get('serverSha256')!=READY.sha(server)):
        raise ValueError('Preinstalled debugger/server identity changed')
    for role in ('debugger','server'):
        checked=selected.get('versionChecks',{}).get(role,{})
        if checked.get('returncode')!=0 or checked.get('parsedVersion')!=version:
            raise ValueError('Original matching host version proof required')
    for mode,stops in (('handled',5),('fatal',1)):
        probe=selected.get(mode,{})
        if (probe.get('ready') is not True or probe.get('stops')!=stops or
            probe.get('aslrEnabled') is not True or probe.get('sentinelMatches') is not True or
            (mode=='handled' and probe.get('actualExitStatus')!=0) or
            (mode=='fatal' and (type(probe.get('actualExitStatus')) is not int or probe['actualExitStatus']==0))):
            raise ValueError('Original own handled/fatal ASLR/environment probes required')
    return {'binary':str(binary),'server':str(server),'version':version,
        'debuggerSha256':selected['debuggerSha256'],'serverSha256':selected['serverSha256'],
        'readinessReportSha256':READY.sha(Path.cwd()/READY_REPORT)}

def validate_sdk(path):
    no_symlinks(path)
    if not READY.regular_executable(path) or READY.sha(path)!=EXPECTED_SDK_SHA:
        raise ValueError('Selected SDK ELF differs from observed baseline SHA')

def install():
    gate();ready=load_ready()
    sdk=os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    if not sdk:raise RuntimeError('Selected Android SDK unavailable')
    original=Path(sdk).resolve(strict=True)/'emulator/emulator';validate_sdk(original)
    real=original.with_name('emulator.doodimo-lldb-original')
    config=original.with_name('emulator.doodimo-lldb-trace.json')
    temporary=original.with_name('emulator.doodimo-lldb-wrapper.tmp')
    for path in (real,config,temporary):
        if path.exists() or path.is_symlink():raise RuntimeError('Reserved diagnostic launcher path already exists; no overwrite')
    out=output_path()
    if (out/'installation.json').exists() or (out/'lifecycle.json').exists():raise RuntimeError('One diagnostic installation per runner only')
    state={'schema':1,'diagnosticOnly':True,'acceptanceEligible':False,
        'original':str(original),'real':str(real),'output':str(out),'sdkSha256':EXPECTED_SDK_SHA,
        'installerSha256':READY.sha(SCRIPT),'controllerSha256':READY.sha(CONTROLLER),**ready}
    json_write(config,state)
    temporary.write_text('#!/usr/bin/env python3\nimport os,sys\n'+
        f'os.execv(sys.executable,[sys.executable,{str(SCRIPT)!r},"launch",{str(config)!r},*sys.argv[1:]])\n')
    temporary.chmod(0o755);original.rename(real)
    try:temporary.replace(original)
    except Exception:real.rename(original);raise
    json_write(out/'installation.json',{key:state[key] for key in (
        'schema','diagnosticOnly','acceptanceEligible','sdkSha256','installerSha256','controllerSha256',
        'binary','server','version','debuggerSha256','serverSha256','readinessReportSha256')})

def identity(pid):
    try:return Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()[19]
    except (OSError,IndexError):return None

def forward_owned(process,start,number):
    if process.poll() is not None or start is None or identity(process.pid)!=start:return False
    try:process.send_signal(number);return True
    except ProcessLookupError:return False

def drain(stream,path,state,lock):
    name=path.name;tail=bytearray();seen=0;head_size=0;head=None;errors=[];eof=False;last=0
    def note(error):
        if len(errors)<4:errors.append(type(error).__name__)
    def save_tail():
        try:
            target=path.with_name(name+'-tail.log');no_symlinks(target);target.write_bytes(tail)
        except (OSError,ValueError) as error:note(error)
    try:
        try:
            target=path.with_name(name+'-head.log');no_symlinks(target);head=target.open('wb')
        except (OSError,ValueError) as error:note(error)
        while True:
            try:block=os.read(stream.fileno(),4096)
            except OSError as error:note(error);break
            if not block:eof=True;break
            seen+=len(block)
            if head is not None and head_size<HEAD:
                try:
                    part=block[:HEAD-head_size];head.write(part);head.flush();head_size+=len(part)
                except OSError as error:
                    note(error)
                    try:head.close()
                    except OSError:pass
                    head=None
            tail.extend(block);del tail[:-TAIL]
            if time.monotonic()-last>=1:save_tail();last=time.monotonic()
    finally:
        if head is not None:
            try:head.close()
            except OSError as error:note(error)
        save_tail()
        if eof:stream.close() # Writers are already gone; never close a live pipe.
        with lock:state[name]={'bytesDrained':seen,'headBytes':head_size,'tailBytes':len(tail),
            'eof':eof,'truncated':seen>HEAD+TAIL,'errors':errors}

def launch(config_path,arguments):
    gate();config_path=Path(config_path);config=json_read(config_path)
    real=Path(config['real']);original=Path(config['original']);out=Path(config['output'])
    if (real.name!='emulator.doodimo-lldb-original' or original.name!='emulator' or real.parent!=original.parent or
        config_path!=original.with_name('emulator.doodimo-lldb-trace.json') or out!=Path.cwd()/OUTPUT):
        raise ValueError('Exact diagnostic launcher/config/output identity required')
    validate_sdk(real)
    # SDK version/help/list requests are transparent, untraced normal execs.
    if not any(arg=='-avd' or arg.startswith('@') for arg in arguments):
        os.execve(real,[str(original),*arguments],os.environ)
    ready=load_ready()
    if any(config.get(key)!=value for key,value in ready.items()) or config.get('controllerSha256')!=READY.sha(CONTROLLER):
        raise ValueError('Reviewed readiness/controller identity changed after installation')
    no_symlinks(out)
    if (out/'lifecycle.json').exists():raise RuntimeError('Only one owned diagnostic AVD launch supported')
    state={'schema':1,'diagnosticOnly':True,'acceptanceEligible':False,'phase':'launching',
        'sdkSha256':EXPECTED_SDK_SHA,'controllerSha256':config['controllerSha256'],**ready,
        'wrapperPid':os.getpid(),'wrapperSignals':[],'startEpochSeconds':time.time(),
        'argv0Difference':'LLDB may normalize argv0 to retained ELF; options/backend preserved. Not normal observer equivalence.',
        'statusScope':'Debugger process exit and raw inferior LLDB status are separate; no natural SDK exit/signal or performance claim.'}
    lock=threading.RLock()
    def save():
        with lock:json_write(out/'lifecycle.json',state)
    save()
    payload={'real':str(real),'argv0':str(original),'arguments':arguments,'output':str(out/'faults.json'),
        'binarySha256':EXPECTED_SDK_SHA,'cwd':str(Path.cwd()),
        'restoreDebuggerEnvironment':{key:os.environ.get(key) for key in ('PYTHONHOME','LD_LIBRARY_PATH','LLDB_DEBUGSERVER_PATH')}}
    data=json.dumps(payload).encode()
    if len(data)>4096:raise ValueError('Bounded anonymous launch payload exceeds4KiB')
    readfd,writefd=os.pipe();process=None
    try:
        os.write(writefd,data);os.close(writefd);writefd=None
        def no_core():resource.setrlimit(resource.RLIMIT_CORE,(0,0))
        process=subprocess.Popen([ready['binary'],'--no-lldbinit','--batch',
            '-o','command script import '+str(CONTROLLER),
            '-o',f'script emulator_lldb_trace.observe({readfd})','-o','quit'],
            env=READY.debugger_environment(Path(ready['binary']),os.environ),pass_fds=(readfd,),
            stdout=subprocess.PIPE,stderr=subprocess.PIPE,preexec_fn=no_core)
    finally:
        os.close(readfd)
        if writefd is not None:os.close(writefd)
    start=identity(process.pid)
    def forward(number,frame):
        with lock:
            state['wrapperSignals']=(state['wrapperSignals']+[{'signal':number,'epochSeconds':time.time(),
                'forwardedToVerifiedOwnedDebugger':forward_owned(process,start,number)}])[-16:]
            save()
    old={number:signal.signal(number,forward) for number in (signal.SIGTERM,signal.SIGINT,signal.SIGHUP)}
    state.update(phase='debugger-running',ownedDebuggerPid=process.pid,ownedDebuggerStartTicks=start);save()
    threads=[threading.Thread(target=drain,args=(stream,out/name,state,lock),daemon=True)
        for stream,name in ((process.stdout,'stdout'),(process.stderr,'stderr'))]
    for thread in threads:thread.start()
    try:
        while True:
            try:code=process.wait(timeout=.5);break
            except subprocess.TimeoutExpired:save()
        state.update(phase='debugger-exited',debuggerReturncode=code,
            debuggerTerminationSignal=-code if code<0 else None,debuggerExitEpochSeconds=time.time());save()
        # Preserve inherited streams until EOF; never close a live descendant's
        # pipe to manufacture completion or signal unrelated host processes.
        while any(thread.is_alive() for thread in threads):
            for thread in threads:thread.join(timeout=.25)
            save()
        state.update(phase='finished',drainsComplete=all(state.get(name,{}).get('eof') is True for name in ('stdout','stderr')),
            endEpochSeconds=time.time());save()
        return code if code>=0 else 128-code
    finally:
        for number,handler in old.items():signal.signal(number,handler)

def collect():
    gate();out=output_path();deadline=time.monotonic()+10;value={}
    while True:
        if (out/'lifecycle.json').exists():
            value=json_read(out/'lifecycle.json')
            if value.get('phase')=='finished':break
        if time.monotonic()>=deadline:break
        time.sleep(.2)
    trace=json_read(out/'faults.json') if (out/'faults.json').exists() else {}
    json_write(out/'collection.json',{'schema':1,'diagnosticOnly':True,'acceptanceEligible':False,
        'observerPhase':value.get('phase','missing'),'debuggerFinished':value.get('phase')=='finished',
        'tracePhase':trace.get('phase','missing'),'traceBytes':(out/'faults.json').stat().st_size if trace else 0,
        'traceSha256':READY.sha(out/'faults.json') if trace else None,
        'scope':'At most10s read-only collection; no repairs/signals, raw LLDB status is not inferred natural QEMU termination.'})
    if trace:
        # Only the controller's fixed fault metadata is printable; never config,
        # arguments, environment, arbitrary JSON keys or raw console streams.
        summary={key:trace.get(key) for key in ('schema','diagnosticOnly','acceptanceEligible','phase','binarySha256','mappingHelperSha256','ownedInferiorPid','aslrDisabled','argv0PreservationVerified','sigsegvStopsObserved','actualExitStatus','finalStateName','finalSignalClassification')}
        summary['faults']=[{key:fault.get(key) for key in ('signal','signalStopNumber','threadId','argumentsPrinted')}|{'frames':[{key:frame.get(key) for key in ('frame','pc','function','module','moduleOffset','moduleUuid')} for frame in fault.get('frames',[])[:24]]} for fault in trace.get('faults',[])[:4]]
        for fault,source in zip(summary['faults'],trace.get('faults',[])[:4]):
            fault['ownedPidMatches']=source.get('ownedPidMatches')
            targets=source.get('targets',{})
            fault['targets']={role:{key:targets.get(role,{}).get(key) for key in ('executableBasename','moduleCount')}
                              for role in ('original','selected','process')}
            mapping=source.get('ownedPcMapping',{})
            fault['ownedPcMapping']={key:mapping.get(key) for key in ('status','rangeMatch','executableBasename','executableStatus','mapsBytesInspected','mapsRowsInspected','mapsComplete','mappedFileCount','permissions','mappingFileOffset','pcFileOffset','mappingBasename','errorCategory')}
            fault['ownedPcMapping']['backingFile']={key:mapping.get('backingFile',{}).get(key) for key in ('status','bytes','sha256','buildIdStatus','errorCategory')}
        print('SDK_FAULT_STACK_DIAGNOSTIC '+json.dumps(summary,sort_keys=True),flush=True)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='operation',required=True)
    sub.add_parser('install');sub.add_parser('collect')
    entry=sub.add_parser('launch');entry.add_argument('config');entry.add_argument('arguments',nargs=argparse.REMAINDER)
    args=parser.parse_args()
    if args.operation=='launch':return launch(args.config,args.arguments)
    globals()[args.operation]();return 0

if __name__=='__main__':sys.exit(main())
