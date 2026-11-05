"""Reject private build files and create SHA-256 manifests for distributable archives."""
import hashlib
from pathlib import Path
import zipfile


def main():
    for path in Path('dist').iterdir():
        if path.suffix not in ('.apk', '.ipa', '.zip'):
            continue
        with zipfile.ZipFile(path) as archive:
            if archive.testzip() is not None:
                raise RuntimeError('Invalid archive CRC')
            for name in archive.namelist():
                file = Path(name).name.lower()
                if file.endswith(('.map', '.jks', '.keystore', '.pem', '.key', '.symbols')) or file.startswith('.env') or file in ('mapping.txt', 'r8-mapping.txt'):
                    raise RuntimeError('Private build file found in ' + path.name)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        path.with_suffix(path.suffix + '.sha256').write_text(digest + '  ' + path.name + '\n')
        print('Validated archive:', path.name)


if __name__ == '__main__':
    main()
