/**
 * anthropicProxy'nin girdi kapısı.
 *
 * Neden ayrı dosya: saf doğrulama, Firebase'e dokunmaz. Emülatörsüz jest ile
 * test edilebiliyor (bkz. test/aiRequest.test.js).
 *
 * Güvenlik denetimi C-1 (2026-09-13): proxy istemcinin gönderdiği mesaj
 * bloklarını OLDUĞU GİBİ Anthropic'e iletiyordu. Metin sınırı yalnız üst
 * düzey `text` alanlarını saydığı için `document` bloğunun `source.data`'sı
 * ya da iç içe `tool_result.content` hiç sayılmıyordu; 8 MB gövdeye kadar
 * girdi faturası kesilebiliyordu. Artık mesajlar izin listesinden YENİDEN
 * KURULUR: tanınmayan her şey reddedilir, iletilen gövde yalnız bizim
 * ürettiğimiz alanlardan oluşur.
 */

const MAX_BODY_BYTES = 8 * 1024 * 1024; // fotoğraf (istemci 4MB'a kırpar) + pay
const MAX_MESSAGES = 30;

// Ölçülen türler (message, food) haftalık kotadan düşer; metin bütçesi geniş.
const MAX_TEXT_CHARS = 100000;
// "system" (karşılama, günlük yanıtı, hafıza çıkarımı, öneri) haftalık
// kotadan düşmez; bu yüzden bütçesi dar. Günlük adet tavanı index.js'te.
const MAX_SYSTEM_KIND_TEXT_CHARS = 30000;
// Kişilik + hafıza bağlamı bugün ~3-6 bin karakter; pay bırakıldı.
const MAX_SYSTEM_PROMPT_CHARS = 24000;
const MAX_IMAGES = 2;
const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp", "image/gif"];

const METERED_KINDS = ["message", "food"];
const KNOWN_KINDS = ["system", ...METERED_KINDS];

/**
 * Mesajları yalnız bilinen parçalardan yeniden kurar.
 * @param {unknown} messages istemciden gelen dizi
 * @return {{messages: Array<object>, textChars: number, images: number}|null}
 *   temiz kopya ya da (beklenmedik herhangi bir şeyde) null
 */
function sanitizeMessages(messages) {
  if (!Array.isArray(messages)) return null;
  let textChars = 0;
  let images = 0;
  const out = [];
  for (const m of messages) {
    if (!m || typeof m !== "object") return null;
    if (m.role !== "user" && m.role !== "assistant") return null;
    if (typeof m.content === "string") {
      textChars += m.content.length;
      out.push({role: m.role, content: m.content});
      continue;
    }
    if (!Array.isArray(m.content) || m.content.length === 0) return null;
    const blocks = [];
    for (const b of m.content) {
      if (!b || typeof b !== "object") return null;
      if (b.type === "text" && typeof b.text === "string") {
        textChars += b.text.length;
        blocks.push({type: "text", text: b.text});
      } else if (
        b.type === "image" &&
        m.role === "user" &&
        b.source && typeof b.source === "object" &&
        b.source.type === "base64" &&
        ALLOWED_IMAGE_TYPES.includes(b.source.media_type) &&
        typeof b.source.data === "string"
      ) {
        images++;
        blocks.push({
          type: "image",
          source: {
            type: "base64",
            media_type: b.source.media_type,
            data: b.source.data,
          },
        });
      } else {
        // document, tool_use, tool_result, url kaynaklı görsel, bilinmeyen
        // tür: hepsi burada durur.
        return null;
      }
    }
    out.push({role: m.role, content: blocks});
  }
  return {messages: out, textChars, images};
}

/**
 * İstek gövdesini doğrular ve iletilecek temiz alanları döner.
 * @param {unknown} body req.body
 * @param {{rawBytes?: number, tiers: string[]}} opts gövde boyutu ve
 *   geçerli kademe adları
 * @return {{ok: true, tier: string, kind: string, system: (string|undefined),
 *   messages: Array<object>, stream: boolean}|
 *   {ok: false, status: number, error: string}} karar
 */
function parseAiRequest(body, {rawBytes, tiers}) {
  const fail = (status, error) => ({ok: false, status, error});
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return fail(400, "Invalid request body");
  }

  const bytes = typeof rawBytes === "number" ?
    rawBytes :
    Buffer.byteLength(JSON.stringify(body));
  if (bytes > MAX_BODY_BYTES) return fail(413, "Payload too large");

  const {tier, system, messages} = body;
  if (typeof tier !== "string" || !tiers.includes(tier)) {
    return fail(400, "Invalid request body");
  }

  // kind yoksa "system" sayılır; bu artık bedava değil: dar metin bütçesi +
  // günlük adet tavanı (index.js) + günlük dolar tavanı.
  const kind = body.kind === undefined ? "system" : body.kind;
  if (typeof kind !== "string" || !KNOWN_KINDS.includes(kind)) {
    return fail(400, "Invalid usage kind");
  }

  if (system !== undefined && typeof system !== "string") {
    return fail(400, "Invalid system prompt");
  }
  const systemChars = typeof system === "string" ? system.length : 0;
  if (systemChars > MAX_SYSTEM_PROMPT_CHARS) {
    return fail(400, "System prompt too long");
  }

  if (!Array.isArray(messages) || messages.length === 0) {
    return fail(400, "Invalid request body");
  }
  if (messages.length > MAX_MESSAGES) return fail(400, "Too many messages");

  const clean = sanitizeMessages(messages);
  if (!clean) return fail(400, "Unsupported message content");

  const textLimit = kind === "system" ? MAX_SYSTEM_KIND_TEXT_CHARS : MAX_TEXT_CHARS;
  const counted = kind === "system" ? clean.textChars : clean.textChars + systemChars;
  if (counted > textLimit) return fail(400, "Input text too long");

  if (clean.images > MAX_IMAGES) return fail(400, "Too many images");
  // Görsel yalnız yemek analizinde anlamlı; yardımcı çağrılar vision
  // faturası kesemesin.
  if (clean.images > 0 && kind !== "food") {
    return fail(400, "Images are only accepted for food analysis");
  }

  return {
    ok: true,
    tier,
    kind,
    system,
    messages: clean.messages,
    stream: body.stream === true,
  };
}

module.exports = {
  MAX_BODY_BYTES,
  MAX_MESSAGES,
  MAX_TEXT_CHARS,
  MAX_SYSTEM_KIND_TEXT_CHARS,
  MAX_SYSTEM_PROMPT_CHARS,
  MAX_IMAGES,
  ALLOWED_IMAGE_TYPES,
  METERED_KINDS,
  KNOWN_KINDS,
  sanitizeMessages,
  parseAiRequest,
};
