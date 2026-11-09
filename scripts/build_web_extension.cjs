const fs=require('node:fs'),path=require('node:path');
const out=path.resolve(process.argv[2]||'build/cleartok-web');fs.mkdirSync(out,{recursive:true});
const source=fs.readFileSync('lib/api/tiktok_mutation_transport.dart','utf8');
function body(method){const section=source.slice(source.indexOf(method));const m=section.match(/const functionBody = r'''([\s\S]*?)''';/);if(!m)throw Error('Missing mobile transport: '+method);return m[1];}
const template=fs.readFileSync('web_extension/page-api.template.js','utf8');
fs.writeFileSync(path.join(out,'page-api.mjs'),template.replace('/* MOBILE_TRANSPORT */',()=>body('Future<DeleteResult> perform')).replace('/* MOBILE_BRIDGE */',()=>source.match(/mainWorldBridgeJs = r'''([\s\S]*?)''';/)[1]));
for(const name of ['index.html','style.css','app.mjs','core.mjs','background.js','README.md'])fs.copyFileSync('web_extension/'+name,path.join(out,name));
const manifest=JSON.parse(fs.readFileSync('web_extension/manifest.json','utf8'));
if(process.env.GITHUB_RUN_NUMBER)manifest.version='2.3.'+process.env.GITHUB_RUN_NUMBER;
fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2));
require('esbuild').buildSync({stdin:{contents:fs.readFileSync('web_extension/app.mjs','utf8').replace("'./page-api.mjs'",JSON.stringify(path.resolve(out,'page-api.mjs'))),resolveDir:path.resolve('web_extension')},bundle:true,format:'esm',platform:'browser',outfile:path.join(out,'app.mjs'),define:{CLEARTOK_SUPABASE_URL:JSON.stringify(process.env.SUPABASE_URL||''),CLEARTOK_SUPABASE_KEY:JSON.stringify(process.env.SUPABASE_PUBLISHABLE_KEY||'')}});
console.log('Built full ClearTok web extension: '+out);
