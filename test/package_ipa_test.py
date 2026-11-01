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
            (app / 'Info.plist').write_bytes(plistlib.dumps({
                'CFBundleExecutable': 'Runner', 'CFBundleIdentifier': 'com.cleartok.app',
                'CFBundleSupportedPlatforms': ['iPhoneOS']}, fmt=plistlib.FMT_BINARY))
            output = Path(directory) / 'test.ipa'
            module.package(app, output)
            with zipfile.ZipFile(output) as archive:
                self.assertIn('Payload/Runner.app/Info.plist', archive.namelist())
                self.assertIn('Payload/Runner.app/Runner', archive.namelist())
                self.assertEqual(archive.getinfo('Payload/Runner.app/Info.plist').compress_type, zipfile.ZIP_STORED)
            (app / 'Info.plist').unlink()
            with self.assertRaises(FileNotFoundError):
                module.package(app, output)


if __name__ == '__main__':
    unittest.main()
