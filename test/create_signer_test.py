import base64
from contextlib import redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('create_signer', Path(__file__).parents[1] / 'scripts/create_android_signer.py')
signer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signer)


class CreateSignerTest(unittest.TestCase):
    def test_never_overwrites_existing_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileExistsError):
                signer.create(Path(directory))

    def test_secret_material_stays_in_files_and_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'signer'
            fingerprint = 'AB' * 32
            def run(command, **kwargs):
                if '-genkeypair' in command:
                    Path(command[command.index('-keystore') + 1]).write_bytes(b'test-key')
                self.assertNotIn('-storepass', command)
                self.assertNotIn('-keypass', command)
                return SimpleNamespace(stdout='SHA256: ' + fingerprint)
            output = io.StringIO()
            with patch.object(signer.subprocess, 'run', side_effect=run), patch.object(signer.subprocess, 'check_output', return_value='test-owner'), redirect_stdout(output):
                signer.create(target)
            values = json.loads((target / 'github-secrets.json').read_text())
            self.assertEqual(base64.b64decode(values['ANDROID_KEYSTORE_BASE64']), b'test-key')
            self.assertGreaterEqual(len(values['ANDROID_KEYSTORE_PASSWORD']), 32)
            self.assertNotIn(values['ANDROID_KEYSTORE_PASSWORD'], output.getvalue())
            self.assertNotIn(values['ANDROID_KEY_PASSWORD'], output.getvalue())
            self.assertEqual(json.loads((target / 'github-variables.json').read_text())['ANDROID_EXPECTED_CERT_SHA256'], fingerprint)
