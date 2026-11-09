"""Verify a built APK's actual signer against the independently recorded certificate."""
import os
from pathlib import Path
import re
import subprocess
import sys


def fingerprints(output):
    # SDK 37 labels certificates by signature scheme instead of signer number.
    return re.findall(
        r'^(?:Signer #\d+|Signer \([^\r\n]+\)|V[1-4](?:\.\d+)? Signer(?: #\d+)?:'
        r'(?: \([^\r\n]+\))?) certificate SHA-256 digest: ([0-9a-fA-F]{64})\r?$',
        output, re.MULTILINE)


def verify(output, expected):
    actual = fingerprints(output)
    expected = expected.replace(':', '').upper()
    counts = re.findall(r'^Number of signers: (\d+)\r?$', output, re.MULTILINE)
    return (counts == ['1'] and bool(actual) and re.fullmatch(r'[0-9A-F]{64}', expected) is not None
            and all(digest.upper() == expected for digest in actual))


def check_result(result, expected):
    if result.returncode:
        raise RuntimeError('apksigner execution failed (exit ' + str(result.returncode) + '): ' + (result.stderr + '\n' + result.stdout).strip())
    if not verify(result.stdout, expected):
        raise RuntimeError('APK signer verification failed; expected ' + expected
                           + '; apksigner output:\n' + result.stdout.strip())


if __name__ == '__main__':
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT'])
    candidates = list((sdk / 'build-tools').glob('*/apksigner'))
    if not candidates:
        raise RuntimeError('apksigner unavailable')
    tool = max(candidates, key=lambda p: tuple(map(int, re.findall(r'\d+', p.parent.name))))
    result = subprocess.run([str(tool), 'verify', '--verbose', '--print-certs', sys.argv[1]], capture_output=True, text=True)
    check_result(result, os.environ['ANDROID_EXPECTED_CERT_SHA256'])
    print('Built APK signer verified')
