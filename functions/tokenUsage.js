/**
 * Token muhasebesi.
 *
 * Neden ayri bir dosya: burasi saf hesap, Firebase'e hic dokunmaz. Boylece
 * jest ile emulator olmadan test edilebiliyor ve proxy'nin sicak yolunda
 * yalnizca birkac string islemi kaliyor.
 *
 * Ne ise yariyor: haftalik/gunluk CAGRI sayaci (ai_usage) bir cagrinin ne
 * kadar tuttugunu bilmiyor. 20 kelimelik bir mesajla 20 bin karakterlik bir
 * yapistirma ayni "1 mesaj" sayiliyor, oysa fatura arasindaki fark 50 kat.
 * Bu modul gercek girdi/cikti token'ini toplar; sinir koymadan once neyin
 * ne kadar tuttugunu OLCEBILELIM diye (owner karari 2026-09-01: once gercek
 * rakam, sonra tavan).
 */

/**
 * Milyon token basina dolar. YALNIZ raporlama icindir, faturalama degil:
 * model degisirse burasi da degismeli, yoksa rapor sessizce yanlislasir.
 * TIER_CONFIG'deki iki katman da ayni Sonnet ailesini kullaniyor.
 */
const TOKEN_PRICES_USD = {
  input: 3.0,
  output: 15.0,
  cacheWrite: 3.75,
  cacheRead: 0.30,
};

/**
 * Bos bir kullanim kaydi.
 * @return {{inputTokens: number, outputTokens: number,
 *   cacheWriteTokens: number, cacheReadTokens: number}} sifirlanmis kayit
 */
function emptyUsage() {
  return {
    inputTokens: 0,
    outputTokens: 0,
    cacheWriteTokens: 0,
    cacheReadTokens: 0,
  };
}

/**
 * Anthropic'in `usage` nesnesini bizim alan adlarimiza cevirir.
 * @param {object} usage upstream usage nesnesi
 * @param {object} into uzerine yazilacak kayit
 */
function mergeUsage(usage, into) {
  if (!usage || typeof usage !== "object") return;
  if (typeof usage.input_tokens === "number") {
    into.inputTokens = usage.input_tokens;
  }
  // Akista output_tokens KUMULATIFTIR: her message_delta o ana kadarki
  // toplami tasir. Toplarsak katlanarak sisen bir sayi elde ederiz.
  if (typeof usage.output_tokens === "number") {
    into.outputTokens = Math.max(into.outputTokens, usage.output_tokens);
  }
  if (typeof usage.cache_creation_input_tokens === "number") {
    into.cacheWriteTokens = usage.cache_creation_input_tokens;
  }
  if (typeof usage.cache_read_input_tokens === "number") {
    into.cacheReadTokens = usage.cache_read_input_tokens;
  }
}

/**
 * SSE akisini gecerken token kullanimini toplar.
 *
 * Akis parcalari satir ortasinda bolunebilir; yarim satir tamponda bekler.
 * Toplayici akisi DEGISTIRMEZ, yalnizca okur: proxy baytlari aynen
 * istemciye yazmaya devam eder.
 * @return {{feedSse: function(string): void,
 *   feedJson: function(object): void, result: function(): object}} toplayici
 */
function createUsageCollector() {
  const usage = emptyUsage();
  let pending = "";

  return {
    feedSse(chunk) {
      pending += chunk;
      const lines = pending.split("\n");
      pending = lines.pop() || "";
      for (const line of lines) {
        if (!line.startsWith("data:")) continue;
        const payload = line.slice(5).trim();
        if (!payload || payload === "[DONE]") continue;
        let event;
        try {
          event = JSON.parse(payload);
        } catch (err) {
          continue; // bozuk satir muhasebeyi durdurmaz
        }
        if (!event || typeof event !== "object") continue;
        if (event.type === "message_start" && event.message) {
          mergeUsage(event.message.usage, usage);
        } else if (event.usage) {
          mergeUsage(event.usage, usage);
        }
      }
    },

    feedJson(data) {
      if (data && typeof data === "object") mergeUsage(data.usage, usage);
    },

    result() {
      return {...usage};
    },
  };
}

/**
 * Bir cagrinin tahmini dolar maliyeti.
 * @param {object} usage token kayit
 * @return {number} dolar (yuvarlanmamis)
 */
function estimateUsd(usage) {
  const u = {...emptyUsage(), ...(usage || {})};
  return (
    (u.inputTokens * TOKEN_PRICES_USD.input +
      u.outputTokens * TOKEN_PRICES_USD.output +
      u.cacheWriteTokens * TOKEN_PRICES_USD.cacheWrite +
      u.cacheReadTokens * TOKEN_PRICES_USD.cacheRead) /
    1000000
  );
}

/**
 * Bir cagrinin gunluk dokumana eklenecek artislari.
 *
 * Ic ice duz sayilar doner; Firestore'a yazan taraf bunlari
 * FieldValue.increment'e cevirir. Boylece bu dosya Firebase'siz kalir ve
 * ayni yapi testte dogrudan okunabilir.
 * @param {{tier: string, kind: string, usage: object}} call cagri bilgisi
 * @return {object} artislar
 */
function buildUsageIncrements({tier, kind, usage}) {
  const u = {...emptyUsage(), ...(usage || {})};
  const usd = estimateUsd(u);
  const perCall = {
    calls: 1,
    inputTokens: u.inputTokens,
    outputTokens: u.outputTokens,
    cacheWriteTokens: u.cacheWriteTokens,
    cacheReadTokens: u.cacheReadTokens,
    estimatedUsd: usd,
  };
  return {
    ...perCall,
    byTier: {[tier]: {...perCall}},
    byKind: {[kind]: {...perCall}},
  };
}

module.exports = {
  TOKEN_PRICES_USD,
  createUsageCollector,
  estimateUsd,
  buildUsageIncrements,
};
