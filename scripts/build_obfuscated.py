"""Build an obfuscated Flutter release with symbols in a separate directory."""
import argparse
import subprocess
import shutil
import os
import plistlib
from pathlib import Path


def configure_ios_callback(plist):
    info = plistlib.loads(plist.read_bytes())
    info['FlutterDeepLinkingEnabled'] = False
    schemes = info.setdefault('CFBundleURLTypes', [])
    if not any('cleartok' in item.get('CFBundleURLSchemes', []) for item in schemes):
        schemes.append({'CFBundleURLSchemes': ['cleartok']})
    plist.write_bytes(plistlib.dumps(info))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('platform', choices=('android', 'ios'))
    parser.add_argument('--symbols', required=True, type=Path,
                        help='Private directory for split debug symbols')
    parser.add_argument('--flutter', default='flutter')
    args = parser.parse_args()
    configuration = {name: os.environ.get(name, '') for name in
                     ('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY')}
    if not all(configuration.values()):
        parser.error('Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY before building')
    from validate_backend_config import validate
    validate(configuration['SUPABASE_URL'], configuration['SUPABASE_PUBLISHABLE_KEY'])
    root = Path(__file__).resolve().parent.parent
    symbols = args.symbols.resolve()
    public_build = (root / 'build').resolve()
    if symbols == public_build or public_build in symbols.parents:
        parser.error('Store symbols outside the build artifact directory')
    if args.platform == 'android':
        gradle = root / 'android/app/build.gradle.kts'
        if not gradle.exists():
            parser.error('Generate Android scaffolding as documented in the release workflow first')
        content = gradle.read_text()
        if 'signingConfig = signingConfigs.getByName("debug")' in content:
            parser.error('Configure a verified production signer before building a public APK')
        if 'release {' not in content:
            parser.error('Missing Android release configuration')
        if 'isMinifyEnabled' in content or 'isShrinkResources' in content:
            if 'isMinifyEnabled = true' not in content or 'isShrinkResources = true' not in content:
                parser.error('Review the existing shrinking configuration before release')
        else:
            content = content.replace('release {', 'release {\n            isMinifyEnabled = true\n            isShrinkResources = true', 1)
        gradle.write_text(content)
    symbols.mkdir(parents=True, exist_ok=True)
    command = [args.flutter, 'build', 'apk' if args.platform == 'android' else 'ios',
               '--release', '--no-tree-shake-icons', '--obfuscate',
               '--split-debug-info=' + str(symbols)]
    if args.platform == 'ios':
        configure_ios_callback(root / 'ios/Runner/Info.plist')
        command.append('--no-codesign')
    command.extend('--dart-define=' + key + '=' + value for key, value in configuration.items())
    if os.environ.get('VERSION'):
        command.extend(['--build-name=' + os.environ['VERSION'].split('-', 1)[0],
                        '--dart-define=APP_VERSION=' + os.environ['VERSION']])
    if os.environ.get('GITHUB_RUN_NUMBER'):
        command.append('--build-number=' + os.environ['GITHUB_RUN_NUMBER'])
    if os.environ.get('UPDATE_FEED_URL'):
        command.append('--dart-define=UPDATE_FEED_URL=' + os.environ['UPDATE_FEED_URL'])
    subprocess.run(command, cwd=root, check=True)
    if args.platform == 'android':
        mapping = root / 'build/app/outputs/mapping/release/mapping.txt'
        if not mapping.exists():
            raise RuntimeError('R8 mapping missing; release protection is unverified')
        shutil.copy2(mapping, symbols / 'r8-mapping.txt')


if __name__ == '__main__':
    main()
