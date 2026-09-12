/**
 * Sunucunun tuttuğu toplu sayaçlar.
 *
 * Güvenlik denetimi H-1/H-6 (2026-09-13): istemci eskiden bu sayıları
 * koleksiyonu kendisi sayarak buluyordu; bunun için `daily_checkins` ve
 * `events/{id}/rsvps` tüm girişli kullanıcılara okunabilir olmak zorundaydı
 * (herkesin uid'i, aktif günleri, hangi buluşmaya gittiği). Artık okumalar
 * kapalı, sayılar burada hesaplanıp tek bir dokümana yazılıyor.
 *
 * İkisi de İDEMPOTENT: her çağrı sayıyı baştan hesaplar, artırma yapmaz. Bu
 * yüzden tetikleyicinin iki kez ya da sırasız çalışması yanlış sayı üretmez.
 */

/**
 * @param {number} nowMs epoch ms
 * @param {number} days kaç gün
 * @return {string[]} bugünden geriye YYYY-MM-DD (UTC) dizeleri
 */
function recentDateKeys(nowMs, days) {
  const keys = [];
  for (let i = 0; i < days; i++) {
    keys.push(new Date(nowMs - i * 86400000).toISOString().slice(0, 10));
  }
  return keys;
}

/**
 * Bir etkinliğin katılımcı sayısını yeniden hesaplar.
 * Etkinlik dokümanı yoksa (seed --prune ile silinmiş) yeni doküman YARATMAZ.
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} eventId etkinlik
 * @return {Promise<number|null>} yazılan sayı, etkinlik yoksa null
 */
async function recomputeRsvpCount(db, eventId) {
  const eventRef = db.collection("events").doc(eventId);
  const agg = await eventRef.collection("rsvps").count().get();
  const count = agg.data().count || 0;
  try {
    await eventRef.update({rsvpCount: count});
  } catch (err) {
    // 5 = NOT_FOUND
    if (err.code === 5 || /NOT_FOUND/i.test(String(err.message))) return null;
    throw err;
  }
  return count;
}

/**
 * Son 7 günde check-in yapan benzersiz kullanıcı sayısı.
 * Her kullanıcı-gün tek doküman (uid_tarih), yani bu "kullanıcı-gün" sayısıdır;
 * eski istemci hesabıyla aynı tanım. İstemci yerel gününü yazdığı için UTC
 * penceresi bir gün geniş tutulur.
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {number} [nowMs] epoch ms (test için)
 * @return {Promise<number>} yazılan sayı
 */
async function recomputeWeeklyActive(db, nowMs = Date.now()) {
  const dates = recentDateKeys(nowMs + 86400000, 8);
  const agg = await db.collection("daily_checkins")
      .where("date", "in", dates)
      .count()
      .get();
  const count = agg.data().count || 0;
  await db.collection("public_stats").doc("weekly_active").set({
    count,
    window: dates,
    updatedAtMs: nowMs,
  });
  return count;
}

module.exports = {recentDateKeys, recomputeRsvpCount, recomputeWeeklyActive};
