import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const headers={"Access-Control-Allow-Origin":Deno.env.get("APP_ORIGIN")??"https://even.app","Access-Control-Allow-Headers":"authorization,apikey,content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Vary":"Origin"};
const response=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...headers,"Content-Type":"application/json"}});
Deno.serve(async req=>{
 if(req.method==="OPTIONS") return new Response("ok",{headers});
 if(req.method!=="POST") return response({error:"method_not_allowed"},405);
 const bearer=req.headers.get("Authorization"); if(!bearer?.startsWith("Bearer ")) return response({error:"unauthorized"},401);
 try{
  const client=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_ANON_KEY")!,{global:{headers:{Authorization:bearer}}});
  const {data:{user},error:authError}=await client.auth.getUser(); if(authError||!user) return response({error:"unauthorized"},401);
  const {token}=await req.json(); if(typeof token!=="string"||!/^[a-f0-9]{64}$/i.test(token)) return response({error:"invalid_invite"},400);
  const digest=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(token));
  const hash=Array.from(new Uint8Array(digest),b=>b.toString(16).padStart(2,"0")).join("");
  const {data:groupId,error}=await client.rpc("accept_group_invite",{p_token_hash:hash});
  if(error) return response({error:"invite_invalid_expired_or_used"},400);
  return response({group_id:groupId,joined:true});
 }catch{return response({error:"invalid_request"},400);}
});
