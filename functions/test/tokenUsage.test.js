const {
  createUsageCollector,
  estimateUsd,
  buildUsageIncrements,
} = require("../tokenUsage");

/**
 * Token muhasebesi olcum icin var: sinirlari buradan cikan gercek rakama
 * gore koyacagiz. Yanlis toplanan bir sayac, yanlis bir tavan demek.
 *
 * Iki tuzak burada kilitleniyor:
 *   1. akista output_tokens KUMULATIF gelir, toplanirsa sayi sisiyor,
 *   2. SSE parcalari satir ortasinda bolunuyor, tamponsuz okuma olayi
 *      tamamen kaciriyor.
 */
describe("createUsageCollector", () => {
  const messageStart = JSON.stringify({
    type: "message_start",
    message: {
      usage: {
        input_tokens: 1200,
        output_tokens: 1,
        cache_creation_input_tokens: 800,
        cache_read_input_tokens: 0,
      },
    },
  });

  test("akistaki kumulatif cikti toplanmaz, sonuncusu alinir", () => {
    const c = createUsageCollector();
    c.feedSse(`data: ${messageStart}\n\n`);
    c.feedSse("data: {\"type\":\"message_delta\",\"usage\":" +
      "{\"output_tokens\":40}}\n\n");
    c.feedSse("data: {\"type\":\"message_delta\",\"usage\":" +
      "{\"output_tokens\":95}}\n\n");

    expect(c.result()).toEqual({
      inputTokens: 1200,
      outputTokens: 95,
      cacheWriteTokens: 800,
      cacheReadTokens: 0,
    });
  });

  test("satir ortasindan bolunen parcalar birlestirilir", () => {
    const c = createUsageCollector();
    const line = `data: ${messageStart}\n\n`;
    c.feedSse(line.slice(0, 30));
    c.feedSse(line.slice(30));

    expect(c.result().inputTokens).toBe(1200);
  });

  test("bozuk satir muhasebeyi durdurmaz", () => {
    const c = createUsageCollector();
    c.feedSse("data: {bozuk\n\n");
    c.feedSse("event: ping\n\n");
    c.feedSse("data: [DONE]\n\n");
    c.feedSse(`data: ${messageStart}\n\n`);

    expect(c.result().inputTokens).toBe(1200);
  });

  test("akissiz yanit da okunur", () => {
    const c = createUsageCollector();
    c.feedJson({
      content: [{type: "text", text: "merhaba"}],
      usage: {input_tokens: 500, output_tokens: 120},
    });

    expect(c.result().inputTokens).toBe(500);
    expect(c.result().outputTokens).toBe(120);
  });

  test("hic olay gelmezse her sey sifir kalir", () => {
    const c = createUsageCollector();
    c.feedSse("");
    expect(c.result()).toEqual({
      inputTokens: 0,
      outputTokens: 0,
      cacheWriteTokens: 0,
      cacheReadTokens: 0,
    });
  });
});

describe("estimateUsd", () => {
  test("cikti girdiden 5 kat pahalidir", () => {
    const input = estimateUsd({inputTokens: 1000000});
    const output = estimateUsd({outputTokens: 1000000});
    expect(input).toBeCloseTo(3.0, 6);
    expect(output).toBeCloseTo(15.0, 6);
  });

  test("onbellek okumasi girdinin onda birinden ucuz", () => {
    expect(estimateUsd({cacheReadTokens: 1000000})).toBeCloseTo(0.3, 6);
  });

  test("tipik bir sohbet cagrisi sent mertebesinde", () => {
    const usd = estimateUsd({inputTokens: 1500, outputTokens: 200});
    expect(usd).toBeGreaterThan(0.005);
    expect(usd).toBeLessThan(0.01);
  });
});

describe("buildUsageIncrements", () => {
  test("cagriyi hem toplama hem tur ve katman kirilimina yazar", () => {
    const inc = buildUsageIncrements({
      tier: "quick",
      kind: "message",
      usage: {inputTokens: 1000, outputTokens: 100},
    });

    expect(inc.calls).toBe(1);
    expect(inc.inputTokens).toBe(1000);
    expect(inc.byTier.quick.outputTokens).toBe(100);
    expect(inc.byKind.message.calls).toBe(1);
    expect(inc.estimatedUsd).toBeCloseTo(
        inc.byKind.message.estimatedUsd,
        9,
    );
  });
});
