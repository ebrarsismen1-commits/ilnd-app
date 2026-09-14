/**
 * Admin SDK scriptlerinin hedef projesini seçer ve prod'a kazara yazmayı
 * engeller.
 *
 * Güvenlik denetimi C-2 (2026-09-13): seed scriptleri `admin.initializeApp()`
 * ile ortamdaki kimlik neyse ona bağlanıyordu, belgelenen varsayılan kullanım
 * "against prod" idi ve `--prune` canlı içeriği onaysız siliyordu.
 *
 * Kurallar:
 *   - FIRESTORE_EMULATOR_HOST varsa emülatör: serbest.
 *   - Yoksa `--project=<id>` ZORUNLU; tahmin edilmez.
 *   - Prod projesine YAZAN script `--confirm-prod` ister.
 *   - Prod'da `--prune` önce kuru çalışır (silinecekleri listeler);
 *     gerçekten silmek için ayrıca `--confirm-prune` gerekir.
 */

const PROD_PROJECT_IDS = ["ilnd-app-8dcbd"];

/** Hedef güvenli değil; mesaj kullanıcıya ne yapacağını söyler. */
class TargetError extends Error {}

/**
 * `--name=value` ya da `--name value` biçimini okur.
 * @param {string[]} argv argümanlar
 * @param {string} name bayrak adı
 * @return {string|null} değer
 */
function readFlag(argv, name) {
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg.startsWith(`--${name}=`)) return arg.slice(name.length + 3) || null;
    if (arg === `--${name}` && argv[i + 1] && !argv[i + 1].startsWith("--")) {
      return argv[i + 1];
    }
  }
  return null;
}

/**
 * @param {{argv?: string[], env?: object, writes?: boolean}} [opts]
 *   writes=false yalnız okuyan scriptler içindir (prod onayı istemez)
 * @return {{projectId: string, emulator: boolean, isProd: boolean,
 *   prune: boolean, pruneDryRun: boolean}} hedef
 */
function resolveTarget({
  argv = process.argv.slice(2),
  env = process.env,
  writes = true,
} = {}) {
  const emulator = Boolean(env.FIRESTORE_EMULATOR_HOST);
  const projectId = readFlag(argv, "project") ||
    (emulator ?
      (env.GCLOUD_PROJECT || env.GOOGLE_CLOUD_PROJECT || "demo-ilnd-local") :
      null);

  if (!projectId) {
    throw new TargetError(
        "Refusing to run without an explicit target. Pass " +
        "--project=<firebase-project-id>, or set FIRESTORE_EMULATOR_HOST " +
        "to use the emulator.",
    );
  }

  const isProd = !emulator && PROD_PROJECT_IDS.includes(projectId);
  if (isProd && writes && !argv.includes("--confirm-prod")) {
    throw new TargetError(
        `"${projectId}" is the PRODUCTION project. Re-run with ` +
        "--confirm-prod if you really mean to write to it.",
    );
  }

  const prune = argv.includes("--prune");
  const pruneDryRun = prune && isProd && !argv.includes("--confirm-prune");
  return {projectId, emulator, isProd, prune, pruneDryRun};
}

/**
 * JSON kaynağında olmayan dokümanları siler (prod'da onaysızsa yalnız listeler).
 * @param {FirebaseFirestore.CollectionReference} col koleksiyon
 * @param {Set<string>} seenIds kaynakta bulunan kimlikler
 * @param {{prune: boolean, pruneDryRun: boolean}} target hedef
 * @param {string} label log etiketi
 * @return {Promise<string[]>} silinen (ya da kuru çalışmada silinecek) kimlikler
 */
async function pruneOrphans(col, seenIds, target, label) {
  if (!target.prune) return [];
  const existing = await col.get();
  const orphaned = existing.docs.filter((d) => !seenIds.has(d.id));
  const ids = orphaned.map((d) => d.id);
  if (ids.length === 0) return ids;

  if (target.pruneDryRun) {
    console.log(
        `[dry run] Would prune ${ids.length} ${label}: ${ids.join(", ")}\n` +
        "Nothing was deleted. Re-run with --confirm-prune to delete them.",
    );
    return ids;
  }
  // Batch başına 500 yazma sınırı.
  for (let i = 0; i < orphaned.length; i += 400) {
    const batch = col.firestore.batch();
    orphaned.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  console.log(`Pruned ${ids.length} orphaned ${label}.`);
  return ids;
}

/**
 * @param {{projectId: string, emulator: boolean, isProd: boolean}} target hedef
 * @return {string} okunur hedef satırı
 */
function describeTarget(target) {
  if (target.emulator) return `Target: emulator (${target.projectId})`;
  return `Target: ${target.projectId}${target.isProd ? " [PRODUCTION]" : ""}`;
}

module.exports = {
  PROD_PROJECT_IDS,
  TargetError,
  readFlag,
  resolveTarget,
  pruneOrphans,
  describeTarget,
};
