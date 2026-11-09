"""Verify a built APK's actual signer against the independently recorded certificate."""
import os
from pathlib import Path
import re
import subprocess
import sys


def verify(output, expected):
    fingerprints = re.findall(r'Signer #\d+ certificate SHA-256 digest:\s*([0-9a-fA-F]+)', output)
    return len(fingerprints) == 1 and fingerprints[0].upper() == expected.replace(':', '').upper()


def check_result(result, expected):
    if result.returncode:
        raise RuntimeError('apksigner execution failed (exit ' + str(result.returncode) + '): ' + (result.stderr + '\n' + result.stdout).strip())
    if not verify(result.stdout, expected):
        actual = re.findall(r'Signer #\d+ certificate SHA-256 digest:\s*([0-9a-fA-F]+)', result.stdout)
        raise RuntimeError('APK certificate mismatch; expected ' + expected + '; actual ' + ','.join(actual))


if __name__ == '__main__':
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT'])
    candidates = list((sdk / 'build-tools').glob('*/apksigner'))
    if not candidates:
        raise RuntimeError('apksigner unavailable')
    tool = max(candidates, key=lambda p: tuple(map(int, re.findall(r'\d+', p.parent.name))))
    result = subprocess.run([str(tool), 'verify', '--print-certs', sys.argv[1]], capture_output=True, text=True)
    check_result(result, os.environ['ANDROID_EXPECTED_CERT_SHA256'])
    print('Built APK signer verified')
