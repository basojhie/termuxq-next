// Deploy with: supabase functions deploy ticket-notify
// Keep all Telegram and service-role keys in server-side secrets only.
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const respond = (payload: Record<string, unknown>, status = 200) =>
  Response.json(payload, { status, headers: corsHeaders });

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return respond({ error: "Method not allowed" }, 405);
  const authorization = request.headers.get("Authorization");
  if (!authorization || !authorization.startsWith("Bearer ")) return respond({ error: "Login diperlukan." }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY") || Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
  const chatId = Deno.env.get("TELEGRAM_CHAT_ID");
  const allowedUserIds = (Deno.env.get("TELEGRAM_NOTIFY_ALLOWED_USER_IDS") || "")
    .split(",").map(value => value.trim()).filter(Boolean);
  if (!supabaseUrl || !publishableKey || !serviceRoleKey || !botToken || !chatId || !allowedUserIds.length) {
    return respond({ error: "Secret Edge Function belum lengkap; periksa token, chat ID, allowlist pengguna, dan service role server." }, 503);
  }

  try {
    const authClient = createClient(supabaseUrl, publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: authorization } },
    });
    const authResult = await authClient.auth.getUser();
    const user = authResult.data.user;
    if (authResult.error || !user) return respond({ error: "Sesi tidak valid; login ulang." }, 401);
    if (!allowedUserIds.includes(user.id)) return respond({ error: "Akun ini tidak diizinkan mengirim notifikasi Telegram." }, 403);

    const body = await request.json();
    const message = typeof body?.text === "string" ? body.text.trim() : "";
    if (!message || message.length > 3000) return respond({ error: "Pesan wajib diisi dan maksimal 3000 karakter." }, 400);

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const claim = await adminClient.rpc("termuxq_claim_notification_slot", { p_user_id: user.id });
    if (claim.error) return respond({ error: "Pembatasan notifikasi server belum siap. Jalankan schema/migrasi terbaru." }, 503);
    const slot = Array.isArray(claim.data) ? claim.data[0] : claim.data;
    if (!slot?.allowed) {
      if (slot?.reason === "cooldown") return respond({ error: "Tunggu minimal 60 detik sebelum mengirim notifikasi berikutnya." }, 429);
      if (slot?.reason === "hourly_limit") return respond({ error: "Batas 20 notifikasi per jam tercapai." }, 429);
      return respond({ error: "Pengiriman tidak diizinkan oleh pembatasan server." }, 403);
    }

    const telegramResponse = await fetch("https://api.telegram.org/bot" + botToken + "/sendMessage", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: chatId, text: message, disable_web_page_preview: true }),
    });
    const telegramResult = await telegramResponse.json().catch(() => ({}));
    if (!telegramResponse.ok || telegramResult.ok !== true) return respond({ error: "Telegram menolak pengiriman. Periksa bot dan chat ID." }, 502);
    return respond({ sent: true });
  } catch (_error) {
    return respond({ error: "Permintaan notifikasi tidak dapat diproses." }, 400);
  }
});
