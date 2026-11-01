"""One-time GitHub setup: public metadata repo + repo-scoped deploy key.

Run via uv with pynacl and cryptography. Credentials stay in process memory.
"""
import base64
import json
import subprocess
import urllib.request
import urllib.error
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PrivateFormat, PublicFormat, NoEncryption
from nacl.public import PublicKey, SealedBox

OWNER = 'Kiencodon777'
SOURCE = OWNER + '/ClearTok-Pro-Reborn'
FEED = OWNER + '/ClearTok-Update-Feed'


def main():
    result = subprocess.run(['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n\n', text=True, capture_output=True, check=True)
    fields = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
    token = fields.get('password')
    if not token:
        raise RuntimeError('GitHub authentication unavailable')

    def api(path, method='GET', data=None, optional=False):
        request = urllib.request.Request('https://api.github.com/' + path,
            data=json.dumps(data).encode() if data is not None else None,
            headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
                     'Content-Type': 'application/json', 'User-Agent': 'ClearTok-feed-setup'}, method=method)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            if optional and error.code == 404:
                return None
            raise RuntimeError(f'GitHub {method} {path}: HTTP {error.code}') from None

    if api('user')['login'].lower() != OWNER.lower():
        raise RuntimeError('Wrong authenticated GitHub account')
    repo = api('repos/' + FEED, optional=True)
    if repo is None:
        repo = api('user/repos', 'POST', {'name': 'ClearTok-Update-Feed', 'private': False,
            'auto_init': True, 'description': 'Public ClearTok update metadata only. Application source remains private.'})
    if repo['private'] or repo['default_branch'] != 'main':
        raise RuntimeError('Feed repo must be public and use main; no visibility changes performed')

    secret = api('repos/' + SOURCE + '/actions/secrets/UPDATE_FEED_SSH_KEY', optional=True)
    if secret is None:
        private = Ed25519PrivateKey.generate()
        public = private.public_key().public_bytes(Encoding.OpenSSH, PublicFormat.OpenSSH).decode()
        pem = private.private_bytes(Encoding.PEM, PrivateFormat.OpenSSH, NoEncryption())
        public_key = api('repos/' + SOURCE + '/actions/secrets/public-key')
        encrypted = base64.b64encode(SealedBox(PublicKey(base64.b64decode(public_key['key']))).encrypt(pem)).decode()
        deploy = api('repos/' + FEED + '/keys', 'POST', {'title': 'ClearTok release metadata publisher', 'key': public, 'read_only': False})
        try:
            api('repos/' + SOURCE + '/actions/secrets/UPDATE_FEED_SSH_KEY', 'PUT', {'encrypted_value': encrypted, 'key_id': public_key['key_id']})
        except Exception:
            api('repos/' + FEED + '/keys/' + str(deploy['id']), 'DELETE')
            raise
    for name, value in {'UPDATE_FEED_REPO': FEED,
                        'UPDATE_FEED_URL': 'https://raw.githubusercontent.com/' + FEED + '/main/update.json'}.items():
        existing = api('repos/' + SOURCE + '/actions/variables/' + name, optional=True)
        if existing is None:
            api('repos/' + SOURCE + '/actions/variables', 'POST', {'name': name, 'value': value})
        else:
            api('repos/' + SOURCE + '/actions/variables/' + name, 'PATCH', {'name': name, 'value': value})
    latest = api('repos/' + SOURCE + '/releases/latest')
    metadata = {'version': latest['tag_name'].removeprefix('v'), 'notes': 'Bản phát hành ClearTok Pro Reborn. Xem ghi chú đầy đủ trên GitHub Releases.', 'url': latest['html_url']}
    existing = api('repos/' + FEED + '/contents/update.json', optional=True)
    payload = {'message': 'Publish latest ClearTok version metadata', 'content': base64.b64encode((json.dumps(metadata, ensure_ascii=False, indent=2) + '\n').encode()).decode()}
    if existing:
        payload['sha'] = existing['sha']
    api('repos/' + FEED + '/contents/update.json', 'PUT', payload)
    print('Public metadata feed configured: https://github.com/' + FEED)
    print('Scoped deploy key stored as encrypted Actions secret; no application source published.')


if __name__ == '__main__':
    main()
