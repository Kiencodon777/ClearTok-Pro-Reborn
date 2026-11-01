"""Package a built device app at Payload/<name>.app and verify its metadata."""
import os
from pathlib import Path
import plistlib
import stat
import sys
import zipfile


def package(app, output):
    app = Path(app).resolve()
    output = Path(output)
    if not app.is_dir() or app.suffix != '.app':
        raise ValueError('Expected a built device .app bundle')
    metadata = plistlib.loads((app / 'Info.plist').read_bytes())
    executable = metadata.get('CFBundleExecutable', '')
    if not executable or Path(executable).name != executable:
        raise ValueError('Invalid CFBundleExecutable')
    if not (app / executable).is_file() or not metadata.get('CFBundleIdentifier'):
        raise ValueError('Missing app executable or bundle identifier')
    if metadata.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
        raise ValueError('Expected an iPhoneOS device build, not a simulator app')
    root = 'Payload/' + app.name + '/'
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for folder, dirs, files in os.walk(app, followlinks=False):
            for name in files + [d for d in dirs if (Path(folder) / d).is_symlink()]:
                path = Path(folder) / name
                arcname = root + path.relative_to(app).as_posix()
                if path.is_symlink():
                    info = zipfile.ZipInfo(arcname)
                    info.create_system = 3
                    info.external_attr = (stat.S_IFLNK | 0o777) << 16
                    archive.writestr(info, os.readlink(path))
                else:
                    archive.write(path, arcname, compress_type=(
                        zipfile.ZIP_STORED if path.name == 'Info.plist' else zipfile.ZIP_DEFLATED))
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise ValueError('Corrupt IPA archive')
        plistlib.loads(archive.read(root + 'Info.plist'))
        archive.getinfo(root + executable)
    print(f'Validated IPA: {output}; metadata: {root}Info.plist')


if __name__ == '__main__':
    package(*sys.argv[1:])
