import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
import xml.etree.ElementTree as ET

root=Path(__file__).parents[1]
spec=importlib.util.spec_from_file_location('build_obfuscated',root/'scripts/build_obfuscated.py')
build=importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)
class NativeAuthConfigTest(unittest.TestCase):
    def test_android_keeps_callback_and_disables_duplicate_flutter_handler(self):
        manifest=ET.parse(root/'android/app/src/main/AndroidManifest.xml')
        ns='{http://schemas.android.com/apk/res/android}'
        activity=manifest.find('.//activity')
        metadata={item.get(ns+'name'):item.get(ns+'value') for item in activity.findall('meta-data')}
        self.assertEqual(metadata['flutter_deeplinking_enabled'],'false')
        self.assertEqual(activity.get(ns+'name'),'com.cleartok.reborn.MainActivity')
        data=activity.find("intent-filter/data")
        self.assertEqual(data.get(ns+'scheme'),'cleartok')
        self.assertEqual(data.get(ns+'host'),'auth-callback')
    def test_ios_callback_is_idempotent_and_preserves_bundle_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            plist=Path(directory)/'Info.plist'
            plist.write_bytes(plistlib.dumps({'CFBundleIdentifier':'com.cleartok.fixture','CFBundleURLTypes':[{'CFBundleURLSchemes':['existing']}]}))
            build.configure_ios_callback(plist)
            build.configure_ios_callback(plist)
            data=plistlib.loads(plist.read_bytes())
            self.assertFalse(data['FlutterDeepLinkingEnabled'])
            self.assertEqual(data['CFBundleIdentifier'],'com.cleartok.fixture')
            self.assertEqual(data['CFBundleURLTypes'],[{'CFBundleURLSchemes':['existing']},{'CFBundleURLSchemes':['cleartok']}])
