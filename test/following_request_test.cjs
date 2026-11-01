const {test}=require('node:test');
const assert=require('node:assert/strict');
const source=require('node:fs').readFileSync('lib/api/tiktok_client.dart','utf8');
const section=source.slice(source.indexOf('Future<FollowingScanResult> fetchFollowingUsersBatch'));
const body=section.match(/const functionBody = r'''([\s\S]*?)''';/)[1];
const AsyncFunction=Object.getPrototypeOf(async function(){}).constructor;
test('Following request carries BOTH server cursor boundaries to the second and third pages',async()=>{
  let page=0;
  const fetch=async url=>{
    const q=new URL(url).searchParams;
    const expected=[['0','0'],['900','600'],['600','300']][page];
    assert.equal(q.get('maxCursor'),expected[0]);
    assert.equal(q.get('minCursor'),expected[1]);
    page++;
    return {text:async()=>JSON.stringify({status_code:0,maxCursor:page===1?'900':'600',minCursor:page===1?'600':'300'})};
  };
  const run=new AsyncFunction('fetch','URLSearchParams','aid','cursor','minCursor','secUid',body);
  let max='0',min='0';
  for(let i=0;i<3;i++){
    const data=JSON.parse(await run(fetch,URLSearchParams,1988,max,min,'viewer'));
    max=data.maxCursor;min=data.minCursor;
  }
  assert.equal(page,3);
});
