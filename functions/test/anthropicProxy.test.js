const admin = require("firebase-admin");
const httpMocks = require("node-mocks-http");
const {getIdTokenForUid, getAppCheckHeaderForTests} = require("./helpers");

const myFunctions = require("../index");
const {resetAiConfigCache} = require("../aiConfig");

const db = admin.firestore();

/**
 * @param {string|null} idToken Bearer token, or null to omit the header.
 * @param {object} body request JSON body.
 * @return {Promise<{statusCode: number, body: object}>}
 */
async function callProxy(idToken, body) {
  const req = httpMocks.createRequest({
    method: "POST",
    headers: {
      ...(idToken ? {authorization: `Bearer ${idToken}`} : {}),
      ...(await getAppCheckHeaderForTests()),
    },
    body,
  });
  const res = httpMocks.createResponse({eventEmitter: require("events").EventEmitter});

  await myFunctions.anthropicProxy(req, res);
  return {statusCode: res.statusCode, body: res._getJSONData()};
}

describe("anthropicProxy", () => {
  let realFetch;

  beforeAll(() => {
    realFetch = global.fetch;
    // Only the real Anthropic call is faked — the Auth-emulator sign-in
    // call inside getIdTokenForUid() must still hit the real (emulated)
    // endpoint, so anything that isn't api.anthropic.com passes through.
    global.fetch = jest.fn((url, options) => {
      if (typeof url === "string" && url.includes("api.anthropic.com")) {
        return Promise.resolve({
          status: 200,
          json: () => Promise.resolve({
            content: [{type: "text", text: "mocked reply"}],
          }),
        });
      }
      return realFetch(url, options);
    });
  });

  afterAll(() => {
    global.fetch = realFetch;
  });

  afterEach(async () => {
    for (const col of ["ai_usage", "ai_token_usage", "config"]) {
      const snap = await db.collection(col).get();
      await Promise.all(snap.docs.map((d) => d.ref.delete()));
    }
    resetAiConfigCache();
    global.fetch.mockClear();
  });

  const anthropicCalls = () =>
    global.fetch.mock.calls.filter(([url]) => String(url).includes("api.anthropic.com"));

  test("rejects requests with no bearer token", async () => {
    const res = await callProxy(null, {tier: "quick", messages: [{role: "user", content: "hi"}]});
    expect(res.statusCode).toBe(401);
  });

  test("rejects an unknown tier", async () => {
    const idToken = await getIdTokenForUid("ai-user-1");
    const res = await callProxy(idToken, {tier: "ultra", messages: [{role: "user", content: "hi"}]});
    expect(res.statusCode).toBe(400);
  });

  test("rejects a request with no messages", async () => {
    const idToken = await getIdTokenForUid("ai-user-2");
    const res = await callProxy(idToken, {tier: "quick", messages: []});
    expect(res.statusCode).toBe(400);
  });

  test("proxies a valid request and never forwards the client's own model/max_tokens choice", async () => {
    const idToken = await getIdTokenForUid("ai-user-3");
    const res = await callProxy(idToken, {
      tier: "quick",
      system: "be nice",
      messages: [{role: "user", content: "hi"}],
      // A client could try to request the expensive model directly —
      // the proxy must ignore this and use the server-side tier mapping.
      model: "claude-opus-4-8",
      max_tokens: 999999,
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.content[0].text).toBe("mocked reply");

    const [, fetchOptions] = global.fetch.mock.calls.find(
        ([url]) => url.includes("api.anthropic.com"),
    );
    const forwardedBody = JSON.parse(fetchOptions.body);
    // quick tier 2026-07-08'de Haiku'dan Sonnet'e geçti (Türkçe kalitesi);
    // bu assert güncellenmemişti — denetimde yakalandı (2026-07-24).
    expect(forwardedBody.model).toBe("claude-sonnet-4-6");
    expect(forwardedBody.max_tokens).toBe(512);
  });

  // ── Girdi sınırları (denetim bulgusu 2026-07-24) ─────────────────────────
  // max_tokens yalnız ÇIKTIYI sınırlar. Bu testler, geçerli bir hesabın
  // devasa girdilerle fatura şişirmesini engelleyen tavanları kilitler.
  describe("girdi sınırları", () => {
    test("çok uzun metni reddeder (fatura koruması)", async () => {
      const idToken = await getIdTokenForUid("ai-limit-1");
      const res = await callProxy(idToken, {
        tier: "quick",
        messages: [{role: "user", content: "x".repeat(100001)}],
      });
      expect(res.statusCode).toBe(400);
      expect(global.fetch).not.toHaveBeenCalledWith(
          expect.stringContaining("api.anthropic.com"),
          expect.anything(),
      );
    });

    test("system prompt'u da metin bütçesine sayar", async () => {
      const idToken = await getIdTokenForUid("ai-limit-2");
      const res = await callProxy(idToken, {
        tier: "quick",
        system: "y".repeat(99000),
        messages: [{role: "user", content: "z".repeat(2000)}],
      });
      expect(res.statusCode).toBe(400);
    });

    test("çok fazla mesajı reddeder", async () => {
      const idToken = await getIdTokenForUid("ai-limit-3");
      const res = await callProxy(idToken, {
        tier: "quick",
        messages: Array.from({length: 31}, () => ({role: "user", content: "hi"})),
      });
      expect(res.statusCode).toBe(400);
    });

    test("çok fazla görseli reddeder", async () => {
      const idToken = await getIdTokenForUid("ai-limit-4");
      const img = {
        type: "image",
        source: {type: "base64", media_type: "image/jpeg", data: "AAAA"},
      };
      const res = await callProxy(idToken, {
        tier: "deep",
        messages: [{role: "user", content: [img, img, img]}],
      });
      expect(res.statusCode).toBe(400);
    });

    test("gerçek yemek fotoğrafı akışı (tek görsel + kısa metin) GEÇER", async () => {
      const idToken = await getIdTokenForUid("ai-limit-5");
      const res = await callProxy(idToken, {
        tier: "deep",
        // İstemci (food_analysis.dart) her zaman kind: food gönderir; görsel
        // artık yalnız bu türde kabul ediliyor (denetim C-1).
        kind: "food",
        messages: [{
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: "image/jpeg",
                // ~1MB base64 görsel — istemcinin ürettiğine yakın boyut.
                data: "A".repeat(1024 * 1024),
              },
            },
            {type: "text", text: "Yukarıdaki fotoğraftaki yemeği analiz et."},
          ],
        }],
      });
      expect(res.statusCode).toBe(200);
    });
  });

  // ── Denetim C-1 (2026-09-13): izin listesi + kind'sız çağrı tavanları ────
  describe("C-1 kötüye kullanım regresyonları", () => {
    test("document bloğu Anthropic'e hiç ulaşmaz", async () => {
      const idToken = await getIdTokenForUid("c1-doc");
      const res = await callProxy(idToken, {
        tier: "quick",
        messages: [{role: "user", content: [{
          type: "document",
          source: {type: "text", media_type: "text/plain", data: "x".repeat(400000)},
        }]}],
      });
      expect(res.statusCode).toBe(400);
      expect(anthropicCalls()).toHaveLength(0);
    });

    test("iç içe tool_result metni bütçeyi atlatamaz", async () => {
      const idToken = await getIdTokenForUid("c1-nested");
      const res = await callProxy(idToken, {
        tier: "quick",
        kind: "message",
        messages: [{role: "user", content: [{
          type: "tool_result",
          tool_use_id: "x",
          content: [{type: "text", text: "x".repeat(400000)}],
        }]}],
      });
      expect(res.statusCode).toBe(400);
      expect(anthropicCalls()).toHaveLength(0);
    });

    test("iletilen gövde yalnız temiz alanlardan kurulur", async () => {
      const idToken = await getIdTokenForUid("c1-strip");
      const res = await callProxy(idToken, {
        tier: "quick",
        kind: "message",
        tools: [{name: "exfil", input_schema: {type: "object"}}],
        metadata: {user_id: "someone-else"},
        messages: [{role: "user", content: [{type: "text", text: "hi", cache_control: {type: "ephemeral"}}]}],
      });
      expect(res.statusCode).toBe(200);
      const forwarded = JSON.parse(anthropicCalls()[0][1].body);
      for (const key of Object.keys(forwarded)) {
        expect(["model", "max_tokens", "system", "messages", "stream"]).toContain(key);
      }
      expect(forwarded.tools).toBeUndefined();
      expect(forwarded.metadata).toBeUndefined();
      expect(forwarded.messages).toEqual([{role: "user", content: [{type: "text", text: "hi"}]}]);
    });

    test("kind göndermeyen çağrı günlük system tavanında durur", async () => {
      const uid = "c1-system-cap";
      const today = new Date().toISOString().slice(0, 10);
      await db.collection("ai_usage").doc(`${uid}_${today}`).set({uid, day: today, counts: {system: 80}});
      const idToken = await getIdTokenForUid(uid);
      const res = await callProxy(idToken, {tier: "quick", messages: [{role: "user", content: "hi"}]});
      expect(res.statusCode).toBe(429);
      expect(res.body.reason).toBe("daily-system-limit");
      expect(anthropicCalls()).toHaveLength(0);
    });

    test("system çağrısı günlük sayaca yazılır", async () => {
      const uid = "c1-system-count";
      const idToken = await getIdTokenForUid(uid);
      await callProxy(idToken, {tier: "quick", messages: [{role: "user", content: "hi"}]});
      const today = new Date().toISOString().slice(0, 10);
      const doc = await db.collection("ai_usage").doc(`${uid}_${today}`).get();
      expect(doc.data().counts.system).toBe(1);
    });

    test("günlük dolar tavanı tüm türleri keser", async () => {
      const uid = "c1-usd";
      const today = new Date().toISOString().slice(0, 10);
      await db.collection("ai_token_usage").doc(`${uid}_${today}`).set({uid, day: today, estimatedUsd: 5.01});
      const idToken = await getIdTokenForUid(uid);
      const res = await callProxy(idToken, {tier: "quick", kind: "message", messages: [{role: "user", content: "hi"}]});
      expect(res.statusCode).toBe(429);
      expect(res.body.reason).toBe("daily-cost-limit");
      expect(anthropicCalls()).toHaveLength(0);
    });

    test("config/ai.dailyUsdLimit tavanı düşürebilir", async () => {
      const uid = "c1-usd-config";
      const today = new Date().toISOString().slice(0, 10);
      await db.collection("config").doc("ai").set({dailyUsdLimit: 1});
      await db.collection("ai_token_usage").doc(`${uid}_${today}`).set({uid, day: today, estimatedUsd: 1.2});
      const idToken = await getIdTokenForUid(uid);
      const res = await callProxy(idToken, {tier: "quick", kind: "message", messages: [{role: "user", content: "hi"}]});
      expect(res.body.reason).toBe("daily-cost-limit");
    });

    test("acil durum anahtarı kapalıyken 503 döner ve sayaç artmaz", async () => {
      await db.collection("config").doc("ai").set({enabled: false});
      const uid = "c1-breaker";
      const idToken = await getIdTokenForUid(uid);
      const res = await callProxy(idToken, {tier: "quick", kind: "message", messages: [{role: "user", content: "hi"}]});
      expect(res.statusCode).toBe(503);
      expect(res.body.reason).toBe("ai-disabled");
      expect(anthropicCalls()).toHaveLength(0);
      const snap = await db.collection("ai_usage").where("uid", "==", uid).get();
      expect(snap.empty).toBe(true);
    });

    test("yardımcı çağrıda görsel reddedilir (vision faturası)", async () => {
      const idToken = await getIdTokenForUid("c1-img-system");
      const res = await callProxy(idToken, {
        tier: "deep",
        messages: [{role: "user", content: [{type: "image", source: {type: "base64", media_type: "image/jpeg", data: "AAAA"}}]}],
      });
      expect(res.statusCode).toBe(400);
    });
  });

  test("enforces the per-tier daily usage cap server-side", async () => {
    const idToken = await getIdTokenForUid("ai-user-4");
    const body = {tier: "deep", messages: [{role: "user", content: "hi"}]};

    // "deep" tier's documented daily limit is 60 — exhaust it, then confirm
    // the 61st call is rejected with 429 regardless of client-side state.
    for (let i = 0; i < 60; i++) {
      const res = await callProxy(idToken, body);
      expect(res.statusCode).toBe(200);
    }

    const capped = await callProxy(idToken, body);
    expect(capped.statusCode).toBe(429);
  }, 30000);

  // ── Hesap bazlı haftalık ücretsiz kota ───────────────────────────────────
  // Kota eskiden istemcide (SharedPreferences) tutuluyordu: kullanıcı web'e
  // geçince, uygulamayı silip kurunca veya depolamayı temizleyince sıfırdan
  // başlıyordu. Bu testler sayacın hesaba (uid) bağlı olduğunu kilitler —
  // istemciden gelen HİÇBİR durum sayaca dokunmaz.
  describe("haftalık ücretsiz kota", () => {
    const weekKey = () => `W${Math.floor((Math.floor(Date.now() / 86400000) + 3) / 7)}`;

    test("sohbet mesajını haftalık kotadan düşer ve 20'de duvara çarpar", async () => {
      const uid = "week-user-1";
      const idToken = await getIdTokenForUid(uid);
      const body = {tier: "quick", kind: "message", messages: [{role: "user", content: "hi"}]};

      for (let i = 0; i < 20; i++) {
        const res = await callProxy(idToken, body);
        expect(res.statusCode).toBe(200);
      }

      const capped = await callProxy(idToken, body);
      expect(capped.statusCode).toBe(429);
      expect(capped.body.reason).toBe("free-weekly-limit");
      expect(capped.body.limit).toBe(20);
    }, 30000);

    test("sayaç cihaza değil hesaba yazılır", async () => {
      const uid = "week-user-2";
      const idToken = await getIdTokenForUid(uid);
      await callProxy(idToken, {
        tier: "quick",
        kind: "message",
        messages: [{role: "user", content: "hi"}],
      });

      const doc = await db.collection("ai_usage").doc(`${uid}_${weekKey()}`).get();
      expect(doc.exists).toBe(true);
      expect(doc.data().counts).toEqual({message: 1});
      expect(doc.data().uid).toBe(uid);
    });

    test("başka bir cihazdan gelen taze istek de aynı sayaca takılır", async () => {
      const uid = "week-user-3";
      // Kotanın dolduğu durumu doğrudan sayaç dokümanına yaz: yeni cihazın
      // yerel durumu boş olsa bile sunucu aynı hesabı sınırda görmeli.
      await db.collection("ai_usage").doc(`${uid}_${weekKey()}`).set({
        uid,
        period: weekKey(),
        counts: {food: 5},
      });

      const freshDeviceToken = await getIdTokenForUid(uid);
      const res = await callProxy(freshDeviceToken, {
        tier: "deep",
        kind: "food",
        messages: [{role: "user", content: "photo"}],
      });

      expect(res.statusCode).toBe(429);
      expect(res.body.reason).toBe("free-weekly-limit");
    });

    test("yardımcı (system) çağrılar kotadan düşmez", async () => {
      const uid = "week-user-4";
      const idToken = await getIdTokenForUid(uid);
      // kind yok = karşılama/hafıza/öneri gibi kullanıcının saymadığı çağrı.
      await callProxy(idToken, {tier: "quick", messages: [{role: "user", content: "hi"}]});

      const doc = await db.collection("ai_usage").doc(`${uid}_${weekKey()}`).get();
      expect(doc.exists).toBe(false);
    });

    test("tanınmayan kind'i reddeder", async () => {
      const idToken = await getIdTokenForUid("week-user-5");
      const res = await callProxy(idToken, {
        tier: "quick",
        kind: "unlimited",
        messages: [{role: "user", content: "hi"}],
      });
      expect(res.statusCode).toBe(400);
    });

    test("türler birbirinin kotasını yemez", async () => {
      const uid = "week-user-6";
      const idToken = await getIdTokenForUid(uid);
      await db.collection("ai_usage").doc(`${uid}_${weekKey()}`).set({
        uid,
        period: weekKey(),
        counts: {food: 5},
      });

      // Yemek hakkı bitti ama sohbet hakkı duruyor.
      const res = await callProxy(idToken, {
        tier: "quick",
        kind: "message",
        messages: [{role: "user", content: "hi"}],
      });
      expect(res.statusCode).toBe(200);
    });

    test("premium hesap haftalık kotadan muaf", async () => {
      const uid = "week-premium-1";
      const idToken = await getIdTokenForUid(uid);
      await db.collection("ai_usage").doc(`${uid}_${weekKey()}`).set({
        uid,
        period: weekKey(),
        counts: {message: 20},
      });
      // Sunucunun kendi yazdığı ödül premium'u (redeemReferralCode deseni).
      await db.collection("user_growth").doc(uid).set({
        referral_code: "PREMIUM1",
        founding_member: true,
        premium_access_until: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        ),
        referred_by_code: null,
      });

      const res = await callProxy(idToken, {
        tier: "quick",
        kind: "message",
        messages: [{role: "user", content: "hi"}],
      });
      expect(res.statusCode).toBe(200);

      // Muafiyet sayacı da şişirmemeli — premium'un kullanımı kotaya yazılmaz.
      const doc = await db.collection("ai_usage").doc(`${uid}_${weekKey()}`).get();
      expect(doc.data().counts.message).toBe(20);

      await db.collection("user_growth").doc(uid).delete();
    });

    test("süresi geçmiş ödül premium'u muafiyet vermez", async () => {
      const uid = "week-premium-2";
      const idToken = await getIdTokenForUid(uid);
      await db.collection("ai_usage").doc(`${uid}_${weekKey()}`).set({
        uid,
        period: weekKey(),
        counts: {message: 20},
      });
      await db.collection("user_growth").doc(uid).set({
        referral_code: "EXPIRED1",
        founding_member: true,
        premium_access_until: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() - 24 * 60 * 60 * 1000),
        ),
        referred_by_code: null,
      });

      const res = await callProxy(idToken, {
        tier: "quick",
        kind: "message",
        messages: [{role: "user", content: "hi"}],
      });
      expect(res.statusCode).toBe(429);

      await db.collection("user_growth").doc(uid).delete();
    });

    test("istemcinin 'premium' beyanı sayacı deldiremez", async () => {
      const uid = "week-user-7";
      const idToken = await getIdTokenForUid(uid);
      await db.collection("ai_usage").doc(`${uid}_${weekKey()}`).set({
        uid,
        period: weekKey(),
        counts: {message: 20},
      });

      const res = await callProxy(idToken, {
        tier: "quick",
        kind: "message",
        premium: true,
        isPremium: true,
        messages: [{role: "user", content: "hi"}],
      });
      expect(res.statusCode).toBe(429);
    });
  });

  test("tracks quick/deep usage independently per user", async () => {
    const idToken = await getIdTokenForUid("ai-user-5");
    await callProxy(idToken, {tier: "quick", messages: [{role: "user", content: "hi"}]});

    const today = new Date().toISOString().slice(0, 10);
    const usageDoc = await db.collection("ai_usage").doc(`ai-user-5_${today}`).get();
    // kind'sız çağrı artık "system" günlük sayacına da yazılır (denetim C-1).
    expect(usageDoc.data().counts).toEqual({quick: 1, system: 1});
  });
});
