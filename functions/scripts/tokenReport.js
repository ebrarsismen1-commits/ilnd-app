#!/usr/bin/env node
/**
 * Gercek token harcamasini okur ve ozetler.
 *
 * Neden var: sinirlari tahminle degil veriyle koyacagiz (owner karari
 * 2026-09-01). Proxy her cagrinin gercek girdi/cikti token'ini
 * `ai_token_usage/{uid}_{gun}` dokumanina yaziyor; bu script o dokumanlari
 * toplayip "kim ne kadar harciyor" sorusuna cevap veriyor. Bir haftalik veri
 * biriktikten sonra buradaki en cok harcayan kullanicinin gunluk maliyeti,
 * gunluk tavanin ne olmasi gerektigini soyler.
 *
 * Kimlik: `gcloud auth application-default login` ya da
 * GOOGLE_APPLICATION_CREDENTIALS.
 *
 * Kullanim (hedef proje ZORUNLU, salt okunur oldugu icin prod onayi istemez):
 *   npm run report:tokens -- --project=<id>          (son 7 gun)
 *   node scripts/tokenReport.js 30 --project=<id>    (son 30 gun)
 */
const admin = require("firebase-admin");
const {resolveTarget, describeTarget} = require("./lib/target");

const target = resolveTarget({writes: false});
console.log(describeTarget(target));

const dayArg = process.argv.slice(2).find((a) => /^\d+$/.test(a));
const DAYS = Number(dayArg || 7);

if (!admin.apps.length) {
  admin.initializeApp({projectId: target.projectId});
}
const db = admin.firestore();

/**
 * @param {number} back kac gun once
 * @return {string} YYYY-MM-DD
 */
function dayKey(back) {
  const d = new Date(Date.now() - back * 86400000);
  return d.toISOString().slice(0, 10);
}

/**
 * @param {number} usd dolar
 * @return {string} okunur tutar
 */
function money(usd) {
  return `$${usd.toFixed(4)}`;
}

/**
 * @param {object} target uzerine toplanacak nesne
 * @param {object} source eklenecek kayit
 */
function accumulate(target, source) {
  for (const key of [
    "calls",
    "inputTokens",
    "outputTokens",
    "cacheWriteTokens",
    "cacheReadTokens",
    "estimatedUsd",
  ]) {
    target[key] = (target[key] || 0) + (source[key] || 0);
  }
}

/**
 * Raporu yazdirir.
 * @return {Promise<void>} bitis
 */
async function main() {
  const days = [];
  for (let i = 0; i < DAYS; i++) days.push(dayKey(i));

  const snap = await db
      .collection("ai_token_usage")
      .where("day", "in", days.slice(0, 30))
      .get();

  if (snap.empty) {
    console.log(`Son ${DAYS} gunde kayit yok.`);
    console.log(
        "Proxy henuz deploy edilmemis olabilir (npm run deploy) ya da hic " +
      "AI cagrisi yapilmamis.",
    );
    return;
  }

  const total = {};
  const byUser = new Map();
  const byKind = new Map();
  const byTier = new Map();

  snap.forEach((doc) => {
    const d = doc.data();
    accumulate(total, d);

    const user = byUser.get(d.uid) || {days: new Set()};
    accumulate(user, d);
    user.days.add(d.day);
    byUser.set(d.uid, user);

    for (const [kind, stats] of Object.entries(d.byKind || {})) {
      const bucket = byKind.get(kind) || {};
      accumulate(bucket, stats);
      byKind.set(kind, bucket);
    }
    for (const [tier, stats] of Object.entries(d.byTier || {})) {
      const bucket = byTier.get(tier) || {};
      accumulate(bucket, stats);
      byTier.set(tier, bucket);
    }
  });

  const perCall = total.calls ? total.estimatedUsd / total.calls : 0;
  console.log(`\n=== Son ${DAYS} gun ===`);
  console.log(`Kullanici       : ${byUser.size}`);
  console.log(`Cagri           : ${total.calls}`);
  console.log(`Girdi token     : ${total.inputTokens.toLocaleString()}`);
  console.log(`Cikti token     : ${total.outputTokens.toLocaleString()}`);
  console.log(
      `Onbellek (y/o)  : ${total.cacheWriteTokens.toLocaleString()} / ` +
    `${total.cacheReadTokens.toLocaleString()}`,
  );
  console.log(`Toplam maliyet  : ${money(total.estimatedUsd)}`);
  console.log(`Cagri basi      : ${money(perCall)}`);

  console.log("\n--- Tur bazinda ---");
  for (const [kind, stats] of [...byKind.entries()].sort(
      (a, b) => b[1].estimatedUsd - a[1].estimatedUsd,
  )) {
    const avg = stats.calls ? stats.estimatedUsd / stats.calls : 0;
    console.log(
        `${kind.padEnd(8)} ${String(stats.calls).padStart(6)} cagri  ` +
      `${money(stats.estimatedUsd).padStart(10)}  cagri basi ${money(avg)}`,
    );
  }

  console.log("\n--- Katman bazinda ---");
  for (const [tier, stats] of byTier.entries()) {
    console.log(
        `${tier.padEnd(8)} ${String(stats.calls).padStart(6)} cagri  ` +
      `${money(stats.estimatedUsd)}`,
    );
  }

  console.log("\n--- En cok harcayan 10 kullanici ---");
  const top = [...byUser.entries()]
      .sort((a, b) => b[1].estimatedUsd - a[1].estimatedUsd)
      .slice(0, 10);
  for (const [uid, stats] of top) {
    const activeDays = stats.days.size;
    const perDay = stats.estimatedUsd / activeDays;
    console.log(
        `${uid.slice(0, 12).padEnd(14)} ${String(stats.calls).padStart(5)} ` +
      `cagri  ${money(stats.estimatedUsd).padStart(10)}  ` +
      `${activeDays} aktif gun  gunluk ${money(perDay)}`,
    );
  }

  // Tavan tartismasinin baslayacagi sayi: en pahali kullanicinin aylik
  // izdusumu. Abonelik fiyatinin altinda mi?
  if (top.length) {
    const worst = top[0][1];
    const worstPerDay = worst.estimatedUsd / worst.days.size;
    console.log(
        `\nEn pahali kullanici bu hizla aylik ${money(worstPerDay * 30)} ` +
      "tutar.",
    );
  }
  console.log("");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
