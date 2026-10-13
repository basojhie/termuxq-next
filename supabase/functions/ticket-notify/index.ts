// Deploy with: supabase functions deploy ticket-notify
// Configure server-side secrets. Never store a Telegram bot token in the public frontend.
// supabase secrets set TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=...
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return Response.json({ error: "Method not allowed" }, { status: 405, headers: corsHeaders });
  const authorization = request.headers.get("Authorization");
  if (!authorization || !authorization.startsWith("Bearer ")) {
    return Response.json({ error: "Login diperlukan." }, { status: 401, headers: corsHeaders });
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY") || Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
  const chatId = Deno.env.get("TELEGRAM_CHAT_ID");
  if (!supabaseUrl || !publishableKey || !botToken || !chatId) {
    return Response.json({ error: "Konfigurasi secret Edge Function belum lengkap." }, { status: 503, headers: corsHeaders });
  }
  try {
    const supabase = createClient(supabaseUrl, publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: authorization } },
    });
    const result = await supabase.auth.getUser();
    if (result.error || !result.data.user) {
      return Response.json({ error: "Sesi tidak valid; login ulang." }, { status: 401, headers: corsHeaders });
    }
    const body = await request.json();
    const message = typeof body?.text === "string" ? body.text.trim() : "";
    if (!message || message.length > 3000) {
      return Response.json({ error: "Pesan wajib diisi dan maksimal 3000 karakter." }, { status: 400, headers: corsHeaders });
    }
    const telegramResponse = await fetch("https://api.telegram.org/bot" + botToken + "/sendMessage", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: chatId, text: message, disable_web_page_preview: true }),
    });
    const telegramResult = await telegramResponse.json().catch(() => ({}));
    if (!telegramResponse.ok || telegramResult.ok !== true) {
      return Response.json({ error: "Telegram menolak pengiriman. Periksa bot dan chat ID." }, { status: 502, headers: corsHeaders });
    }
    return Response.json({ sent: true }, { status: 200, headers: corsHeaders });
  } catch (_error) {
    return Response.json({ error: "Permintaan notifikasi tidak dapat diproses." }, { status: 400, headers: corsHeaders });
  }
});
