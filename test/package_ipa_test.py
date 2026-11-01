import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('package_ipa', Path(__file__).parents[1] / 'scripts/package_ipa.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PackagingTest(unittest.TestCase):
    def test_root_plist_and_executable(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / 'Runner.app'
            app.mkdir()
            (app / 'Runner').write_bytes(b'test executable')
            (app / 'Frameworks' / 'Example.framework').mkdir(parents=True)
            (app / 'Frameworks' / 'Example.framework' / 'Example').write_bytes(b'framework')
            (app / 'Frameworks' / 'Example.framework' / 'Info.plist').write_bytes(
                plistlib.dumps({'CFBundleExecutable': 'Example'}))
            (app / 'Info.plist').write_bytes(plistlib.dumps({
                'CFBundleExecutable': 'Runner', 'CFBundleIdentifier': 'com.cleartok.app',
                'CFBundleSupportedPlatforms': ['iPhoneOS']}, fmt=plistlib.FMT_BINARY))
            output = Path(directory) / 'test.ipa'
            module.package(app, output)
            with zipfile.ZipFile(output) as archive:
                for directory in ['Payload/', 'Payload/Runner.app/',
                                  'Payload/Runner.app/Frameworks/',
                                  'Payload/Runner.app/Frameworks/Example.framework/']:
                    self.assertTrue(archive.getinfo(directory).is_dir())
                    self.assertEqual(archive.getinfo(directory).external_attr >> 16, 0o40755)
                self.assertIn('Payload/Runner.app/Info.plist', archive.namelist())
                self.assertIn('Payload/Runner.app/Runner', archive.namelist())
                self.assertEqual(archive.getinfo('Payload/Runner.app/Info.plist').compress_type, zipfile.ZIP_STORED)
            self.assertTrue(output.with_suffix('.ipa.sha256').is_file())
            (app / 'Info.plist').unlink()
            with self.assertRaises(FileNotFoundError):
                module.package(app, output)


if __name__ == '__main__':
    unittest.main()
