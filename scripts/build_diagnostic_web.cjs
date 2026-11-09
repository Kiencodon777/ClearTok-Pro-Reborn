// Build a standalone test harness from the exact transport embedded in mobile.
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync('lib/api/tiktok_mutation_transport.dart', 'utf8');
const body = source.match(/const functionBody = r'''([\s\S]*?)''';/)[1];
const bridge = source.match(/mainWorldBridgeJs = r'''([\s\S]*?)''';/)[1];
const out = path.resolve(process.argv[2] || 'build/diagnostic-web');
fs.mkdirSync(out, {recursive:true});
for (const name of ['index.html','app.js']) fs.copyFileSync('diagnostic_web/'+name,path.join(out,name));
fs.writeFileSync(path.join(out,'transport.js'), 'window.installMobileBridge = function(window, document, location, XMLHttpRequest, MutationObserver) {\n'+bridge+'\n};\nwindow.mobileTransport = async function(window, document, location, navigator, path, params, aid) {\n'+body+'\n};\n');
console.log('Diagnostic web built at '+out);
