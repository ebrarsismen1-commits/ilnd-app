#!/usr/bin/env node
/**
 * P5 istatistik kapısı (ADR-0009). Firebase'e, ağa ve LLM'e dokunmaz.
 *
 * Senaryolar worker thread'lerde paralel koşar; her senaryo tohumlu olduğu
 * için paralellik sonucu değiştirmez. Belirlilik (G3) için küçük bir tam set
 * iki kez koşulur ve özet hash'leri karşılaştırılır.
 *
 * Kullanım:
 *   npm run sim:p5                                   (tam kapı: 2000 kullanıcı, B=2000)
 *   node scripts/simulateP5.js --users=200 --permutations=500 --skip-determinism
 *   node scripts/simulateP5.js --out=../docs/adr/0009-p5-simulation-results.json
 */
const os = require("os");
const fs = require("fs");
const {Worker, isMainThread, parentPort, workerData} = require("worker_threads");
const {
  ENGINE_VERSION,
  SCENARIOS,
  runScenario,
  evaluateGate,
} = require("./lib/p5Simulation");

/**
 * @param {string} name bayrak
 * @param {string|null} fallback varsayılan
 * @return {string|null} değer
 */
function flag(name, fallback) {
  const hit = process.argv.slice(2).find((arg) => arg === `--${name}` || arg.startsWith(`--${name}=`));
  if (!hit) return fallback;
  return hit.includes("=") ? hit.slice(hit.indexOf("=") + 1) : "true";
}

/**
 * Senaryoları worker havuzunda çalıştırır.
 * @param {object[]} scenarios senaryolar
 * @param {{users: number, permutations: number}} size boyut
 * @param {number} poolSize eşzamanlı worker
 * @return {Promise<object[]>} SCENARIOS sırasıyla sonuçlar
 */
function runPool(scenarios, size, poolSize) {
  return new Promise((resolve, reject) => {
    const results = new Array(scenarios.length);
    let next = 0;
    let done = 0;
    const launch = () => {
      if (next >= scenarios.length) return;
      const index = next++;
      const started = Date.now();
      const worker = new Worker(__filename, {workerData: {scenarioId: scenarios[index].id, ...size}});
      worker.once("message", (result) => {
        results[index] = result;
        done += 1;
        console.error(`  ${result.id}: ${((Date.now() - started) / 1000).toFixed(1)} sn` +
          ` (${done}/${scenarios.length})`);
        if (done === scenarios.length) resolve(results);
        else launch();
      });
      worker.once("error", reject);
    };
    for (let i = 0; i < Math.min(poolSize, scenarios.length); i++) launch();
  });
}

/**
 * @param {number} value oran
 * @return {string} yüzde
 */
function pct(value) {
  return `${(value * 100).toFixed(2)}%`;
}

async function main() {
  const users = Number(flag("users", "2000"));
  const permutations = Number(flag("permutations", "2000"));
  const determinismUsers = Number(flag("determinism-users", "300"));
  const skipDeterminism = flag("skip-determinism", null) === "true";
  const out = flag("out", null);
  const poolSize = Number(flag("workers", String(Math.max(1, os.cpus().length - 1))));
  const started = Date.now();

  console.error(`P5 simülasyonu: ${users} kullanıcı, B=${permutations}, ${poolSize} worker`);
  const results = await runPool(SCENARIOS, {users, permutations}, poolSize);

  let determinism = {pass: false, detail: "koşulmadı (--skip-determinism)"};
  if (!skipDeterminism) {
    console.error(`Belirlilik: ${determinismUsers} kullanıcı, B=${permutations}, iki kez`);
    const first = await runPool(SCENARIOS, {users: determinismUsers, permutations}, poolSize);
    const second = await runPool(SCENARIOS, {users: determinismUsers, permutations}, poolSize);
    const a = first.map((r) => `${r.id}:${r.summaryHash}`);
    const b = second.map((r) => `${r.id}:${r.summaryHash}`);
    const same = a.every((value, i) => value === b[i]);
    determinism = {pass: same, detail: same ? `aynı: ${a.join(" ")}` : `farklı: ${a} / ${b}`};
  }

  const gate = evaluateGate(results, determinism);

  console.log("\nsenaryo                   ort.gece  strong90             strong60   emerging*  candidate*  not_obs  zayıflama");
  for (const r of results) {
    console.log([
      r.id.padEnd(24),
      r.meanPairs.toFixed(1).padStart(8),
      `${pct(r.everStrong90.rate)} [≤${pct(r.everStrong90.wilsonUpper)}]`.padStart(21),
      pct(r.everStrong60.rate).padStart(9),
      pct(r.everEmergingStatus.rate).padStart(10),
      pct(r.everCandidateStatus.rate).padStart(11),
      pct(r.everNotObservedShown.rate).padStart(8),
      r.weakenedAfterStrong.total ?
        `${pct(r.weakenedAfterStrong.rate)} (${r.weakenedAfterStrong.count}/${r.weakenedAfterStrong.total})` :
        "-",
    ].join("  "));
  }
  console.log("* iç durum, kullanıcıya gösterilmez\n");
  for (const c of gate.criteria) {
    const verdict = c.pass === null ? "RAPOR" : c.pass ? "GEÇTİ" : "KALDI";
    console.log(`${c.code} (${c.type}): ${verdict}${c.value !== undefined ? ` ${pct(c.value)}` : ""}`);
  }
  console.log(`\nSTATISTICAL GATE: ${gate.gate}`);
  console.error(`Toplam süre: ${((Date.now() - started) / 60000).toFixed(1)} dk`);

  if (out) {
    const report = {
      adr: "ADR-0009",
      engineVersion: ENGINE_VERSION,
      config: {users, permutations, determinismUsers, nights: 90},
      node: process.version,
      generatedAt: new Date().toISOString(),
      results,
      determinism,
      criteria: gate.criteria,
      gate: gate.gate,
    };
    fs.writeFileSync(out, `${JSON.stringify(report, null, 2)}\n`);
    console.error(`Rapor: ${out}`);
  }
}

if (isMainThread) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
} else {
  const scenario = SCENARIOS.find((s) => s.id === workerData.scenarioId);
  parentPort.postMessage(runScenario(scenario, {
    users: workerData.users,
    permutations: workerData.permutations,
  }));
}
