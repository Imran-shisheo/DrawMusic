#!/usr/bin/env python3
"""Host orchestration regressions. Fake ADB/processes are NOT native runtime proof."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
import struct
import zlib
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('capture_host', Path(__file__).with_name('capture-android-ui.py'))
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)


class Process:
    def __init__(self, exit_code): self.returncode = exit_code
    def poll(self): return self.returncode
    def wait(self, timeout): return self.returncode


class RecorderTests(unittest.TestCase):
    def test_actual_png_decoder_rejects_flat_splash_but_accepts_presented_content(self):
        def png(content):
            def chunk(kind, data):
                return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
            raw=b''.join(b'\0'+b''.join(bytes((85,223,245) if content and x<40 else (9,11,24)) for x in range(80)) for _ in range(160))
            return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',80,160,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')
        self.assertLess(host.presented_scene_evidence(png(False))['centralForegroundRatio'], .02)
        self.assertGreater(host.presented_scene_evidence(png(True))['centralForegroundRatio'], .02)

    def exercise(self, *, failure='unable to configure video/avc codec', wrong_owner=False):
        calls, created, clock = [], [], [0.]
        def popen(command, stdout, stderr):
            created.append(command)
            if len(created) == 1 and not wrong_owner:
                stdout.write('ERROR: ' + failure + '\n'); stdout.flush()
                return Process(1)
            return Process(None)
        def adb(*args, **kwargs):
            calls.append(args)
            if args[:2] == ('shell', 'pidof'):
                return SimpleNamespace(stdout='123' if created else '')
            if args[:2] == ('shell', 'cat'):
                return SimpleNamespace(stdout='unrelated recording' if wrong_owner else '\x00'.join(created[-1]))
            return SimpleNamespace(stdout='')
        def sleep(seconds): clock[0] += seconds
        with tempfile.TemporaryDirectory(prefix='drawmusic-recorder-test-') as directory:
            output = Path(directory); (output/'recordings').mkdir()
            with patch.object(host, 'OUTPUT', output), patch.object(host, 'adb', adb), patch.object(host.subprocess, 'Popen', popen), patch.object(host.time, 'monotonic', lambda:clock[0]), patch.object(host.time, 'sleep', sleep):
                capture = host.Capture()
                try:
                    settings = capture.record_start('00-home-ambient')
                except RuntimeError as error:
                    return None, str(error), calls, created
                capture.recording[4].close()
                return settings, None, calls, created

    def test_known_codec_configuration_failure_uses_bounded_portrait_fallback(self):
        settings, error, calls, created = self.exercise()
        self.assertIsNone(error)
        self.assertEqual((settings['width'], settings['height']), (432,960))
        self.assertEqual(len(created), 2)
        self.assertEqual(len(settings['codecFallbackAttempts']), 1)
        self.assertFalse(any(call[:2] == ('shell','kill') for call in calls))

    def test_unknown_startup_failure_does_not_retry_or_claim_success(self):
        settings, error, calls, created = self.exercise(failure='unrelated encoder failure')
        self.assertIsNone(settings)
        self.assertIn('exited before startup', error)
        self.assertEqual(len(created), 1)

    def test_unrelated_process_is_never_signaled_or_used_as_recording(self):
        settings, error, calls, created = self.exercise(wrong_owner=True)
        self.assertIsNone(settings)
        self.assertIn('identity differs', error)
        self.assertEqual(len(created), 1)
        self.assertFalse(any(call[:2] == ('shell','kill') for call in calls))

    def test_lost_recording_identity_closes_log_and_never_signals(self):
        with tempfile.TemporaryDirectory(prefix='drawmusic-recorder-stop-') as directory:
            log = (Path(directory)/'record.log').open('w')
            capture = host.Capture()
            capture.recording = ('ambient', '/owned/exact.mp4', '123', Process(1), log, {'width':432,'height':960})
            calls = []
            def adb(*args, **kwargs):
                calls.append(args)
                return SimpleNamespace(stdout='a different process')
            with patch.object(host, 'adb', adb):
                with self.assertRaisesRegex(RuntimeError, 'refusing signal'):
                    capture.record_stop()
            self.assertTrue(log.closed)
            self.assertIsNone(capture.recording)
            self.assertFalse(any(call[:2] == ('shell','kill') for call in calls))


if __name__ == '__main__': unittest.main()
