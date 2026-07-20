// supabase/functions/send-push-notification/index.ts
//
// Supabase Edge Function — إرسال Firebase Cloud Messaging Push Notifications
//
// تُستدعى من:
//   1. Database Trigger عند كل INSERT في customers / production_reports
//   2. يمكن استدعاؤها مباشرة من Flutter للإرسال الفوري
//
// المنطق:
//   1. استلام factory_id + actor_id + title + body
//   2. جلب جميع fcm_tokens من workers حيث factory_id = X
//   3. استثناء التوكن الخاص بـ actor_id (صاحب العملية)
//   4. إرسال Push Notification عبر Firebase HTTP v1 API
//
// ⚠️ متغيرات البيئة المطلوبة في Supabase Dashboard:
//   FIREBASE_SERVICE_ACCOUNT_JSON  — محتوى ملف service-account.json كاملاً
//   SUPABASE_URL                   — تلقائي في Edge Functions
//   SUPABASE_SERVICE_ROLE_KEY      — تلقائي في Edge Functions

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Deno type declaration for VS Code compatibility ────────────────────────
// Supabase Edge Functions تعمل على Deno runtime — هذا التصريح يُعرّف Deno لـ VS Code
declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

// ─── نوع بيانات الطلب الواردة ───────────────────────────────────────────────
interface NotificationPayload {
  factory_id: string;
  actor_id: string | null;   // auth.uid() للشخص الذي أضاف السجل
  title: string;
  body: string;
  table_name?: string;
}

// ─── دالة توليد JWT لـ Firebase HTTP v1 API ─────────────────────────────────
// Firebase v1 يتطلب OAuth2 Bearer Token مُولَّد من Service Account
async function getFirebaseAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const expiry = now + 3600; // صالح لساعة واحدة

  // بناء JWT Header + Payload
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: expiry,
  };

  const encode = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const signingInput = `${encode(header)}.${encode(payload)}`;

  // استيراد المفتاح الخاص من Service Account
  const privateKeyPem = serviceAccount.private_key;
  const pemContent = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "");
  
  const binaryKey = Uint8Array.from(atob(pemContent), (c) => c.charCodeAt(0));
  
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const sigBase64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const jwt = `${signingInput}.${sigBase64}`;

  // استبدال JWT بـ Access Token من Google OAuth2
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) {
    throw new Error(`OAuth2 Token Error: ${JSON.stringify(tokenData)}`);
  }
  return tokenData.access_token;
}

// ─── إرسال رسالة FCM لتوكن واحد ─────────────────────────────────────────────
async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  fcmToken: string,
  title: string,
  body: string
): Promise<{ success: boolean; token: string; error?: string }> {
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  const message = {
    message: {
      token: fcmToken,
      notification: {
        title,
        body,
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channel_id: "factory_push_channel",
          icon: "ic_launcher",
        },
      },
      // بيانات إضافية (Data payload) للمعالجة في Flutter
      data: {
        title,
        body,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
  };

  try {
    const response = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    });

    if (response.ok) {
      return { success: true, token: fcmToken.substring(0, 20) + "..." };
    } else {
      const errorBody = await response.text();
      return { success: false, token: fcmToken.substring(0, 20) + "...", error: errorBody };
    }
  } catch (err) {
    return { success: false, token: fcmToken.substring(0, 20) + "...", error: String(err) };
  }
}

// ─── Handler الرئيسي ─────────────────────────────────────────────────────────
serve(async (req: Request) => {
  // CORS للتطوير
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "Authorization, Content-Type",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method Not Allowed" }), { status: 405 });
  }

  try {
    // ─── 1. تحليل الطلب ────────────────────────────────────────────
    const payload: NotificationPayload = await req.json();
    const { factory_id, actor_id, title, body } = payload;

    if (!factory_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: "factory_id, title, body مطلوبة" }),
        { status: 400 }
      );
    }

    console.log(`📬 إرسال إشعار | factory=${factory_id} | actor=${actor_id} | ${title}`);

    // ─── 2. تحميل Service Account من المتغيرات البيئية ─────────────
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!serviceAccountJson) {
      throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON غير موجود في متغيرات البيئة");
    }
    const serviceAccount = JSON.parse(serviceAccountJson);
    const projectId = serviceAccount.project_id;

    // ─── 3. إنشاء Supabase Client للاستعلام عن FCM Tokens ──────────
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // ─── 4. جلب كل FCM Tokens لعمال المصنع ─────────────────────────
    const { data: workers, error: workersError } = await supabaseClient
      .from("workers")
      .select("id, email, fcm_token")
      .eq("factory_id", factory_id)
      .not("fcm_token", "is", null);

    if (workersError) {
      throw new Error(`خطأ في جلب العمال: ${workersError.message}`);
    }

    if (!workers || workers.length === 0) {
      console.log("⚠️ لا يوجد عمال مسجلون بـ FCM Token في هذا المصنع.");
      return new Response(JSON.stringify({ sent: 0, message: "لا يوجد tokens" }), { status: 200 });
    }

    // ─── 5. الحصول على email الـ actor لاستثنائه ───────────────────
    let actorEmail: string | null = null;
    if (actor_id) {
      // نجلب email المستخدم من auth.users
      const { data: userData } = await supabaseClient.auth.admin.getUserById(actor_id);
      actorEmail = userData?.user?.email ?? null;
    }

    // ─── 6. تصفية التوكنات: استثناء صاحب العملية ──────────────────
    const targetWorkers = workers.filter((w: { id: string; email: string; fcm_token: string }) => {
      if (!w.fcm_token) return false;
      // المنع بالـ id المباشر
      if (actor_id && w.id === actor_id) {
        console.log(`⏭️ تجاهل: صاحب العملية (id=${actor_id})`);
        return false;
      }
      // المنع بالـ email (احتياطي)
      if (actorEmail && w.email === actorEmail) {
        console.log(`⏭️ تجاهل: صاحب العملية (email=${actorEmail})`);
        return false;
      }
      return true;
    });

    if (targetWorkers.length === 0) {
      console.log("ℹ️ لا يوجد مستلمون بعد استثناء صاحب العملية.");
      return new Response(JSON.stringify({ sent: 0, message: "تم استثناء الجميع" }), { status: 200 });
    }

    // ─── 7. توليد Firebase Access Token ────────────────────────────
    const accessToken = await getFirebaseAccessToken(serviceAccount);

    // ─── 8. إرسال Push لكل جهاز بشكل متوازٍ ─────────────────────
    const sendPromises = targetWorkers.map((w: { fcm_token: string }) =>
      sendFcmMessage(accessToken, projectId, w.fcm_token, title, body)
    );
    const results = await Promise.all(sendPromises);

    const successCount = results.filter(
      (r: { success: boolean; token: string; error?: string }) => r.success
    ).length;
    const failedCount = results.filter(
      (r: { success: boolean; token: string; error?: string }) => !r.success
    ).length;

    console.log(`✅ تم الإرسال: ${successCount} نجح | ${failedCount} فشل`);
    
    return new Response(
      JSON.stringify({ sent: successCount, failed: failedCount, details: results }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("❌ Edge Function Error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
