const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
test('web detects the reported empty-200 log and executes shared transport',async()=>{
  const elements={};
  const document={getElementById:id=>elements[id]||(elements[id]={value:'',textContent:'',click(){this.onclick();}})};
  const window={};
  const context=vm.createContext({window,document,URL,AbortController,Event,setTimeout,clearTimeout,setInterval,clearInterval});
  vm.runInContext(fs.readFileSync('build/diagnostic-web/transport.js','utf8'),context);
  vm.runInContext(fs.readFileSync('diagnostic_web/app.js','utf8'),context);
  elements.example.onclick();
  assert.match(elements.diagnosis.textContent,/HTTP 200, body rỗng/);
  assert.match(elements.diagnosis.textContent,/unfollow: thành công/);
  await elements.tests.onclick();
  assert.equal(elements.results.textContent.split('\n').length,5);
  assert.ok(!elements.results.textContent.includes('FAIL'));
});
