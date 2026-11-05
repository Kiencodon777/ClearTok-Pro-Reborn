import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('signer', Path(__file__).parents[1] / 'scripts/verify_apk_signer.py')
signer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signer)


class ApkSignerTest(unittest.TestCase):
    def test_requires_exact_single_signer(self):
        digest = 'ab' * 32
        output = 'Signer #1 certificate SHA-256 digest: ' + digest
        self.assertTrue(signer.verify(output, digest.upper()))
        self.assertFalse(signer.verify(output, 'cd' * 32))
        self.assertFalse(signer.verify('Unsigned APK', digest))
        self.assertFalse(signer.verify(output + '\nSigner #2 certificate SHA-256 digest: ' + digest, digest))
