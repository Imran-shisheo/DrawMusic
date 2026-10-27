#!/usr/bin/env python3
"""Real MP4/NAL readiness checks; not Android codec/device execution proof."""
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

from ui_capture_mp4 import encoded_avc_readiness


def box(kind, payload): return struct.pack('>I4s',8+len(payload),kind)+payload


def inspect(data): return encoded_avc_readiness(lambda off,count:data[off:off+count],len(data))


class MediaReadinessTests(unittest.TestCase):
    def test_header_and_metadata_are_not_encoded_video(self):
        self.assertFalse(inspect(box(b'ftyp',b'isom\0\0\0\0'))['ready'])
        self.assertFalse(inspect(box(b'ftyp',b'isom')+box(b'free',b'\0'*16384))['ready'])

    def test_preallocation_zeros_are_not_a_video_frame(self):
        self.assertFalse(inspect(box(b'ftyp',b'isom')+box(b'mdat',b'\0'*65536))['ready'])

    def test_incomplete_declared_vcl_payload_is_not_ready(self):
        sample=struct.pack('>I',4096)+b'\x65\xb8\x40\x80'
        result=inspect(box(b'ftyp',b'isom')+struct.pack('>I4s',0,b'mdat')+sample)
        self.assertFalse(result['ready'])
        self.assertIn('not been fully written',result['reason'])

    def test_fake_vcl_header_in_sparse_payload_is_not_ready(self):
        nal=b'\x65\xb8\x40\x80'+b'\0'*128
        self.assertFalse(inspect(box(b'mdat',struct.pack('>I',len(nal))+nal))['ready'])

    def test_incomplete_extended_box_header_is_not_ready(self):
        self.assertFalse(inspect(struct.pack('>I4s',1,b'mdat')+b'\0\0')['ready'])

    def test_real_synthetic_avc_is_ready_only_when_complete_media_was_written(self):
        with tempfile.TemporaryDirectory(prefix='drawmusic-real-avc-') as directory:
            file=Path(directory)/'fixture.mp4'
            subprocess.run(['ffmpeg','-nostdin','-v','error','-f','lavfi','-i','testsrc=size=320x240:rate=6','-t','2','-pix_fmt','yuv420p','-y',str(file)],check=True,capture_output=True,timeout=20)
            data=file.read_bytes();result=inspect(data)
            self.assertTrue(result['ready'],result)
            self.assertIn(result['nalType'],(1,5))
            cut=result['nalOffset']+result['nalBytes']-1
            self.assertFalse(inspect(data[:cut])['ready'])
            # Real ffmpeg decoding remains a separate final acceptance step.
            subprocess.run(['ffmpeg','-nostdin','-v','error','-xerror','-err_detect','explode','-i',str(file),'-map','0:v:0','-f','null','-'],check=True,capture_output=True,timeout=20)


if __name__ == '__main__': unittest.main()
