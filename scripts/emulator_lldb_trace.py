"""Diagnostic-only owned-child stack capture, imported by installed host LLDB.

No init files, online symbols, argument/local/register/environment dumps, core
files, attachment to unrelated processes or host security-policy changes. LLDB
changes scheduling and may normalize argv0; this is never motion/performance
acceptance. Readiness probes use only authored tiny executables, not an emulator.
"""
import hashlib
import json
import os
from pathlib import Path
import time
import lldb

def encode_bounded(state):
    """Keep the newest fault even when older stacks exhaust the byte cap."""
    while True:
        data=(json.dumps(state,indent=2)+'\n').encode()
        if len(data)<=32768:return data
        if len(state.get('faults',[]))<=1:raise RuntimeError('Last bounded fault report exceeds32KiB')
        state['faults'].pop(0)
        state['faultStacksDroppedForByteBound']=state.get('faultStacksDroppedForByteBound',0)+1


def observe(fd):
    # Anonymous inherited pipe: never a persisted argv/environment dump.
    with os.fdopen(fd, 'r') as stream:
        config=json.loads(stream.read(65536))
    real=Path(config['real']);output=Path(config['output'])
    if real.is_symlink() or not real.is_file():raise RuntimeError('Owned regular executable required')
    with real.open('rb') as binary:
        if hashlib.file_digest(binary,'sha256').hexdigest()!=config['binarySha256']:
            raise RuntimeError('Owned executable SHA changed')
    state={'schema':1,'diagnosticOnly':True,'acceptanceEligible':False,
        'scope':'Debugger alters scheduling; never normal motion/performance acceptance. Signal stops are delivered onward, not presumed fatal.',
        'binarySha256':config['binarySha256'],'faults':[],'sigsegvStopsObserved':0,
        'phase':'initializing','aslrDisabled':False,
        'argv0PreservationVerified':False,
        'argv0DiagnosticDifference':'Own-ELF smoke shows SBTarget.Launch normalizes argv0 to retained ELF path despite target.arg0; not equivalent to normal observer.'}
    def save():
        data=encode_bounded(state)
        tmp=output.with_suffix('.tmp');tmp.write_bytes(data);tmp.replace(output)
    save()
    debugger=lldb.debugger
    debugger.SetAsync(False)
    def setting(command):
        result=lldb.SBCommandReturnObject()
        debugger.GetCommandInterpreter().HandleCommand(command,result)
        if not result.Succeeded():raise RuntimeError('Required debugger setting unsupported')
    try:
        # No HOME init/pretty-printer/source script lookup, online symbol
        # download, shell launch, memory/register reads, locals or arguments.
        for command in ('settings set target.disable-aslr false',
                        'settings set target.load-script-from-symbol-file false',
                        'settings set symbols.enable-external-lookup false'):
            setting(command)
        target=debugger.CreateTarget(str(real))
        if not target.IsValid():raise RuntimeError('SDK debug target unavailable')
        debugger.SetSelectedTarget(target)
        error=lldb.SBDebugger.SetInternalVariable('target.arg0',config['argv0'],debugger.GetInstanceName())
        if error.Fail():raise RuntimeError('Exact owned SDK argv0 override unsupported')
        launch=target.GetLaunchInfo()
        launch.SetExecutableFile(lldb.SBFileSpec(str(real)),False)
        launch.SetArguments([config['argv0'],*config['arguments']],False)
        flags=launch.GetLaunchFlags() & ~lldb.eLaunchFlagDisableASLR & ~lldb.eLaunchFlagLaunchInTTY & ~lldb.eLaunchFlagShellExpandArguments
        launch.SetLaunchFlags(flags)
        # lldb.sh requires PYTHONHOME/LD_LIBRARY_PATH for its own runtime;
        # restore precisely those two original values for the SDK inferior.
        environment=dict(os.environ)
        for key,value in config['restoreDebuggerEnvironment'].items():
            if key not in ('PYTHONHOME','LD_LIBRARY_PATH','LLDB_DEBUGSERVER_PATH'):raise RuntimeError('Unexpected environment restore key')
            if value is None:environment.pop(key,None)
            else:environment[key]=value
        launch.SetEnvironmentEntries([key+'='+value for key,value in environment.items()],False)
        launch.SetWorkingDirectory(config['cwd'])
        launch.AddDuplicateFileAction(1,1);launch.AddDuplicateFileAction(2,2)
        error=lldb.SBError();process=target.Launch(launch,error)
        if error.Fail() or not process.IsValid():
            state.update(phase='launch-unavailable',launchErrorCode=error.GetError());save();return
        state.update(phase='observing',ownedInferiorPid=process.GetProcessID(),startEpochSeconds=time.time())
        signals=process.GetUnixSignals()
        for number in (11,7,4,6):
            signals.SetShouldStop(number,True)
            signals.SetShouldSuppress(number,False)
            signals.SetShouldNotify(number,False)
        save()
        while process.IsValid():
            status=process.GetState()
            if status in (lldb.eStateExited,lldb.eStateDetached,lldb.eStateInvalid):break
            if status in (lldb.eStateStopped,lldb.eStateCrashed):
                for thread in process:
                    if thread.GetStopReason()!=lldb.eStopReasonSignal or thread.GetStopReasonDataCount()<1:continue
                    if thread.GetStopReasonDataAtIndex(0)!=11:continue
                    state['sigsegvStopsObserved']+=1
                    frames=[]
                    for index in range(min(thread.GetNumFrames(),24)):
                        frame=thread.GetFrameAtIndex(index)
                        module=frame.GetModule()
                        base=module.GetObjectFileHeaderAddress().GetLoadAddress(target)
                        pc=frame.GetPC()
                        frames.append({'frame':index,'pc':pc,
                            'moduleOffset':pc-base if base!=lldb.LLDB_INVALID_ADDRESS and 0<=base<=pc else None,
                            'moduleUuid':(module.GetUUIDString() or '')[:80],
                            'function':(frame.GetFunctionName() or '<symbol unavailable>')[:80],
                            'module':(module.GetFileSpec().GetFilename() or '<module unavailable>')[:80]})
                    state['faults']=(state['faults']+[{'signal':11,'threadId':thread.GetThreadID(),
                        'signalStopNumber':state['sigsegvStopsObserved'],
                        'epochSeconds':time.time(),'frames':frames,'argumentsPrinted':False}])[-4:]
                    save()
                    break
                # The inferior receives the original signal. A legitimate
                # handler/probe can recover; do not kill on the first stop.
                error=process.Continue()
                if error.Fail():
                    state.update(phase='continue-unavailable',continueErrorCode=error.GetError());save();return
            else:
                state.update(phase='unexpected-debugger-state',debuggerState=int(status));save();return
        final=process.GetState()
        state.update(phase='finished',finalState=int(final),
            finalStateName=lldb.SBDebugger.StateAsCString(final),
            actualExitStatus=process.GetExitStatus(),
            actualExitDescription=(process.GetExitDescription() or '')[:500],endEpochSeconds=time.time(),
            finalSignalClassification='Not inferred: SBProcess may expose only numeric status and empty description; signal stops can be handled.')
        save()
    except Exception as error:
        state.update(phase='diagnostic-unavailable',errorCategory=type(error).__name__);save()
        # Never manipulate host ptrace policy, dump a core, or claim a fake
        # child status. Launcher integration must preserve this as unavailable.
