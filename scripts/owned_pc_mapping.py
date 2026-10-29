"""Bounded metadata for ONE already-owned stopped inferior's fault PC.

Never dumps maps, paths, process memory, registers, arguments or environment.
Filesystem fingerprints identify a verified backing ELF file, not the cause of
the fault or proof that its loaded instructions are intact.
"""
import hashlib
import os
from pathlib import Path
import re
import stat

PROC_ROOT=Path('/proc')
MAPS_LIMIT=2*1024*1024
ROWS_LIMIT=16384
ELF_LIMIT=32*1024*1024
ROW=re.compile(r'^([0-9a-fA-F]{1,16})-([0-9a-fA-F]{1,16})\s+([rwxps-]{4})\s+([0-9a-fA-F]{1,16})\s+([0-9a-fA-F]{1,8}):([0-9a-fA-F]{1,8})\s+(\d{1,20})(?:\s+(.*))?$')

def backing_elf(path,*,trusted_roots,device,inode):
    """Hash only a bounded regular trusted ELF matching the kernel map inode."""
    if not path.is_absolute() or '..' in path.parts:return {'status':'NonTrustedMappedPath'}
    if not any(path.is_relative_to(root) for root in trusted_roots):return {'status':'NonTrustedMappedPath'}
    if any(part.is_symlink() for part in (path,*path.parents)):return {'status':'BackingFileSymlinkRejected'}
    try:
        descriptor=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
        with os.fdopen(descriptor,'rb') as stream:
            info=os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode):return {'status':'BackingFileNotRegular'}
            if (info.st_ino!=inode or (os.major(info.st_dev),os.minor(info.st_dev))!=device):
                return {'status':'BackingFileIdentityChanged'}
            if info.st_size>ELF_LIMIT:return {'status':'BackingElfExceedsFingerprintBound','bytes':info.st_size}
            header=stream.read(64)
            if (len(header)<52 or header[:4]!=b'\x7fELF' or header[4] not in (1,2) or
                header[5] not in (1,2) or header[6]!=1 or (header[4]==2 and len(header)<64)):
                return {'status':'BackingFileIsNotVerifiedElf'}
            value=hashlib.sha256(header);read=len(header)
            while True:
                block=stream.read(min(65536,ELF_LIMIT-read+1))
                if not block:break
                read+=len(block)
                if read>ELF_LIMIT:return {'status':'BackingFileChangedOrExceedsBound'}
                value.update(block)
            after=os.fstat(stream.fileno())
            if (info.st_size,info.st_mtime_ns)!=(after.st_size,after.st_mtime_ns) or read!=info.st_size:
                return {'status':'BackingFileChangedDuringRead'}
        return {'status':'VerifiedBackingElf','bytes':read,'sha256':value.hexdigest(),
            'buildIdStatus':'NotCollectedNoObjectParser'}
    except OSError as error:return {'status':'BackingFileUnavailable','errorCategory':type(error).__name__}

def inspect_owned_pc(current_pid,owned_pid,pc,*,trusted_roots):
    result={'scope':'Only owned stopped PID exe basename and PC-containing map metadata; no complete maps or memory output.',
            'rangeMatch':False}
    if (type(current_pid) is not int or type(owned_pid) is not int or current_pid<=0 or
        current_pid!=owned_pid or type(pc) is not int or not 0<=pc<2**64):
        return result|{'status':'OwnedPidOrPcMismatch'}
    folder=PROC_ROOT/str(owned_pid)
    if folder.is_symlink():return result|{'status':'OwnedProcDirectorySymlinkRejected'}
    try:result['executableBasename']=Path(os.readlink(folder/'exe')).name[:80]
    except OSError as error:result['executableStatus']=type(error).__name__
    maps=folder/'maps'
    try:
        if maps.is_symlink():return result|{'status':'MapsSymlinkRejected'}
        descriptor=os.open(maps,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
        with os.fdopen(descriptor,'rb') as stream:
            info=os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode):return result|{'status':'MapsNotRegular'}
            if info.st_size>MAPS_LIMIT:return result|{'status':'MapsExceedsReadBound'}
            data=stream.read(MAPS_LIMIT)
    except OSError as error:return result|{'status':'MapsUnavailable','errorCategory':type(error).__name__}
    rows=data.decode('utf-8',errors='replace').splitlines()
    complete=len(data)<MAPS_LIMIT and len(rows)<=ROWS_LIMIT
    if len(data)==MAPS_LIMIT and not data.endswith(b'\n'):rows=rows[:-1]
    files=set();match=None
    for line in rows[:ROWS_LIMIT]:
        item=ROW.fullmatch(line)
        if item is None:continue
        start,end,permissions,offset,major,minor,inode,path=item.groups()
        start,end,offset=int(start,16),int(end,16),int(offset,16)
        if start>=end:continue
        if path and path.startswith('/'):files.add(path)
        if start<=pc<end:
            if match is not None:return result|{'status':'AmbiguousContainingMaps'}
            match=(permissions,offset,pc-start+offset,(int(major,16),int(minor,16)),int(inode),path)
    result.update(mapsBytesInspected=len(data),mapsRowsInspected=min(len(rows),ROWS_LIMIT),
        mapsComplete=complete,mappedFileCount=len(files))
    if match is None:return result|{'status':'PcNotMapped' if complete else 'PcNotFoundWithinBound'}
    permissions,offset,relative,device,inode,path=match
    result.update(rangeMatch=True,permissions=permissions,mappingFileOffset=offset,pcFileOffset=relative)
    if not path or not path.startswith('/'):
        return result|{'status':'AnonymousOrSpecialMapping','mappingBasename':None}
    result['mappingBasename']=Path(path).name[:80]
    if path.endswith(' (deleted)'):return result|{'status':'DeletedMappedFile'}
    result.update(status='MappedPath',backingFile=backing_elf(Path(path),trusted_roots=trusted_roots,device=device,inode=inode))
    return result
