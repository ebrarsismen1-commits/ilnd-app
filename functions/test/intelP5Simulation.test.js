const {
  CRITERIA,
  SCENARIOS,
  MOOD_MARGINALS,
  probit,
  generateUserNights,
  runScenario,
  evaluateGate,
} = require("../scripts/lib/p5Simulation");

/**
 * P5 simülasyon paketinin duman testi (ADR-0009). Kapının kendisi DEĞİLDİR:
 * tam kapı `npm run sim:p5` ile elle koşulur. Burası üreticinin ve
 * değerlendiricinin bozulmadığını, ölçütlerin ADR'dan kaymadığını kilitler.
 */

jest.setTimeout(180000);

const byId = (id) => SCENARIOS.find((s) => s.id === id);

describe("önceden kayıtlı yapı", () => {
  test("ölçütler ve senaryolar ADR ile aynı", () => {
    expect(CRITERIA).toEqual({
      G1: {maxRate: 0.05, maxWilsonUpper: 0.065},
      G2: {maxRate: 0.08},
      S1: {minRate: 0.60},
      S3: {minRate: 0.50},
    });
    expect(SCENARIOS.map((s) => s.id)).toEqual([
      "N-tipik-r0", "N-tipik-r0.3", "N-tipik-r0.6",
      "N-nadiren-r0", "N-nadiren-r0.3", "N-nadiren-r0.6",
      "N-sik-r0", "N-sik-r0.3", "N-sik-r0.6",
      "N-tipik-r0-weekend",
      "P-tipik-r0-b1.0", "P-tipik-r0-b0.5", "W-tipik-r0-b1.0-s30",
    ]);
  });

  test("probit bilinen değerler", () => {
    expect(probit(0.5)).toBeCloseTo(0, 9);
    expect(probit(0.975)).toBeCloseTo(1.959964, 5);
    expect(probit(0.01)).toBeCloseTo(-2.326348, 5);
  });
});

describe("üretici", () => {
  test("ruh hali marjinali hedefe yakın, tamamlanma ~%75", () => {
    const scenario = byId("N-tipik-r0");
    let low = 0;
    let total = 0;
    for (let i = 0; i < 300; i++) {
      for (const n of generateUserNights(scenario, i)) {
        total += 1;
        if (n.mood <= 2) low += 1;
      }
    }
    const expectedLow = MOOD_MARGINALS.tipik[0] + MOOD_MARGINALS.tipik[1];
    expect(low / total).toBeGreaterThan(expectedLow - 0.02);
    expect(low / total).toBeLessThan(expectedLow + 0.02);
    expect(total / (300 * 90)).toBeGreaterThan(0.73);
    expect(total / (300 * 90)).toBeLessThan(0.77);
  });

  test("aynı kullanıcı aynı geceler", () => {
    const scenario = byId("N-sik-r0.6");
    expect(generateUserNights(scenario, 7)).toEqual(generateUserNights(scenario, 7));
  });
});

describe("duman", () => {
  test("boş veride strong nadir, etkili veride görülür (gevşek sınırlar)", () => {
    const size = {users: 200, permutations: 500};
    const nullResult = runScenario(byId("N-tipik-r0"), size);
    const powerResult = runScenario(byId("P-tipik-r0-b1.0"), size);
    expect(nullResult.everStrong90.rate).toBeLessThanOrEqual(0.12);
    expect(powerResult.everStrong60.rate).toBeGreaterThanOrEqual(0.35);
  });

  test("aynı yapılandırma iki kez aynı özet hash'i", () => {
    const size = {users: 30, permutations: 500};
    expect(runScenario(byId("P-tipik-r0-b0.5"), size).summaryHash)
        .toBe(runScenario(byId("P-tipik-r0-b0.5"), size).summaryHash);
  });
});

describe("evaluateGate", () => {
  const fake = (id, kind, fields = {}) => ({
    id, kind,
    everStrong90: {rate: 0.02, wilsonUpper: 0.03},
    everStrong60: {rate: 0.7},
    weakenedAfterStrong: {rate: 0.8, total: 100},
    ...fields,
  });
  const all = (overrides = {}) => SCENARIOS.map((s) => fake(s.id, s.kind, overrides[s.id]));
  const ok = {pass: true, detail: ""};

  test("hepsi geçerse PASS", () => {
    expect(evaluateGate(all(), ok).gate).toBe("PASS");
  });

  test("boş veri ölçütü kalırsa FAIL", () => {
    const r = all({"N-tipik-r0.3": {everStrong90: {rate: 0.051, wilsonUpper: 0.06}}});
    expect(evaluateGate(r, ok).gate).toBe("FAIL");
  });

  test("Wilson üst sınırı aşarsa FAIL", () => {
    const r = all({"N-sik-r0": {everStrong90: {rate: 0.05, wilsonUpper: 0.07}}});
    expect(evaluateGate(r, ok).gate).toBe("FAIL");
  });

  test("belirlilik kalırsa FAIL", () => {
    expect(evaluateGate(all(), {pass: false, detail: ""}).gate).toBe("FAIL");
  });

  test("yüksek otokorelasyon ya da güç kalırsa NEEDS OWNER DECISION", () => {
    const g2 = all({"N-nadiren-r0.6": {everStrong90: {rate: 0.09, wilsonUpper: 0.1}}});
    expect(evaluateGate(g2, ok).gate).toBe("NEEDS OWNER DECISION");
    const s1 = all({"P-tipik-r0-b1.0": {everStrong60: {rate: 0.59}}});
    expect(evaluateGate(s1, ok).gate).toBe("NEEDS OWNER DECISION");
    const s3 = all({"W-tipik-r0-b1.0-s30": {weakenedAfterStrong: {rate: 0.4, total: 50}}});
    expect(evaluateGate(s3, ok).gate).toBe("NEEDS OWNER DECISION");
  });
});
