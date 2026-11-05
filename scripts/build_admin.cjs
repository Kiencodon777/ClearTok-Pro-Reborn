const esbuild=require('esbuild'),fs=require('node:fs');
fs.mkdirSync('build/admin',{recursive:true});
fs.copyFileSync('admin/index.html','build/admin/index.html');
esbuild.buildSync({entryPoints:['admin/app.js'],bundle:true,minify:true,sourcemap:false,outfile:'build/admin/app.js',format:'esm',platform:'browser'});
