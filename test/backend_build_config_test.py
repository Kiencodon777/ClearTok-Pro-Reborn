import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('config', Path(__file__).parents[1] / 'scripts/validate_backend_config.py')
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class BackendBuildConfigTest(unittest.TestCase):
    def test_public_configuration(self):
        config.validate('https://project.supabase.co', 'sb_publishable_fixture_public_value')

    def test_rejects_private_keys_and_unsafe_urls(self):
        for url in ['http://project.supabase.co', 'https://user@project.supabase.co',
                    'https://@project.supabase.co', 'https://project.supabase.co:444',
                    'https://project.supabase.co/path', 'https://project.supabase.co/?token=x']:
            with self.assertRaises(ValueError):
                config.validate(url, 'sb_publishable_fixture_public_value')
        for key in ['', 'sb_secret_example', 'invalid.jwt.value']:
            with self.assertRaises(ValueError):
                config.validate('https://project.supabase.co', key)
