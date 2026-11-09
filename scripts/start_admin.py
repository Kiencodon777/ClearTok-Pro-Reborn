"""Build and open the admin on loopback; no backend configuration is required."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import shutil
import subprocess
import webbrowser


def main():
    root = Path(__file__).resolve().parent.parent
    node = shutil.which('node')
    if not node:
        raise RuntimeError('Install Node.js, then run Open-Admin.cmd again')
    subprocess.run([node, 'scripts/build_admin.cjs'], cwd=root, check=True)
    handler = partial(SimpleHTTPRequestHandler, directory=str(root / 'build/admin'))
    with ThreadingHTTPServer(('127.0.0.1', 0), handler) as server:
        url = f'http://127.0.0.1:{server.server_port}/'
        print('Admin: ' + url, flush=True)
        print('Keep this window open. Press Ctrl+C to stop.', flush=True)
        webbrowser.open(url)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == '__main__':
    main()
