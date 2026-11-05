"""Configure CI signing only after comparing its certificate with an expected signer."""
import base64
import os
import re
import subprocess
from pathlib import Path


def main():
    names = ('ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD',
             'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD', 'ANDROID_EXPECTED_CERT_SHA256')
    if not all(os.environ.get(name) for name in names):
        raise RuntimeError('Android signing BLOCKED: verified production keystore configuration is missing')
    expected = os.environ['ANDROID_EXPECTED_CERT_SHA256'].replace(':', '').upper()
    if not re.fullmatch(r'[0-9A-F]{64}', expected):
        raise RuntimeError('Invalid expected Android signing certificate fingerprint')
    target = Path(os.environ['ANDROID_KEYSTORE_PATH'])
    target.write_bytes(base64.b64decode(os.environ['ANDROID_KEYSTORE_BASE64'], validate=True))
    target.chmod(0o600)
    result = subprocess.run(['keytool', '-list', '-v', '-keystore', str(target),
      '-storepass:env', 'ANDROID_KEYSTORE_PASSWORD', '-alias', os.environ['ANDROID_KEY_ALIAS'],
      '-J-Duser.language=en'], capture_output=True, text=True)
    match = re.search(r'SHA256:\s*([A-Fa-f0-9:]+)', result.stdout)
    if 'CN=Android Debug' in result.stdout:
        raise RuntimeError('The previous debug signer cannot be used as a production signing identity')
    if result.returncode or not match or match[1].replace(':', '').upper() != expected:
        raise RuntimeError('Android keystore certificate does not match the expected signer')
    gradle = Path('android/app/build.gradle.kts')
    content = gradle.read_text()
    old = 'signingConfig = signingConfigs.getByName("debug")'
    if content.count(old) != 1:
        raise RuntimeError('Review existing release signing configuration before changing it')
    content = content.replace('buildTypes {', '''signingConfigs {
        create("verifiedRelease") {
            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH"))
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }
    buildTypes {''', 1).replace(old, 'signingConfig = signingConfigs.getByName("verifiedRelease")')
    gradle.write_text(content)
    print('Android production certificate matched the expected signer')


if __name__ == '__main__':
    main()
