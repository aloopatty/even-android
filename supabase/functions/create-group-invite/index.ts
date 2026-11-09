import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const headers = { "Access-Control-Allow-Origin": Deno.env.get("APP_ORIGIN") ?? "https://even.app", "Access-Control-Allow-Headers": "authorization, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS", "Vary": "Origin" };
const response = (body: unknown, status=200) => new Response(JSON.stringify(body), {status,headers:{...headers,"Content-Type":"application/json"}});
Deno.serve(async req => {
 if(req.method==="OPTIONS") return new Response("ok",{headers});
 if(req.method!=="POST") return response({error:"method_not_allowed"},405);
 const bearer=req.headers.get("Authorization"); if(!bearer?.startsWith("Bearer ")) return response({error:"unauthorized"},401);
 try {
  const client=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_ANON_KEY")!,{global:{headers:{Authorization:bearer}}});
  const {data:{user},error:authError}=await client.auth.getUser(); if(authError||!user) return response({error:"unauthorized"},401);
  const body=await req.json(); const groupId=String(body.group_id??""); const days=Math.min(Math.max(Number(body.expires_in_days??7),1),30);
  const maxUses=body.max_uses==null?null:Math.min(Math.max(Number(body.max_uses),1),500);
  if(!/^[0-9a-f-]{36}$/i.test(groupId)) return response({error:"invalid_group_id"},400);
  const {data:group,error}=await client.from("groups").select("id,created_by").eq("id",groupId).maybeSingle();
  if(error||!group||group.created_by!==user.id) return response({error:"owner_only"},403);
  const bytes=crypto.getRandomValues(new Uint8Array(32)); const token=Array.from(bytes,b=>b.toString(16).padStart(2,"0")).join("");
  const digest=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(token));
  const hash=Array.from(new Uint8Array(digest),b=>b.toString(16).padStart(2,"0")).join("");
  const {error:insertError}=await client.rpc("create_group_invite",{p_group_id:groupId,p_token_hash:hash,p_expires_at:new Date(Date.now()+days*86400000).toISOString(),p_max_uses:maxUses});
  if(insertError) return response({error:"invite_creation_failed"},400);
  const base=Deno.env.get("INVITE_BASE_URL")??"https://even.app/join";
  return response({invite_url:base+"?token="+token,expires_in_days:days,max_uses:maxUses});
 } catch { return response({error:"invalid_request"},400); }
});
