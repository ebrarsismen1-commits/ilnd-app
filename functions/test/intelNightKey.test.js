const fs = require("fs");
const path = require("path");
const {
  isNightKey,
  addDays,
  eveningNightKey,
  morningNightKey,
} = require("../intel/nightKey");

/**
 * Gece anahtarı kuralları (ADR-0009 §2). Vektörler ortak dosyada: Flutter
 * tarafı aynı dosyayla test edilecek, iki uygulama birbirinden kaymasın.
 */
const vectors = JSON.parse(fs.readFileSync(
    path.join(__dirname, "fixtures", "night_key_vectors.json"), "utf8"));

const createdAtMs = (local, tzOffsetMin) => Date.parse(`${local}Z`) - tzOffsetMin * 60000;

describe("eveningNightKey", () => {
  test.each(vectors.evening)("$id $local ($tzOffsetMin) → $expected", (v) => {
    expect(eveningNightKey(createdAtMs(v.local, v.tzOffsetMin), v.tzOffsetMin)).toBe(v.expected);
  });

  test("sayı olmayan zaman ya da offset null döner", () => {
    expect(eveningNightKey("2026-09-14", 180)).toBeNull();
    expect(eveningNightKey(Number.NaN, 180)).toBeNull();
    expect(eveningNightKey(Date.UTC(2026, 8, 14, 19), 90.5)).toBeNull();
  });
});

describe("morningNightKey", () => {
  test.each(vectors.morning)("$id $local ($tzOffsetMin) → $expected", (v) => {
    expect(morningNightKey(createdAtMs(v.local, v.tzOffsetMin), v.tzOffsetMin)).toBe(v.expected);
  });
});

describe("isNightKey", () => {
  test.each(vectors.nightKeys)("$value → $valid", (v) => {
    expect(isNightKey(v.value)).toBe(v.valid);
  });
});

describe("addDays", () => {
  test("ay, yıl ve artık gün sınırlarını geçer", () => {
    expect(addDays("2026-01-01", -1)).toBe("2025-12-31");
    expect(addDays("2028-02-28", 1)).toBe("2028-02-29");
    expect(addDays("2026-09-14", -59)).toBe("2026-07-17");
  });
});
