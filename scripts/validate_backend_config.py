"""Validate public client configuration without printing its values."""
import base64
import json
import os
from urllib.parse import urlparse


def validate(url, key):
    parsed = urlparse(url)
    if (parsed.scheme != 'https' or not parsed.hostname or parsed.username is not None
        or parsed.password is not None or parsed.port not in (None, 443)
        or parsed.path not in ('', '/') or parsed.query or parsed.fragment):
        raise ValueError('A valid HTTPS SUPABASE_URL is required')
    if key.startswith('sb_publishable_') and len(key) > 20:
        return
    try:
        payload = key.split('.')[1]
        claims = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
        if claims.get('role') == 'anon':
            return
    except (IndexError, ValueError, UnicodeError):
        pass
    raise ValueError('SUPABASE_PUBLISHABLE_KEY must be a public publishable/anon key')


if __name__ == '__main__':
    validate(os.environ.get('SUPABASE_URL', ''), os.environ.get('SUPABASE_PUBLISHABLE_KEY', ''))
    print('Public backend configuration validated')
