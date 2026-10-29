#!/usr/bin/env python3
import importlib.util
import json
import hashlib
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('fault_reader', Path(__file__).with_name('inspect-emulator-fault-artifact.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
REQUEST = {'mode': 'emulator-fault', 'runId': 40878922617, 'artifactId': 12901105053,
           'artifactName': 'drawmusic-emulator-fault-trace-' + 'd' * 40}


class FaultReaderTest(unittest.TestCase):
    def test_rejects_arbitrary_input_and_accepted_artifact_names(self):
        module.validate_request(REQUEST)
        for change in ({'path': '/etc/passwd'}, {'runId': True}, {'artifactId': 0}, {'mode': 'ui'},
                       {'artifactName': 'drawmusic-ui-visuals-' + 'd' * 40}):
            with self.assertRaises(ValueError):
                module.validate_request(REQUEST | change)

    def test_actual_fixed_metadata_does_not_dump_unknown_fields_or_console(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / module.PREFIX
            folder.mkdir(parents=True)
            (folder / 'lifecycle.json').write_text(json.dumps({'wrapperSignals': [], 'debuggerReturncode': 0,
                'stdout': {'eof': True, 'bytesDrained': 10, 'unknown': 'SECRET-STREAM'},
                'stderr': {'eof': True}, 'environment': 'SECRET-ENV'}))
            (folder / 'faults.json').write_text(json.dumps({'phase': 'finished', 'actualExitStatus': -1, 'arguments': 'SECRET-ARGV'}))
            (folder / 'stderr-tail.log').write_text('unable to read rendezvous\nSECRET-ENVIRONMENT\n')
            (root / 'ui-capture/flutter-drive.log').write_text('Using the Impeller rendering backend (OpenGLES).\nSECRET-DRIVER-CAPABILITY\n')
            (root / 'arbitrary').write_text('SECRET-UNRELATED')
            emitted = []
            result = module.inspect(root, REQUEST, emitted.append)
            text = '\n'.join(emitted)
            self.assertNotIn('SECRET-', text)
            self.assertFalse(result['acceptanceEligible'])
            self.assertIn('"actualExitStatus": -1', text)
            console = next(file for file in result['files'] if file['file'].endswith('stderr-tail.log'))
            self.assertEqual(console['diagnosticTokenCounts']['rendezvous'], 1)
            lifecycle = next(file for file in result['files'] if file['file'].endswith('lifecycle.json'))
            self.assertEqual(lifecycle['wrapperSignals'], [])
            self.assertTrue(lifecycle['drains']['stdout']['eof'])
            self.assertEqual(result['driverRenderer']['impellerGlesAnnouncements'], 1)
            self.assertEqual(result['driverRenderer']['impellerVulkanAnnouncements'], 0)
            self.assertTrue(result['missing'])

    def test_bounded_flight_fields_survive_without_leaking_driver_or_route_identity(self):
        text = 'SECRET-CAPABILITY\nUI_GRAPHITE_FLIGHT_SUMMARY ' + json.dumps({'naturalFramesObserved': 5, 'scope': 'SECRET-SCOPE'})
        text += '\nUI_GRAPHITE_FLIGHT_FRAME ' + json.dumps({'routePath': '/editor/SECRET-ID?session=SECRET',
            'routeType': '_PageBasedMaterialPageRoute<void>', 'routeTransitionDurationUs': 320000,
            'canvasRect': [1, 2, 3, 4], 'shuttleVisibleCount': 1, 'intentCancelled': False,
            'fieldErrors': {'routerLookup': 'FlutterError', 'unknown': 'SECRET'}, 'extra': 'SECRET'})
        result = module.flight_observations(text)
        self.assertNotIn('SECRET', json.dumps(result))
        self.assertEqual(result['frames'][0]['routeKind'], 'editor')
        self.assertEqual(result['frames'][0]['shuttleVisibleCount'], 1)
        self.assertEqual(result['frames'][0]['fieldErrors'], {'routerLookup': 'FlutterError'})
        with self.assertRaises(ValueError):
            module.flight_observations('\n'.join(['UI_GRAPHITE_FLIGHT_FRAME {}'] * 81))
        with self.assertRaises(ValueError):
            module.flight_observations('UI_GRAPHITE_FLIGHT_FRAME ' + 'x' * 8193)

    def test_profile_recomputes_original_samples_and_rejects_tampering(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / module.PREFIX
            folder.mkdir(parents=True)
            (folder / 'faults.json').write_text('{}')
            profile = {'refreshHz': 60, 'frameBudgetUs': 1_000_000/60,
                'visibleScope': {'screenRecordingActive': False, 'graphiteProductionInteractions': True},
                'rawFrames': [{'frameNumber': i, 'vsyncUs': i*1000, 'rasterFinishWallUs': i*1000+60,
                              'buildUs': i*10, 'rasterUs': i*20, 'totalUs': i*30} for i in (1, 2)],
                'eitherUiOrRasterOverBudgetFrames': 0}
            for name, maximum in (('uiBuild', 20), ('raster', 40), ('totalSpan', 60)):
                profile[name] = dict(count=2, maxUs=maximum, overBudgetFrames=0,
                                     p50Us=maximum, p90Us=maximum, p95Us=maximum, p99Us=maximum)
            path = root / 'ui-capture/performance/graphite-interactions-unrecorded.json'
            path.parent.mkdir(parents=True)
            data = json.dumps(profile).encode()
            path.write_bytes(data)
            report = {'passed': False, 'diagnosticSequenceCompleted': True, 'events': [
                {'operation': 'perf_finish', 'name': 'graphite-interactions-unrecorded',
                 'recordingDuringMeasurement': False, 'evidenceBytes': len(data), 'evidenceSha256': hashlib.sha256(data).hexdigest()}]}
            (root / 'ui-capture/capture-report.json').write_text(json.dumps(report))
            result = module.inspect(root, REQUEST, lambda text: None)
            self.assertEqual(result['unrecordedProfile']['uiBuild']['p95Us'], 20)
            self.assertFalse(result['unrecordedProfile']['acceptanceEligible'])
            path.write_bytes(data + b' ')
            with self.assertRaises(ValueError):
                module.inspect(root, REQUEST, lambda text: None)

    def test_missing_files_are_not_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                module.inspect(Path(tmp), REQUEST)

    def test_symlink_or_oversized_console_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / module.PREFIX
            folder.mkdir(parents=True)
            target = root / 'private'
            target.write_text('SECRET')
            path = folder / 'stderr-tail.log'
            path.symlink_to(target)
            with self.assertRaises(ValueError):
                module.inspect(root, REQUEST)
            path.unlink()
            with path.open('wb') as file:
                file.truncate(262145)
            with self.assertRaises(ValueError):
                module.inspect(root, REQUEST)


if __name__ == '__main__':
    unittest.main()
