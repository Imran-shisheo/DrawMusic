"""Fixed-file, read-only observer inspection; never executes SDK or commands."""
import hashlib
import json
import math
from pathlib import Path
import re
import stat

JSON_LIMIT = 32768
HEAD_LIMIT = 65536
TAIL_LIMIT = 262144
DB_LIMIT = 8 * 1024 * 1024
HASH = re.compile(r'[0-9a-f]{64}')
DB_PATH = re.compile(r'/tmp/android-runner/emu-crash-[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.db')
DB_FILE = re.compile(r'crash-db/emu-crash-[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.db(?:/[A-Za-z0-9_.-]{1,120}){0,4}')
SIGNALS = re.compile(r'crash|fatal|error|exception|signal|segfault|qemu|abort|killed|out.of.memory|database|exit', re.I)
SENSITIVE = re.compile(r'UI_CAPTURE_TOKEN=|authorization\s*[:=]|(?:api[_-]?key|access[_-]?token|secret|password)\s*[:=]|\b(?:argv|environment)\s*[:=]', re.I)
STATES = {'launching','running','child-exited','exited','observer-error'}


def read_file(root, relative, limit):
    if root.is_symlink(): raise ValueError('Observer artifact root symlink rejected')
    current = root
    for part in relative.parts:
        if part in ('.','..') or not part: raise ValueError('Observer relative path rejected')
        current = current/part
        if current.is_symlink(): raise ValueError('Observer artifact symlink rejected')
    if not current.exists(): return None
    info=current.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_size>limit:
        raise ValueError('Observer file is not bounded regular evidence: '+str(relative))
    if not current.resolve().is_relative_to(root.resolve()):
        raise ValueError('Observer artifact escaped fixed root')
    return current.read_bytes()


def integer(value, maximum=2**63-1):
    return type(value) is int and 0 <= value <= maximum


def timestamp(value):
    return type(value) in (int,float) and math.isfinite(value) and value>=0


def hashes(value):
    return all(isinstance(value.get(key),str) and HASH.fullmatch(value[key])
               for key in ('binarySha256','observerSha256'))


def inspect_observer(root, relative, emit=print):
    """Only callers' two fixed observer locations; no request-selected paths."""
    if relative not in (Path('emulator-process'),Path('work/runtime-output/emulator-process')):
        raise ValueError('Unknown fixed observer location')
    folder=root/relative
    if folder.is_symlink(): raise ValueError('Observer folder symlink rejected')
    values={}; metadata={}; total=0; found=0; missing=[]
    for name in ('installation.json','lifecycle.json','collection.json','crash-database.json'):
        data=read_file(root,relative/name,JSON_LIMIT)
        if data is None:
            missing.append(name);continue
        value=json.loads(data)
        if not isinstance(value,dict):raise ValueError('Observer manifest must be an object')
        values[name]=value; total+=len(data);found+=1
        metadata[name]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
    summary={'status':'UNACCEPTED_DIAGNOSTIC_ONLY','file':str(relative), 'manifestFiles':metadata,
        'missing':missing,
        'scope':'Stored owned SDK-child observation only. Launcher exit is not presumed QEMU exit; no inferred OOM, SIGPIPE cause, repairs or physical/performance acceptance.'}
    install=values.get('installation.json')
    if install is not None:
        if type(install.get('schema')) is not int or install['schema']!=1 or install.get('installed') is not True or not hashes(install):
            raise ValueError('Malformed observer installation identity')
        summary['installation']={key:install[key] for key in ('schema','installed','binarySha256','observerSha256')}
    lifecycle=values.get('lifecycle.json')
    if lifecycle is not None:
        if type(lifecycle.get('schema')) is not int or lifecycle['schema']!=1 or lifecycle.get('state') not in STATES or not hashes(lifecycle):
            raise ValueError('Malformed observer lifecycle state/identity')
        if install is not None and any(lifecycle[key]!=install[key] for key in ('binarySha256','observerSha256')):
            raise ValueError('Observer binary/script identity differs across original manifests')
        for key in ('wrapperPid','childPid'):
            if key in lifecycle and (not integer(lifecycle[key]) or lifecycle[key]==0):raise ValueError('Invalid observed PID')
        for key in ('startEpochSeconds','startMonotonicSeconds','childExitEpochSeconds','endEpochSeconds'):
            if key in lifecycle and not timestamp(lifecycle[key]):raise ValueError('Invalid observer clock')
        if lifecycle.get('childStartTicks') is not None and not re.fullmatch(r'[0-9]{1,30}',str(lifecycle['childStartTicks'])):
            raise ValueError('Invalid observed process start identity')
        code=lifecycle.get('childReturncode')
        if code is not None and (type(code) is not int or not -64<=code<=255):raise ValueError('Invalid observed return code')
        if lifecycle['state'] in ('child-exited','exited') and code is None:raise ValueError('Exited launcher lacks original child status')
        if code is not None and lifecycle.get('childTerminationSignal')!=(-code if code<0 else None):
            raise ValueError('Child signal does not match actual subprocess returncode')
        names=lifecycle.get('observedExecutableNames',[])
        if not isinstance(names,list) or len(names)>4 or any(not isinstance(name,str) or not re.fullmatch(r'[A-Za-z0-9_.+-]{1,80}',name) for name in names):
            raise ValueError('Unbounded observer executable names')
        paths=lifecycle.get('reportedCrashDbPaths',[])
        if not isinstance(paths,list) or len(paths)>2 or any(not isinstance(path,str) or not DB_PATH.fullmatch(path) for path in paths):
            raise ValueError('Non-scoped SDK crash database path')
        signals=lifecycle.get('wrapperSignals',[])
        if not isinstance(signals,list) or len(signals)>16:raise ValueError('Unbounded wrapper signals')
        clean_signals=[]
        for item in signals:
            if (not isinstance(item,dict) or not integer(item.get('signal'),64) or not item['signal'] or
                not timestamp(item.get('epochSeconds')) or type(item.get('forwardedToVerifiedChild')) is not bool):
                raise ValueError('Malformed original wrapper signal')
            clean_signals.append({key:item[key] for key in ('signal','epochSeconds','forwardedToVerifiedChild')})
        summary['lifecycle']={key:lifecycle[key] for key in (
            'schema','state','binarySha256','observerSha256','wrapperPid','childPid','childStartTicks',
            'startEpochSeconds','startMonotonicSeconds','childExitEpochSeconds','endEpochSeconds',
            'childReturncode','childTerminationSignal','drainsComplete','observerError') if key in lifecycle}
        # Error class only, never arbitrary exception text/argv/environment.
        if 'observerError' in lifecycle and (not isinstance(lifecycle['observerError'],str) or not re.fullmatch(r'[A-Za-z]{1,80}',lifecycle['observerError'])):
            raise ValueError('Invalid observer error category')
        if 'drainsComplete' in lifecycle and type(lifecycle['drainsComplete']) is not bool:raise ValueError('Invalid drain state')
        summary['lifecycle'].update(observedExecutableNames=names,reportedCrashDbPaths=paths,wrapperSignals=clean_signals)
    collection=values.get('collection.json')
    if collection is not None:
        if (type(collection.get('schema')) is not int or collection['schema']!=1 or collection.get('observedState') not in STATES|{'no-observer-manifest'} or
            type(collection.get('observerFinished')) is not bool or type(collection.get('drainsComplete')) is not bool or
            collection['observerFinished']!=(collection['observedState']=='exited')):
            raise ValueError('Malformed observer collection state')
        summary['collection']={key:collection[key] for key in ('schema','observedState','observerFinished','drainsComplete')}
    logs=[]
    for stream in ('stdout','stderr'):
        witness=lifecycle.get(stream) if lifecycle else None
        if witness is not None:
            if (not isinstance(witness,dict) or not integer(witness.get('bytesDrained')) or
                not integer(witness.get('headBytes'),HEAD_LIMIT) or not integer(witness.get('tailBytes'),TAIL_LIMIT) or
                type(witness.get('eof')) is not bool or type(witness.get('truncated')) is not bool or
                witness['truncated']!=(witness['bytesDrained']>HEAD_LIMIT+TAIL_LIMIT)):
                raise ValueError('Invalid original drain byte witness')
            errors=witness.get('logWriteOrReadErrors',[])
            if not isinstance(errors,list) or len(errors)>4 or any(not isinstance(item,str) or not re.fullmatch(r'[A-Za-z]{1,80}',item) for item in errors):
                raise ValueError('Invalid stream error categories')
        for position,limit in (('head',HEAD_LIMIT),('tail',TAIL_LIMIT)):
            name=f'{stream}-{position}.log';data=read_file(root,relative/name,limit)
            if data is None:
                missing.append(name);continue
            total+=len(data);found+=1
            if witness is not None and len(data)!=witness[position+'Bytes']:
                raise ValueError('Original observer log length differs from drain witness')
            lines=data.decode('utf-8',errors='replace').splitlines()
            selected=[line for line in lines if SIGNALS.search(line)][-16:]+lines[-20:]
            safe=[];redacted=0
            for line in selected:
                if SENSITIVE.search(line):redacted+=1;continue
                safe.append(re.sub(r'DrawMusicCapture-[0-9a-f]{32}-','DrawMusicCapture-[redacted]-',line[:500]))
            logs.append({'file':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),
                'originalDrainWitness':({key:witness[key] for key in ('bytesDrained','headBytes','tailBytes','eof','truncated')}|
                    {'logWriteOrReadErrors':witness.get('logWriteOrReadErrors',[])} if witness else None),
                'redactedSelectedLines':redacted,'boundedSignalAndTailLines':safe})
    database=values.get('crash-database.json')
    if database is not None:
        files=database.get('files'); skipped=database.get('skipped')
        if (database.get('maxFiles')!=8 or database.get('maxTotalBytes')!=DB_LIMIT or
            not isinstance(files,list) or len(files)>8 or not isinstance(skipped,list) or len(skipped)>128 or
            type(database.get('partialOrUnavailable')) is not bool):raise ValueError('Invalid bounded crash database manifest')
        clean_files=[];db_total=0;unique=set();db_roots=set()
        for item in files:
            if (not isinstance(item,dict) or not isinstance(item.get('file'),str) or not DB_FILE.fullmatch(item['file']) or
                any(part in ('.','..') for part in Path(item['file']).parts) or item['file'] in unique or
                not integer(item.get('bytes'),DB_LIMIT) or not isinstance(item.get('sha256'),str) or not HASH.fullmatch(item['sha256'])):
                raise ValueError('Crash database file manifest path/hash/length rejected')
            unique.add(item['file']);db_total+=item['bytes']
            db_roots.add(Path(item['file']).parts[1])
            if len(db_roots)>1:raise ValueError('Only one exact SDK database may be retained')
            if lifecycle is not None and Path(item['file']).parts[1] not in {Path(path).name for path in lifecycle.get('reportedCrashDbPaths',[])}:
                raise ValueError('Retained database was not reported by the actual SDK child')
            if db_total>DB_LIMIT:raise ValueError('Crash database total byte bound exceeded')
            data=read_file(root,relative/item['file'],DB_LIMIT)
            if data is None:
                verified=False;missing.append(item['file'])
            else:
                if len(data)!=item['bytes'] or hashlib.sha256(data).hexdigest()!=item['sha256']:
                    raise ValueError('Original retained crash database bytes/SHA differ')
                verified=True
            clean_files.append({key:item[key] for key in ('file','bytes','sha256')}|{'originalBytesVerified':verified})
        if database.get('retainedBytes')!=db_total:raise ValueError('Crash database retained byte total differs')
        if database['partialOrUnavailable']!=bool(skipped):raise ValueError('Crash database partial flag differs from original skip outcomes')
        clean_skipped=[]
        for item in skipped:
            if not isinstance(item,dict) or not isinstance(item.get('reason'),str) or not re.fullmatch(r'[A-Za-z]{1,80}',item['reason']):
                raise ValueError('Invalid crash database skip category')
            entry={'reason':item['reason']}
            if 'bytes' in item:
                if not integer(item['bytes']):raise ValueError('Invalid skipped database byte count')
                entry['bytes']=item['bytes']
            clean_skipped.append(entry)
        summary['crashDatabase']={'files':clean_files,'skipped':clean_skipped,'retainedBytes':db_total,
            'partialOrUnavailable':database['partialOrUnavailable'], 'rawBinaryOutput':False}
    summary['logs']=logs
    summary['partialOrMissing']=(bool(missing) or lifecycle is None or lifecycle.get('state')!='exited' or
        lifecycle.get('drainsComplete') is not True or collection is None or not collection.get('observerFinished') or
        any((entry['originalDrainWitness'] or {}).get('logWriteOrReadErrors') for entry in logs) or
        database is None or database.get('partialOrUnavailable') is True)
    emit('EMULATOR_PROCESS_DIAGNOSTIC '+json.dumps(summary,sort_keys=True))
    return {'files':found,'textBytes':total}
