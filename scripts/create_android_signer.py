"""Create a production signer locally; never print or overwrite private material."""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import secrets
import subprocess


def create(target):
    target = target.resolve()
    target.mkdir(parents=True, exist_ok=False)
    if os.name == 'nt':
        owner = subprocess.check_output(['whoami'], text=True).strip()
        subprocess.run(['icacls', str(target), '/inheritance:r', '/grant:r',
                        owner + ':(OI)(CI)F'], check=True, capture_output=True)
    else:
        target.chmod(0o700)
    values = {
        'ANDROID_KEYSTORE_PASSWORD': secrets.token_urlsafe(32),
        'ANDROID_KEY_PASSWORD': secrets.token_urlsafe(32),
        'ANDROID_KEY_ALIAS': 'cleartok-production-v1',
    }
    environment = {**os.environ, **values}
    keystore = target / 'release.jks'
    subprocess.run(['keytool', '-genkeypair', '-noprompt', '-storetype', 'JKS',
                    '-keystore', str(keystore), '-alias', values['ANDROID_KEY_ALIAS'],
                    '-keyalg', 'RSA', '-keysize', '4096', '-validity', '10000',
                    '-dname', 'CN=ClearTok Production',
                    '-storepass:env', 'ANDROID_KEYSTORE_PASSWORD',
                    '-keypass:env', 'ANDROID_KEY_PASSWORD'],
                   env=environment, check=True, capture_output=True)
    result = subprocess.run(['keytool', '-list', '-v', '-keystore', str(keystore),
                             '-alias', values['ANDROID_KEY_ALIAS'],
                             '-storepass:env', 'ANDROID_KEYSTORE_PASSWORD',
                             '-J-Duser.language=en'], env=environment,
                            check=True, capture_output=True, text=True)
    match = re.search(r'SHA256:\s*([A-Fa-f0-9:]+)', result.stdout)
    if not match or 'CN=Android Debug' in result.stdout:
        raise RuntimeError('Production certificate verification failed')
    fingerprint = match[1].replace(':', '').upper()
    values['ANDROID_KEYSTORE_BASE64'] = base64.b64encode(keystore.read_bytes()).decode('ascii')
    (target / 'github-secrets.json').write_text(json.dumps(values, indent=2), encoding='utf-8')
    (target / 'github-variables.json').write_text(json.dumps({
        'ANDROID_EXPECTED_CERT_SHA256': fingerprint}, indent=2), encoding='utf-8')
    subprocess.run(['keytool', '-exportcert', '-rfc', '-keystore', str(keystore),
                    '-alias', values['ANDROID_KEY_ALIAS'], '-storepass:env',
                    'ANDROID_KEYSTORE_PASSWORD', '-file', str(target / 'certificate.pem')],
                   env=environment, check=True, capture_output=True)
    print('Production signer created and verified. Private material was not printed.')
    print('SHA256: ' + fingerprint)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    create(args.directory)
