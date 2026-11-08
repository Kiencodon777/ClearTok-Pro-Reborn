const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),yaml=require('yaml');
test('authenticated WebView keeps OS TLS validation and restricted content',()=>{
 const source=fs.readFileSync('lib/ui/screens/tiktok_browser_screen.dart','utf8');
 assert.ok(!source.includes('ServerTrustAuthResponseAction.PROCEED'));
 for(const value of ['allowFileAccess: false','allowContentAccess: false','MIXED_CONTENT_NEVER_ALLOW','safeBrowsingEnabled: true','resolveTikTokDeepLink(uri)','LaunchMode.externalApplication'])assert.ok(source.includes(value),value);
});
test('release has blocking validation and no signer fallback',()=>{
 const wf=yaml.parse(fs.readFileSync('.github/workflows/release.yml','utf8'));
 const steps=wf.jobs.build.steps;
 assert.ok(steps.some(s=>s.run==='flutter analyze lib test'&&!s['continue-on-error']));
 assert.ok(steps.some(s=>s.run==='dart format --output=none --set-exit-if-changed lib test'));
 assert.ok(!steps.some(s=>s.run?.includes('--update-goldens')));
 assert.ok(!steps.find(s=>s.name==='Configure verified Android production signer').if.includes('KEYSTORE'));
 assert.ok(!steps.find(s=>s.name==='Build APK').run.includes('else'));
 for(const job of Object.values(wf.jobs))for(const step of job.steps||[])if(step.uses)assert.match(step.uses,/@[a-f0-9]{40}$/);
});
