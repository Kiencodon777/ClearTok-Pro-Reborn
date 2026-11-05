"""Local-only TLS fixture. Run with: python test/tls_fixture.py --openssl PATH"""
import argparse
import datetime
import http.server
import json
import ssl
import subprocess
import tempfile
import threading
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--openssl', default='openssl')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)

        def openssl(*command):
            subprocess.run([args.openssl, *map(str, command)], cwd=root,
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        openssl('req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2',
                '-subj', '/CN=ClearTok Fixture CA', '-keyout', 'ca.key', '-out', 'ca.crt')
        (root / 'ext.cnf').write_text('subjectAltName=IP:127.0.0.1,IP:10.0.2.2,DNS:localhost\n')
        for name, subject, days in [('valid', 'localhost', '2'),
                                    ('expired', 'localhost', '0'),
                                    ('wrong-host', 'wrong.invalid', '2')]:
            openssl('req', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=' + subject,
                    '-keyout', name + '.key', '-out', name + '.csr')
            ext = root / ('wrong.cnf' if name == 'wrong-host' else 'ext.cnf')
            if name == 'wrong-host':
                ext.write_text('subjectAltName=DNS:wrong.invalid\n')
            openssl('x509', '-req', '-in', name + '.csr', '-CA', 'ca.crt', '-CAkey',
                    'ca.key', '-CAcreateserial', '-out', name + '.crt', '-days', days,
                    '-extfile', ext)
        for name in ('self-signed', 'other-ca'):
            openssl('req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2',
                    '-subj', '/CN=localhost', '-addext', 'subjectAltName=IP:127.0.0.1,DNS:localhost',
                    '-keyout', name + '.key', '-out', name + '.crt')
        openssl('req', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=localhost',
                '-keyout', 'untrusted-ca.key', '-out', 'untrusted-ca.csr')
        openssl('x509', '-req', '-in', 'untrusted-ca.csr', '-CA', 'other-ca.crt',
                '-CAkey', 'other-ca.key', '-CAcreateserial', '-out', 'untrusted-ca.crt',
                '-days', '2', '-extfile', 'ext.cnf')

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                print(json.dumps({'port': self.server.server_port, 'path': self.path,
                                  'time': datetime.datetime.now(datetime.timezone.utc).isoformat()}), flush=True)
                if self.path == '/redirect-http':
                    self.send_response(302)
                    self.send_header('Location', 'http://127.0.0.1:18080/endpoint')
                elif self.path == '/redirect-external':
                    self.send_response(302)
                    self.send_header('Location', 'https://example.invalid/endpoint')
                else:
                    self.send_response(200)
                self.end_headers()
                self.wfile.write(b'ClearTok local TLS fixture')

            def log_message(self, *_):
                pass

        servers = []
        for port, name in [(18443, 'valid'), (18444, 'expired'), (18445, 'wrong-host'),
                           (18446, 'self-signed'), (18447, 'untrusted-ca')]:
            server = http.server.ThreadingHTTPServer(('0.0.0.0', port), Handler)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(root / (name + '.crt'), root / (name + '.key'))
            server.socket = context.wrap_socket(server.socket, server_side=True)
            servers.append(server)
        servers.append(http.server.ThreadingHTTPServer(('0.0.0.0', 18080), Handler))
        for server in servers:
            threading.Thread(target=server.serve_forever, daemon=True).start()
        print('Fixture CA:', root / 'ca.crt', flush=True)
        print('Ports: valid 18443, expired 18444, wrong-host 18445, self-signed 18446, untrusted 18447, HTTP 18080', flush=True)
        print('Use only a test device. Trust the fixture CA there for the valid case; Ctrl+C stops.', flush=True)
        threading.Event().wait()


if __name__ == '__main__':
    main()
