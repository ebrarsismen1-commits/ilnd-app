const admin = require("firebase-admin");
const httpMocks = require("node-mocks-http");
const {getIdTokenForUid, getAppCheckHeaderForTests} = require("./helpers");

const myFunctions = require("../index");

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
    const snap = await db.collection("ai_usage").get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
    global.fetch.mockClear();
  });

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

  test("tracks quick/deep usage independently per user", async () => {
    const idToken = await getIdTokenForUid("ai-user-5");
    await callProxy(idToken, {tier: "quick", messages: [{role: "user", content: "hi"}]});

    const today = new Date().toISOString().slice(0, 10);
    const usageDoc = await db.collection("ai_usage").doc(`ai-user-5_${today}`).get();
    expect(usageDoc.data().counts).toEqual({quick: 1});
  });
});
