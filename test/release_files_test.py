import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('release_files', Path(__file__).parents[1] / 'scripts/check_release_files.py')
release_files = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_files)


class ReleaseFilesTest(unittest.TestCase):
    def test_checksums_and_private_file_rejection(self):
        previous = Path.cwd()
        with tempfile.TemporaryDirectory() as directory:
            try:
                os.chdir(directory)
                Path('dist').mkdir()
                with zipfile.ZipFile('dist/public.zip', 'w') as archive:
                    archive.writestr('manifest.json', '{}')
                release_files.main()
                self.assertTrue(Path('dist/public.zip.sha256').exists())
                with zipfile.ZipFile('dist/private.zip', 'w') as archive:
                    archive.writestr('private/r8-mapping.txt', 'private')
                with self.assertRaises(RuntimeError):
                    release_files.main()
            finally:
                os.chdir(previous)
