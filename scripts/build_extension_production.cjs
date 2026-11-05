const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const {minify}=require('terser'),obfuscator=require('javascript-obfuscator');
async function main(){
  const out='build/cleartok-web-production';
  execFileSync(process.execPath,['scripts/build_web_extension.cjs',out],{stdio:'inherit'});
  for(const file of fs.readdirSync(out)){
    if(!/\.(m?js)$/.test(file))continue;
    const filename=path.join(out,file),source=fs.readFileSync(filename,'utf8');
    const result=await minify(source,{module:file.endsWith('.mjs'),mangle:true,compress:true,format:{comments:false}});
    const protectedCode=obfuscator.obfuscate(result.code,{compact:true,stringArray:false,
      controlFlowFlattening:false,deadCodeInjection:false,renameGlobals:false,
      simplify:false,sourceMap:false,target:'browser-no-eval'}).getObfuscatedCode();
    fs.writeFileSync(filename,protectedCode);
  }
  fs.unlinkSync(path.join(out,'README.md'));
  if(fs.readdirSync(out).some(x=>/\.map$|\.env|symbols/i.test(x)))throw Error('Private build files found');
  console.log('Production extension ready at '+out);
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
