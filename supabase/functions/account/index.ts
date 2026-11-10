import { createClient } from 'npm:@supabase/supabase-js@2.118.0';

const headers = {'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info'};
Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('', {headers});
  if (request.method !== 'POST') return new Response('', {status:405,headers});
  try {
    const authorization = request.headers.get('authorization');
    if (!authorization?.startsWith('Bearer ')) return new Response('', {status:401,headers});
    const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!,
      {global:{headers:{Authorization:authorization}},auth:{persistSession:false}});
    const {data:{user},error:authError} = await client.auth.getUser();
    if (authError || !user) return new Response('', {status:401,headers});
    const body = await request.text();
    const byteLength = typeof TextEncoder !== 'undefined' ? new TextEncoder().encode(body).byteLength : body.length;
    if (byteLength > 4096) return new Response('', {status:413,headers});
    const input = JSON.parse(body);
    if (typeof input.action !== 'string' || !input.payload || typeof input.payload !== 'object' || Array.isArray(input.payload))
      return new Response('', {status:400,headers});
    const {data,error} = await client.rpc(input.admin === true ? 'admin_api' : 'account_api',
      {action:input.action,payload:input.payload});
    if (error) {
      if (input.admin === true && input.action === 'restore_device' &&
          error.code === '42501' && error.message === 'Device limit reached') {
        let devices = [];
        try { devices = JSON.parse(error.details || '[]'); } catch (_) {}
        return Response.json({code:'DEVICE_LIMIT_REACHED', devices: Array.isArray(devices) ? devices : []}, {status:409, headers});
      }
      if (error.code === 'PT409' && error.message === 'QUOTA_EXHAUSTED') {
        return Response.json({code:'QUOTA_EXHAUSTED', quota_remaining:0}, {status:409, headers});
      }
      const isRateLimit = String(error.message || '').includes('Rate limit exceeded') || error.code === '429';
      return Response.json(
        {error: isRateLimit ? 'Rate limit exceeded' : 'Request denied'},
        {status: isRateLimit ? 429 : 403, headers},
      );
    }
    return Response.json(data, {headers});
  } catch {
    return Response.json({error:'Invalid request'}, {status:400,headers});
  }
});
