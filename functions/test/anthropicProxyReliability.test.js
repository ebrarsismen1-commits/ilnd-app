/**
 * Emülatörde çalışır. Denetim M-1 / M-2 (2026-09-13):
 *   - sağlayıcı hatasında kota hakkı iade edilir, istemci hatasında edilmez,
 *   - akış başladıktan sonraki hata SSE hata olayı olarak iletilir (eskiden
 *     ERR_HTTP_HEADERS_SENT fırlıyor, yarım cevap tamam sanılıyordu),
 *   - Anthropic çağrısı iptal edilebilir sinyal taşır (kullanıcı ayrılınca /
 *     zaman aşımında durur),
 *   - kullanıcı başına eşzamanlı çağrı sınırı ve kiralamanın bırakılması.
 */
const admin = require("firebase-admin");
const httpMocks = require("node-mocks-http");
const {EventEmitter} = require("events");
const {getIdTokenForUid} = require("./helpers");

const fns = require("../index");

const db = admin.firestore();
const weekKey = () => `W${Math.floor((Math.floor(Date.now() / 86400000) + 3) / 7)}`;
const today = () => new Date().toISOString().slice(0, 10);

jest.setTimeout(30000);

let realFetch;
let upstreamImpl;

beforeAll(() => {
  realFetch = global.fetch;
  global.fetch = jest.fn((url, options) => {
    if (String(url).includes("api.anthropic.com")) return upstreamImpl(options);
    return realFetch(url, options);
  });
});
afterAll(() => {
  global.fetch = realFetch;
});
afterEach(async () => {
  for (const col of ["ai_usage", "ai_leases", "ai_token_usage"]) {
    const snap = await db.collection(col).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
  global.fetch.mockClear();
});

async function callProxy(idToken, body) {
  const req = httpMocks.createRequest({
    method: "POST",
    headers: {authorization: `Bearer ${idToken}`},
    body,
  });
  const res = httpMocks.createResponse({eventEmitter: EventEmitter});
  await fns.anthropicProxy(req, res);
  return {
    statusCode: res.statusCode,
    // Proxy akış parçalarını Buffer olarak yazar; node-mocks-http Buffer
    // yazımlarını _getData()'ya değil _getChunks()'a koyar.
    raw: res._getChunks().map((c) => Buffer.from(c).toString("utf8")).join("") +
      res._getData(),
    json: () => res._getJSONData(),
  };
}

const counts = async (docId) => {
  const snap = await db.collection("ai_usage").doc(docId).get();
  return snap.exists ? snap.data().counts : null;
};

const message = {tier: "quick", kind: "message", messages: [{role: "user", content: "hi"}]};

/** SSE parçalarını verip sonra (isteğe bağlı) hata fırlatan sahte gövde. */
function sseBody(chunks, {failAfter = false} = {}) {
  let i = 0;
  return {
    getReader: () => ({
      read: async () => {
        if (i < chunks.length) return {done: false, value: new TextEncoder().encode(chunks[i++])};
        if (failAfter) throw Object.assign(new Error("socket hang up"), {name: "TypeError"});
        return {done: true, value: undefined};
      },
    }),
  };
}

describe("M-1: sağlayıcı hatası ve akış", () => {
  test("Anthropic 529 (aşırı yük) haftalık ve günlük hakkı yemez", async () => {
    const uid = "rel-529";
    upstreamImpl = async () => ({status: 529, json: async () => ({type: "error", error: {type: "overloaded_error"}})});

    const res = await callProxy(await getIdTokenForUid(uid), message);

    expect(res.statusCode).toBe(529);
    expect(await counts(`${uid}_${weekKey()}`)).toEqual({message: 0});
    expect((await counts(`${uid}_${today()}`)).quick).toBe(0);
  });

  test("ağ hatası 502 döner ve hakkı iade eder", async () => {
    const uid = "rel-network";
    upstreamImpl = async () => {
      throw Object.assign(new Error("ECONNRESET"), {name: "TypeError"});
    };

    const res = await callProxy(await getIdTokenForUid(uid), message);

    expect(res.statusCode).toBe(502);
    expect(await counts(`${uid}_${weekKey()}`)).toEqual({message: 0});
  });

  test("HTML hata sayfası bile JSON olarak iletilir (upstream.json fırlatsa da)", async () => {
    const uid = "rel-html";
    upstreamImpl = async () => ({status: 502, json: async () => {
      throw new SyntaxError("Unexpected token <");
    }});

    const res = await callProxy(await getIdTokenForUid(uid), message);

    expect(res.statusCode).toBe(502);
    expect(res.json().error.type).toBe("upstream_error");
  });

  test("400 (istemci hatası) iade edilmez", async () => {
    const uid = "rel-400";
    upstreamImpl = async () => ({status: 400, json: async () => ({type: "error", error: {type: "invalid_request_error"}})});

    await callProxy(await getIdTokenForUid(uid), message);

    expect(await counts(`${uid}_${weekKey()}`)).toEqual({message: 1});
  });

  test("akış ortasında kopan bağlantı SSE hata olayıyla biter, 502 fırlatmaz", async () => {
    const uid = "rel-midstream";
    upstreamImpl = async () => ({
      status: 200,
      body: sseBody([
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"Yarım \"}}\n\n",
      ], {failAfter: true}),
    });

    const res = await callProxy(await getIdTokenForUid(uid), {...message, stream: true});

    expect(res.statusCode).toBe(200);
    expect(res.raw).toContain("Yarım");
    expect(res.raw).toContain("event: error");
    expect(res.raw).toContain("proxy_error");
    expect(res.raw).not.toContain("message_stop");
    expect(await counts(`${uid}_${weekKey()}`)).toEqual({message: 0});
  });

  test("tamamlanan akış hak düşer ve hata olayı içermez", async () => {
    const uid = "rel-stream-ok";
    upstreamImpl = async () => ({
      status: 200,
      body: sseBody([
        "data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"Tamam\"}}\n\n",
        "data: {\"type\":\"message_stop\"}\n\n",
      ]),
    });

    const res = await callProxy(await getIdTokenForUid(uid), {...message, stream: true});

    expect(res.raw).toContain("message_stop");
    expect(res.raw).not.toContain("event: error");
    expect(await counts(`${uid}_${weekKey()}`)).toEqual({message: 1});
  });

  test("Anthropic çağrısı iptal edilebilir bir sinyal taşır (zaman aşımı / kullanıcı ayrıldı)", async () => {
    upstreamImpl = async () => ({status: 200, json: async () => ({content: [{type: "text", text: "ok"}]})});

    await callProxy(await getIdTokenForUid("rel-signal"), message);

    const [, options] = global.fetch.mock.calls.find(([u]) => String(u).includes("api.anthropic.com"));
    expect(options.signal).toBeDefined();
    expect(typeof options.signal.aborted).toBe("boolean");
  });
});

describe("M-2: kullanıcı başına eşzamanlılık", () => {
  test("iki etkin kiralama varken üçüncü çağrı 429 alır ve kota yemez", async () => {
    const uid = "rel-concurrency";
    const future = Date.now() + 60000;
    await db.collection("ai_leases").doc(uid).set({uid, leases: [
      {id: "a", expiresAtMs: future},
      {id: "b", expiresAtMs: future},
    ]});
    upstreamImpl = async () => ({status: 200, json: async () => ({content: [{type: "text", text: "ok"}]})});

    const res = await callProxy(await getIdTokenForUid(uid), message);

    expect(res.statusCode).toBe(429);
    expect(res.json().reason).toBe("concurrency-limit");
    expect(await counts(`${uid}_${weekKey()}`)).toBeNull();
  });

  test("süresi dolmuş kiralamalar sayılmaz", async () => {
    const uid = "rel-expired";
    const past = Date.now() - 1000;
    await db.collection("ai_leases").doc(uid).set({uid, leases: [
      {id: "a", expiresAtMs: past},
      {id: "b", expiresAtMs: past},
    ]});
    upstreamImpl = async () => ({status: 200, json: async () => ({content: [{type: "text", text: "ok"}]})});

    const res = await callProxy(await getIdTokenForUid(uid), message);

    expect(res.statusCode).toBe(200);
  });

  test("çağrı bitince (başarılı ya da hatalı) kiralama bırakılır", async () => {
    const uid = "rel-release";
    const idToken = await getIdTokenForUid(uid);

    upstreamImpl = async () => ({status: 200, json: async () => ({content: [{type: "text", text: "ok"}]})});
    await callProxy(idToken, message);
    expect((await db.collection("ai_leases").doc(uid).get()).data().leases).toEqual([]);

    upstreamImpl = async () => {
      throw new Error("boom");
    };
    await callProxy(idToken, message);
    expect((await db.collection("ai_leases").doc(uid).get()).data().leases).toEqual([]);
  });
});

// Staging doğrulaması (2026-09-13): günlük dolar tavanı kiralamadan ÖNCE
// okunuyordu. Sırada bekleyen istekler harcamanın eski değerini (4,99 $)
// görüp birer birer geçti: 5 isteğin 5'i de Anthropic'e ulaştı. Harcama artık
// kiralama alındıktan SONRA okunuyor; önceki çağrı harcamasını kiralamayı
// bırakmadan önce yazdığı için aşım en fazla eşzamanlı çağrı kadar.
describe("günlük dolar tavanı kiralama sırası", () => {
  test("harcama kiralama alındıktan sonra okunur", async () => {
    const uid = "rel-spend-order";
    const idToken = await getIdTokenForUid(uid);
    upstreamImpl = async () => ({status: 200, json: async () => ({content: [{type: "text", text: "ok"}]})});

    const order = [];
    const spy = jest.spyOn(db, "collection").mockImplementation(function(name) {
      order.push(name);
      return Object.getPrototypeOf(db).collection.call(this, name);
    });
    try {
      await callProxy(idToken, message);
    } finally {
      spy.mockRestore();
    }

    const lease = order.indexOf("ai_leases");
    const spend = order.indexOf("ai_token_usage");
    expect(lease).toBeGreaterThan(-1);
    expect(spend).toBeGreaterThan(-1);
    expect(spend).toBeGreaterThan(lease);
  });

  test("önceki çağrı harcamayı tavana taşıdıysa sonraki çağrı reddedilir ve kiralama bırakılır", async () => {
    const uid = "rel-spend-release";
    const idToken = await getIdTokenForUid(uid);
    await db.collection("ai_token_usage").doc(`${uid}_${today()}`).set({uid, day: today(), estimatedUsd: 4.99});
    // İlk çağrı ~0,03 $ harcar (10.000 girdi token'ı) ve tavanı geçirir.
    upstreamImpl = async () => ({
      status: 200,
      json: async () => ({content: [{type: "text", text: "ok"}], usage: {input_tokens: 10000, output_tokens: 0}}),
    });

    expect((await callProxy(idToken, message)).statusCode).toBe(200);
    const second = await callProxy(idToken, message);

    expect(second.statusCode).toBe(429);
    expect(second.json().reason).toBe("daily-cost-limit");
    expect(global.fetch.mock.calls.filter(([u]) => String(u).includes("api.anthropic.com"))).toHaveLength(1);
    expect((await db.collection("ai_leases").doc(uid).get()).data().leases).toEqual([]);
  });
});
