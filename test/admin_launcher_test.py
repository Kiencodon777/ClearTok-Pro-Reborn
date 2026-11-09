import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('launcher', Path(__file__).parents[1] / 'scripts/start_admin.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class AdminLauncherTest(unittest.TestCase):
    def test_serves_only_built_admin_on_loopback_before_opening_browser(self):
        with patch.object(launcher.shutil, 'which', return_value='node'), \
             patch.object(launcher.subprocess, 'run') as build, \
             patch.object(launcher, 'ThreadingHTTPServer') as server, \
             patch.object(launcher.webbrowser, 'open') as browser:
            running = server.return_value.__enter__.return_value
            running.server_port = 12345
            running.serve_forever.side_effect = KeyboardInterrupt
            launcher.main()
            self.assertEqual(server.call_args.args[0], ('127.0.0.1', 0))
            root = Path(__file__).resolve().parents[1]
            self.assertEqual(server.call_args.args[1].keywords['directory'], str(root / 'build/admin'))
            build.assert_called_once_with(['node', 'scripts/build_admin.cjs'], cwd=root, check=True)
            browser.assert_called_once_with('http://127.0.0.1:12345/')
