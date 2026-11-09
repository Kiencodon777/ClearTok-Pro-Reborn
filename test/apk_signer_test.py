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
        with self.assertRaisesRegex(RuntimeError, 'APK signer verification failed'):
            signer.check_result(SimpleNamespace(returncode=0, stdout='Unsigned APK', stderr=''), 'ab' * 32)

    def test_requires_exact_single_signer(self):
        digest = 'ab' * 32
        output = 'Number of signers: 1\nSigner #1 certificate SHA-256 digest: ' + digest
        self.assertTrue(signer.verify(output, digest.upper()))
        self.assertFalse(signer.verify(output, 'cd' * 32))
        self.assertFalse(signer.verify('Unsigned APK', digest))
        self.assertFalse(signer.verify(output.replace('signers: 1', 'signers: 2') + '\nSigner #2 certificate SHA-256 digest: ' + digest, digest))

    def test_sdk37_scheme_labels_and_sdk_ranges(self):
        digest = 'ab' * 32
        for label in ('V2 Signer:', 'V3.0 Signer:',
                      'V3.1 Signer: (minSdkVersion=33, maxSdkVersion=2147483647)',
                      'Signer (minSdkVersion=24, maxSdkVersion=32)'):
            with self.subTest(label=label):
                output = 'Number of signers: 1\n' + label + ' certificate SHA-256 digest: ' + digest
                self.assertTrue(signer.verify(output, digest))
                self.assertFalse(signer.verify(output, 'cd' * 32))
                self.assertFalse(signer.verify(output.replace('Number of signers: 1\n', ''), digest))

    def test_every_sdk_range_must_match_and_source_stamp_is_not_app_identity(self):
        digest = 'ab' * 32
        output = ('Number of signers: 1\nV3.0 Signer: certificate SHA-256 digest: ' + digest
                  + '\nV3.1 Signer: (minSdkVersion=33, maxSdkVersion=2147483647) certificate SHA-256 digest: ' + digest)
        self.assertTrue(signer.verify(output, digest))
        self.assertFalse(signer.verify(output.replace('V3.0 Signer: certificate SHA-256 digest: ' + digest,
                                                    'V3.0 Signer: certificate SHA-256 digest: ' + 'cd' * 32), digest))
        self.assertFalse(signer.verify('Number of signers: 1\nSource Stamp Signer certificate SHA-256 digest: ' + digest, digest))
