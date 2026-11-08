import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Storage } from "npm:@google-cloud/storage";

const cors = {
  "Access-Control-Allow-Origin": Deno.env.get("APP_ORIGIN") ?? "https://even.app",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401);
  try {
    const client = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authorization } } });
    const { data: { user }, error: authError } = await client.auth.getUser();
    if (authError || !user) return json({ error: "unauthorized" }, 401);
    const body = await req.json();
    const groupId = String(body.group_id ?? "");
    const mime = String(body.content_type ?? "");
    const size = Number(body.size_bytes);
    if (!/^[0-9a-f-]{36}$/i.test(groupId) ||
        !["image/jpeg", "image/png", "image/webp", "application/pdf"].includes(mime) ||
        !Number.isSafeInteger(size) || size < 1 || size > 10 * 1024 * 1024) {
      return json({ error: "invalid_upload" }, 400);
    }
    const { data: membership } = await client.from("group_members").select("group_id")
      .eq("group_id", groupId).eq("user_id", user.id).is("left_at", null).maybeSingle();
    if (!membership) return json({ error: "forbidden" }, 403);

    const credentials = JSON.parse(Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON")!);
    const storage = new Storage({ projectId: Deno.env.get("GOOGLE_CLOUD_PROJECT"), credentials });
    const objectKey = groupId + "/" + crypto.randomUUID();
    const file = storage.bucket(Deno.env.get("GCS_RECEIPTS_BUCKET")!).file(objectKey);
    const [uploadUrl] = await file.getSignedUrl({
      version: "v4", action: "write", expires: Date.now() + 5 * 60 * 1000,
      contentType: mime,
    });
    return json({ upload_url: uploadUrl, object_key: objectKey, expires_in_seconds: 300 });
  } catch {
    return json({ error: "upload_signing_failed" }, 500);
  }
});
