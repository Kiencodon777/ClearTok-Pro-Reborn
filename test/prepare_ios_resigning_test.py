import importlib.util
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('prepare_ios', Path(__file__).parents[1] / 'scripts/prepare_ios_resigning.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PrepareIosTest(unittest.TestCase):
    def make_app(self, root):
        app = Path(root) / 'Runner.app'
        app.mkdir()
        (app / 'Info.plist').write_bytes(plistlib.dumps({
            'CFBundleExecutable': 'Runner', 'CFBundleSupportedPlatforms': ['iPhoneOS']}))
        (app / 'Runner').write_bytes(b'\xcf\xfa\xed\xfe' + b'app')
        framework = app / 'Frameworks/Example.framework'
        framework.mkdir(parents=True)
        (framework / 'Example').write_bytes(b'\xca\xfe\xba\xbe' + b'framework')
        for bundle in (app, framework):
            (bundle / '_CodeSignature').mkdir()
            (bundle / '_CodeSignature/CodeResources').write_text('old seal')
        (app / 'embedded.mobileprovision').write_bytes(b'old profile')
        (app / 'asset.png').write_bytes(b'image')
        return app

    def test_removes_all_macho_signatures_and_stale_seals_and_can_retry(self):
        with tempfile.TemporaryDirectory() as root, patch.object(module.subprocess, 'run') as run:
            app = self.make_app(root)
            run.return_value = subprocess.CompletedProcess([], 0, '', '')
            module.prepare(app)
            self.assertEqual({Path(call.args[0][-1]).name for call in run.call_args_list}, {'Runner', 'Example'})
            self.assertFalse(list(app.rglob('_CodeSignature')))
            self.assertFalse((app / 'embedded.mobileprovision').exists())
            self.assertEqual((app / 'asset.png').read_bytes(), b'image')
            run.return_value = subprocess.CompletedProcess([], 1, '', 'code object is not signed at all')
            module.prepare(app)

    def test_tool_failure_stops_before_deleting_seals(self):
        with tempfile.TemporaryDirectory() as root, patch.object(module.subprocess, 'run') as run:
            app = self.make_app(root)
            run.return_value = subprocess.CompletedProcess([], 1, '', 'invalid Mach-O')
            with self.assertRaisesRegex(RuntimeError, 'Cannot remove'):
                module.prepare(app)
            self.assertTrue((app / '_CodeSignature/CodeResources').exists())

    def test_missing_executable_and_simulator_are_rejected(self):
        with tempfile.TemporaryDirectory() as root, patch.object(module.subprocess, 'run') as run:
            app = self.make_app(root)
            (app / 'Runner').write_bytes(b'not Mach-O')
            with self.assertRaisesRegex(ValueError, 'Missing Mach-O'):
                module.prepare(app)
            info = {'CFBundleExecutable': 'Runner', 'CFBundleSupportedPlatforms': ['iPhoneSimulator']}
            (app / 'Info.plist').write_bytes(plistlib.dumps(info))
            with self.assertRaisesRegex(ValueError, 'iPhoneOS'):
                module.prepare(app)
            run.assert_not_called()
