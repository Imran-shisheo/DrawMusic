#!/usr/bin/env python3
"""Fixed proc/ELF metadata safety fakes; never reads another live process."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import owned_pc_mapping as module

@unittest.skipUnless(shutil.which('cc'),'Authored ELF fixture needs the standard compiler')
class OwnedPcMappingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build=tempfile.TemporaryDirectory();root=Path(cls.build.name)
        (root/'own.c').write_text('int main(void){return 0;}\n');cls.elf=root/'owned-elf'
        subprocess.run(['/usr/bin/cc','-o',str(cls.elf),str(root/'own.c')],check=True,capture_output=True)
    @classmethod
    def tearDownClass(cls):cls.build.cleanup()
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.proc=self.root/'proc';self.folder=self.proc/'123';self.folder.mkdir(parents=True)
        self.binary=self.root/'libowned.so';shutil.copy2(self.elf,self.binary)
        (self.folder/'exe').symlink_to(self.binary)
        self.maps=self.folder/'maps';self.maps.write_text(self.row(self.binary))
        own=patch.object(module,'PROC_ROOT',self.proc);own.start();self.addCleanup(own.stop)
    def row(self,path,*,offset=0,inode=None):
        info=path.stat() if not str(path).endswith(' (deleted)') else self.binary.stat()
        return f'1000-3000 r-xp {offset:08x} {os.major(info.st_dev):02x}:{os.minor(info.st_dev):02x} {info.st_ino if inode is None else inode} {path}\n'
    def inspect(self,pc=0x1123,roots=None):
        return module.inspect_owned_pc(123,123,pc,trusted_roots=roots or (self.root,))

    def test_exact_range_fileoffset_and_verified_elf_hash_without_path_or_maps_dump(self):
        self.maps.write_text(self.row(self.binary,offset=0x2000))
        value=self.inspect();self.assertTrue(value['rangeMatch'])
        self.assertEqual(value['pcFileOffset'],0x2123)
        self.assertEqual(value['mappingBasename'],'libowned.so')
        self.assertEqual(value['permissions'],'r-xp')
        self.assertEqual(value['backingFile']['sha256'],hashlib.sha256(self.binary.read_bytes()).hexdigest())
        self.assertNotIn(str(self.root),str(value));self.assertNotIn('1000-3000',str(value))

    def test_pid_mismatch_never_opens_proc_and_unmapped_pc_has_no_module_guess(self):
        with patch.object(module.os,'open') as opened:
            value=module.inspect_owned_pc(124,123,0x1123,trusted_roots=(self.root,))
            opened.assert_not_called();self.assertEqual(value['status'],'OwnedPidOrPcMismatch')
        value=self.inspect(0x4000);self.assertEqual(value['status'],'PcNotMapped')
        self.assertFalse(value['rangeMatch']);self.assertNotIn('mappingBasename',value)

    def test_missing_symlink_oversized_and_nonregular_maps_are_explicit(self):
        self.maps.unlink();self.assertEqual(self.inspect()['status'],'MapsUnavailable')
        private=self.root/'unrelated';private.write_text('NEVER_PRINT_PRIVATE_CONTENT')
        self.maps.symlink_to(private);self.assertEqual(self.inspect()['status'],'MapsSymlinkRejected');self.maps.unlink()
        with self.maps.open('wb') as stream:stream.truncate(module.MAPS_LIMIT+1)
        self.assertEqual(self.inspect()['status'],'MapsExceedsReadBound');self.maps.unlink()
        os.mkfifo(self.maps);self.assertEqual(self.inspect()['status'],'MapsNotRegular')

    def test_anonymous_deleted_untrusted_and_backing_symlink_never_claim_verified_module(self):
        self.maps.write_text('1000-3000 rwxp 00000000 00:00 0\n')
        self.assertEqual(self.inspect()['status'],'AnonymousOrSpecialMapping')
        self.maps.write_text(self.row(Path(str(self.binary)+' (deleted)')))
        self.assertEqual(self.inspect()['status'],'DeletedMappedFile')
        self.maps.write_text(self.row(self.binary))
        self.assertEqual(self.inspect(roots=(self.root/'other',))['backingFile']['status'],'NonTrustedMappedPath')
        link=self.root/'link.so';link.symlink_to(self.binary);self.maps.write_text(self.row(link))
        self.assertEqual(self.inspect()['backingFile']['status'],'BackingFileSymlinkRejected')

    def test_invalid_or_changed_backing_file_is_not_inferred_as_loaded_elf(self):
        self.maps.write_text(self.row(self.binary,inode=self.binary.stat().st_ino+1))
        self.assertEqual(self.inspect()['backingFile']['status'],'BackingFileIdentityChanged')
        self.binary.write_bytes(b'NOT_AN_ELF_PRIVATE_CONTENT');self.maps.write_text(self.row(self.binary))
        value=self.inspect();self.assertEqual(value['backingFile']['status'],'BackingFileIsNotVerifiedElf')
        self.assertNotIn('sha256',value['backingFile']);self.assertNotIn('PRIVATE_CONTENT',str(value))

    def test_fingerprint_byte_bound_keeps_mapping_evidence_honest(self):
        with patch.object(module,'ELF_LIMIT',4):value=self.inspect()
        self.assertTrue(value['rangeMatch'])
        self.assertEqual(value['backingFile']['status'],'BackingElfExceedsFingerprintBound')
        self.assertNotIn('sha256',value['backingFile'])

if __name__=='__main__':unittest.main()
