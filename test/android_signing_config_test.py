import base64
import importlib.util
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('signing_config', Path(__file__).parents[1] / 'scripts/configure_android_signing.py')
signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing)


class AndroidSigningConfigTest(unittest.TestCase):
    def test_signer_validation_precedes_gradle_changes(self):
        original = 'android { buildTypes { release { signingConfig = signingConfigs.getByName("debug") } } }'
        digest = 'AB' * 32
        for certificate, accepted in [
            ('Owner: CN=ClearTok\nSHA256: ' + digest, True),
            ('Owner: CN=Android Debug\nSHA256: ' + digest, False),
            ('Owner: CN=ClearTok\nSHA256: ' + 'CD' * 32, False),
        ]:
            with self.subTest(certificate=certificate), tempfile.TemporaryDirectory() as directory:
                previous = Path.cwd()
                try:
                    os.chdir(directory)
                    gradle = Path('android/app/build.gradle.kts')
                    gradle.parent.mkdir(parents=True)
                    gradle.write_text(original)
                    environment = {
                        'ANDROID_KEYSTORE_BASE64': base64.b64encode(b'fixture-not-a-key').decode(),
                        'ANDROID_KEYSTORE_PASSWORD': 'fixture', 'ANDROID_KEY_ALIAS': 'fixture',
                        'ANDROID_KEY_PASSWORD': 'fixture', 'ANDROID_EXPECTED_CERT_SHA256': digest,
                        'ANDROID_KEYSTORE_PATH': str(Path(directory) / 'fixture.jks'),
                    }
                    with patch.dict(os.environ, environment, clear=True), patch.object(
                        signing.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout=certificate)
                    ):
                        if accepted:
                            signing.main()
                            self.assertIn('getByName("verifiedRelease")', gradle.read_text())
                            self.assertNotIn('getByName("debug")', gradle.read_text())
                        else:
                            with self.assertRaises(RuntimeError):
                                signing.main()
                            self.assertEqual(gradle.read_text(), original)
                finally:
                    os.chdir(previous)

    def test_missing_signer_blocks_without_mutation(self):
        with patch.dict(os.environ, {}, clear=True), self.assertRaises(RuntimeError):
            signing.main()
