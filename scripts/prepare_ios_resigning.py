"""Remove temporary signatures from a device app before a sideload signer imports it."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys


MACHO_MAGICS = {b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf',
                b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xce',
                b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca',
                b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca'}


def prepare(app):
    app = Path(app).resolve()
    if not app.is_dir() or app.suffix != '.app':
        raise ValueError('Expected a built .app bundle')
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
        raise ValueError('Expected an iPhoneOS device app')
    binaries = []
    for path in app.rglob('*'):
        if path.is_symlink():
            raise ValueError('Review bundle symlinks before preparing an IPA')
        if path.is_file():
            with path.open('rb') as source:
                if source.read(4) in MACHO_MAGICS:
                    binaries.append(path)
    executable = info.get('CFBundleExecutable', '')
    if not executable or Path(executable).name != executable or app / executable not in binaries:
        raise ValueError('Missing Mach-O app executable')
    for binary in binaries:
        result = subprocess.run(['codesign', '--remove-signature', str(binary)],
                                capture_output=True, text=True)
        if result.returncode and 'code object is not signed at all' not in result.stderr:
            raise RuntimeError('Cannot remove temporary signature from ' + str(binary) + ': ' + result.stderr)
    for path in sorted(app.rglob('_CodeSignature'), reverse=True):
        if path.is_dir():
            shutil.rmtree(path)
    for path in app.rglob('embedded.mobileprovision'):
        path.unlink()
    print('Prepared unsigned device bundle for re-signing:', app.name, '; Mach-O files:', len(binaries))


if __name__ == '__main__':
    prepare(sys.argv[1])
