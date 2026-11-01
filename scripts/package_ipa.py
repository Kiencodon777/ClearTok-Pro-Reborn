"""Package a built device app at Payload/<name>.app and verify its metadata."""
import os
from pathlib import Path
import plistlib
import stat
import sys
import zipfile
import hashlib


def add_directory(archive, name):
    info = zipfile.ZipInfo(name.rstrip('/') + '/')
    info.create_system = 3
    info.external_attr = ((stat.S_IFDIR | 0o755) << 16) | 0x10
    archive.writestr(info, b'')


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
        add_directory(archive, 'Payload/')
        for folder, dirs, files in os.walk(app, followlinks=False):
            relative = Path(folder).relative_to(app).as_posix()
            add_directory(archive, root + (relative + '/' if relative != '.' else ''))
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
        if not archive.getinfo('Payload/').is_dir() or not archive.getinfo(root).is_dir():
            raise ValueError('Missing explicit IPA directory entries')
        for name in archive.namelist():
            if name.endswith('.framework/Info.plist'):
                framework = plistlib.loads(archive.read(name))
                binary = framework.get('CFBundleExecutable')
                if not binary or '/' in binary:
                    raise ValueError('Invalid framework executable: ' + name)
                archive.getinfo(name.rsplit('/', 1)[0] + '/' + binary)
    with output.open('rb') as stream:
        hasher = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            hasher.update(chunk)
        digest = hasher.hexdigest()
    output.with_suffix(output.suffix + '.sha256').write_text(
        digest + '  ' + output.name + '\n', encoding='utf-8')
    print(f'Validated IPA: {output}; metadata: {root}Info.plist')


if __name__ == '__main__':
    package(*sys.argv[1:])
