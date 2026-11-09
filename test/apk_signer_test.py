import importlib.util
from pathlib import Path
import unittest
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location('signer', Path(__file__).parents[1] / 'scripts/verify_apk_signer.py')
signer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signer)


class ApkSignerTest(unittest.TestCase):
    def test_reports_tool_failure_separately_from_certificate_mismatch(self):
        with self.assertRaisesRegex(RuntimeError, 'apksigner execution failed.*Java'):
            signer.check_result(SimpleNamespace(returncode=1, stdout='', stderr='Java tool failure'), 'ab' * 32)
        with self.assertRaisesRegex(RuntimeError, 'certificate mismatch'):
            signer.check_result(SimpleNamespace(returncode=0, stdout='Unsigned APK', stderr=''), 'ab' * 32)

    def test_requires_exact_single_signer(self):
        digest = 'ab' * 32
        output = 'Signer #1 certificate SHA-256 digest: ' + digest
        self.assertTrue(signer.verify(output, digest.upper()))
        self.assertFalse(signer.verify(output, 'cd' * 32))
        self.assertFalse(signer.verify('Unsigned APK', digest))
        self.assertFalse(signer.verify(output + '\nSigner #2 certificate SHA-256 digest: ' + digest, digest))
