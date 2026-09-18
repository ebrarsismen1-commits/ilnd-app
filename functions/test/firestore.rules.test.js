/**
 * Firestore güvenlik kuralları — kullanıcı A ve kullanıcı B.
 *
 * Emülatörde çalışır (`firebase emulators:exec … "npm test"`); prod'a
 * erişemez: proje kimliği demo- önekli. Bu dosya her testten sonra
 * emülatördeki veriyi temizler; jest --runInBand ile sıralı koştuğu için diğer
 * dosyaları etkilemez.
 *
 * Güvenlik denetimi (2026-09-13) regresyonları: H-1, H-6, M-3 ve mevcut
 * sahiplik/kapalı koleksiyon kuralları.
 */
const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  query,
  where,
  serverTimestamp,
  Timestamp,
  arrayUnion,
  writeBatch,
} = require("firebase/firestore");

jest.setTimeout(30000);

let env;

beforeAll(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
  env = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || "demo-ilnd-test",
    firestore: {
      host,
      port: Number(port),
      // RULES_FILE: yalnız "bu testler eski kurallarda gerçekten kırılıyor mu"
      // kanıtı için (kırmızı-yeşil). Normal koşuda depodaki dosya.
      rules: fs.readFileSync(
          process.env.RULES_FILE || path.join(__dirname, "..", "..", "firestore.rules"),
          "utf8",
      ),
    },
  });
});

afterEach(async () => {
  await env.clearFirestore();
});

afterAll(async () => {
  await env.cleanup();
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

/** Kuralları atlayarak veri hazırlar. */
async function seed(p, data) {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), p), data));
}

const dateKey = (offsetDays = 0) =>
  new Date(Date.now() + offsetDays * 86400000).toISOString().slice(0, 10);

const habit = (userId, over = {}) => ({
  userId,
  name: "Su iç",
  targetDaysPerWeek: 5,
  createdAt: serverTimestamp(),
  ...over,
});

describe("habits (H-1)", () => {
  test("A kendi alışkanlığını oluşturur", async () => {
    await assertSucceeds(setDoc(doc(as("A"), "habits/h1"), habit("A")));
  });

  test("A, B adına alışkanlık oluşturamaz", async () => {
    await assertFails(setDoc(doc(as("A"), "habits/h1"), habit("B")));
  });

  test("A kendi alışkanlığının sahibini B'ye çeviremez", async () => {
    await seed("habits/h1", {userId: "A", name: "x", targetDaysPerWeek: 3});
    await assertFails(updateDoc(doc(as("A"), "habits/h1"), {userId: "B"}));
  });

  test("A kendi alışkanlığında başka alanı da güncelleyemez (update kapalı)", async () => {
    await seed("habits/h1", {userId: "A", name: "x", targetDaysPerWeek: 3});
    await assertFails(updateDoc(doc(as("A"), "habits/h1"), {name: "y"}));
  });

  test("A, B'nin alışkanlığını okuyamaz, listeleyemez, silemez", async () => {
    await seed("habits/hb", {userId: "B", name: "gizli", targetDaysPerWeek: 3});
    const a = as("A");
    await assertFails(getDoc(doc(a, "habits/hb")));
    await assertFails(getDocs(query(collection(a, "habits"), where("userId", "==", "B"))));
    await assertFails(getDocs(collection(a, "habits")));
    await assertFails(deleteDoc(doc(a, "habits/hb")));
  });

  test("A kendi alışkanlıklarını listeler ve siler", async () => {
    await seed("habits/ha", {userId: "A", name: "x", targetDaysPerWeek: 3});
    const a = as("A");
    await assertSucceeds(getDocs(query(collection(a, "habits"), where("userId", "==", "A"))));
    await assertSucceeds(deleteDoc(doc(a, "habits/ha")));
  });

  test.each([
    ["fazladan alan", {isPremium: true}],
    ["string olmayan ad", {name: 42}],
    ["boş ad", {name: ""}],
    ["aşırı uzun ad", {name: "x".repeat(501)}],
    ["negatif hedef", {targetDaysPerWeek: -1}],
    ["8 günlük hedef", {targetDaysPerWeek: 8}],
    ["istemci saati", {createdAt: Timestamp.fromDate(new Date("2020-01-01"))}],
  ])("%s reddedilir", async (_, over) => {
    await assertFails(setDoc(doc(as("A"), "habits/h1"), habit("A", over)));
  });

  test("kimliksiz kullanıcı hiçbir şey yapamaz", async () => {
    await assertFails(setDoc(doc(anon(), "habits/h1"), habit("A")));
  });
});

describe("habit_completions (H-1, M-3)", () => {
  const completion = (userId, habitId, over = {}) => ({
    habitId,
    userId,
    date: dateKey(),
    completedAt: serverTimestamp(),
    ...over,
  });

  beforeEach(async () => {
    await seed("habits/ha", {userId: "A", name: "a", targetDaysPerWeek: 3});
    await seed("habits/hb", {userId: "B", name: "b", targetDaysPerWeek: 3});
  });

  test("M-3: henüz olmayan tamamlama dokümanı okunabilir (transaction ilk tık)", async () => {
    await assertSucceeds(getDoc(doc(as("A"), `habit_completions/${dateKey()}_ha`)));
  });

  test("A kendi alışkanlığına tamamlama yazar", async () => {
    await assertSucceeds(setDoc(doc(as("A"), `habit_completions/${dateKey()}_ha`), completion("A", "ha")));
  });

  test("A, B'nin alışkanlığına tamamlama yazamaz", async () => {
    await assertFails(setDoc(doc(as("A"), `habit_completions/${dateKey()}_hb`), completion("A", "hb")));
  });

  test("A, B adına tamamlama yazamaz", async () => {
    await assertFails(setDoc(doc(as("A"), `habit_completions/${dateKey()}_ha`), completion("B", "ha")));
  });

  test("habitId'siz bozuk doküman yazılamaz (kurbanın ekranını düşüren yük)", async () => {
    const bad = completion("A", "ha");
    delete bad.habitId;
    await assertFails(setDoc(doc(as("A"), `habit_completions/${dateKey()}_ha`), bad));
  });

  test("sahiplik update ile taşınamaz", async () => {
    await seed(`habit_completions/${dateKey()}_ha`, {habitId: "ha", userId: "A", date: dateKey()});
    await assertFails(updateDoc(doc(as("A"), `habit_completions/${dateKey()}_ha`), {userId: "B"}));
  });

  test("doküman kimliği içerikle eşleşmeli", async () => {
    await assertFails(setDoc(doc(as("A"), "habit_completions/whatever"), completion("A", "ha")));
  });

  test("bozuk tarih reddedilir", async () => {
    await assertFails(setDoc(doc(as("A"), "habit_completions/x_ha"), completion("A", "ha", {date: "x"})));
  });

  // Phase 7: tamamlamalarda "bugüne yakın" şartı YOK, yani bu testler tarihin
  // kendisinin geçerliliğini kesin olarak ölçer (daily_checkins'teki
  // 2026-02-30 testi yakınlık şartı yüzünden de reddedilmiş olabilirdi).
  test.each(["2026-02-30", "2026-02-29", "2025-04-31", "2026-06-31"])(
      "takvimde olmayan gün %s reddedilir",
      async (date) => {
        await assertFails(setDoc(
            doc(as("A"), `habit_completions/${date}_ha`),
            completion("A", "ha", {date}),
        ));
      },
  );

  test("geçerli artık gün (2028-02-29) kabul edilir", async () => {
    const date = "2028-02-29";
    await assertSucceeds(setDoc(
        doc(as("A"), `habit_completions/${date}_ha`),
        completion("A", "ha", {date}),
    ));
  });

  test("A, B'nin tamamlamasını okuyamaz ve silemez", async () => {
    await seed(`habit_completions/${dateKey()}_hb`, {habitId: "hb", userId: "B", date: dateKey()});
    const a = as("A");
    await assertFails(getDoc(doc(a, `habit_completions/${dateKey()}_hb`)));
    await assertFails(getDocs(query(collection(a, "habit_completions"), where("userId", "==", "B"))));
    await assertFails(deleteDoc(doc(a, `habit_completions/${dateKey()}_hb`)));
  });

  test("A kendi tamamlamalarını sorgular ve siler", async () => {
    await seed(`habit_completions/${dateKey()}_ha`, {habitId: "ha", userId: "A", date: dateKey()});
    const a = as("A");
    await assertSucceeds(getDocs(query(
        collection(a, "habit_completions"),
        where("userId", "==", "A"),
        where("date", ">=", dateKey(-7)),
    )));
    await assertSucceeds(deleteDoc(doc(a, `habit_completions/${dateKey()}_ha`)));
  });
});

describe("daily_checkins (H-6)", () => {
  const checkin = (userId, date = dateKey()) => ({userId, date, createdAt: serverTimestamp()});

  test("A bugünün kaydını yazar (merge ile tekrar da)", async () => {
    const a = as("A");
    await assertSucceeds(setDoc(doc(a, `daily_checkins/A_${dateKey()}`), checkin("A")));
    await assertSucceeds(setDoc(doc(a, `daily_checkins/A_${dateKey()}`), checkin("A"), {merge: true}));
  });

  test("koleksiyon listelenemez ve B'nin kaydı okunamaz (uid sızıntısı)", async () => {
    await seed(`daily_checkins/B_${dateKey()}`, {userId: "B", date: dateKey()});
    const a = as("A");
    await assertFails(getDocs(collection(a, "daily_checkins")));
    await assertFails(getDoc(doc(a, `daily_checkins/B_${dateKey()}`)));
  });

  test.each([
    ["serbest dize", "x1"],
    ["imkânsız gün", "2026-02-30"],
    ["13. ay", "2026-13-01"],
    ["eksik sıfır", "2026-9-13"],
    ["çok eski gün", dateKey(-3)],
    ["gelecek gün", dateKey(3)],
  ])("%s reddedilir", async (_, date) => {
    await assertFails(setDoc(doc(as("A"), `daily_checkins/A_${date}`), checkin("A", date)));
  });

  test("B'nin kimliğiyle ya da B adına yazılamaz", async () => {
    const a = as("A");
    await assertFails(setDoc(doc(a, `daily_checkins/B_${dateKey()}`), checkin("B")));
    await assertFails(setDoc(doc(a, `daily_checkins/B_${dateKey()}`), checkin("A")));
  });

  test("fazladan alan reddedilir", async () => {
    await assertFails(setDoc(doc(as("A"), `daily_checkins/A_${dateKey()}`), {...checkin("A"), mood: "sad"}));
  });

  test("public_stats okunur ama yazılamaz", async () => {
    await seed("public_stats/weekly_active", {count: 3});
    const a = as("A");
    await assertSucceeds(getDoc(doc(a, "public_stats/weekly_active")));
    await assertFails(setDoc(doc(a, "public_stats/weekly_active"), {count: 999999}));
  });
});

describe("events/rsvps (H-1)", () => {
  beforeEach(async () => {
    await seed("events/e1", {title: "yürüyüş", startsAt: Timestamp.fromDate(new Date(Date.now() + 86400000))});
  });

  test("A kendi RSVP'sini yazar, okur ve siler", async () => {
    const a = as("A");
    await assertSucceeds(setDoc(doc(a, "events/e1/rsvps/A"), {userId: "A", createdAt: serverTimestamp()}));
    await assertSucceeds(getDoc(doc(a, "events/e1/rsvps/A")));
    await assertSucceeds(deleteDoc(doc(a, "events/e1/rsvps/A")));
  });

  test("katılımcı listesi ve B'nin RSVP'si okunamaz", async () => {
    await seed("events/e1/rsvps/B", {userId: "B"});
    const a = as("A");
    await assertFails(getDocs(collection(a, "events/e1/rsvps")));
    await assertFails(getDoc(doc(a, "events/e1/rsvps/B")));
  });

  test("A, B adına RSVP yazamaz ya da silemez", async () => {
    await seed("events/e1/rsvps/B", {userId: "B"});
    const a = as("A");
    await assertFails(setDoc(doc(a, "events/e1/rsvps/B"), {userId: "B", createdAt: serverTimestamp()}));
    await assertFails(deleteDoc(doc(a, "events/e1/rsvps/B")));
  });

  test("var olmayan etkinliğe RSVP yazılamaz", async () => {
    await assertFails(setDoc(doc(as("A"), "events/nope/rsvps/A"), {userId: "A", createdAt: serverTimestamp()}));
  });

  test("etkinlik dokümanına (rsvpCount dahil) yazılamaz", async () => {
    await assertFails(updateDoc(doc(as("A"), "events/e1"), {rsvpCount: 1000}));
  });
});

// ── Phase 10 (denetim M-6): users alt ağacında şema ─────────────────────
// İlk blok, uygulamanın GERÇEK yazma şekillerinin (repository'lerdeki map'ler)
// hâlâ geçtiğini kanıtlar; ikincisi düşmanca şekillerin reddedildiğini.
describe("users alt ağacı şeması (M-6)", () => {
  const food = (over = {}) => ({
    userId: "A",
    yemekAdi: "Mercimek çorbası",
    kalori: 180,
    protein: 9,
    karbonhidrat: 27,
    yag: 4,
    createdAt: Timestamp.now(),
    malzemeler: ["kırmızı mercimek", "soğan"],
    ...over,
  });
  const today = new Date().toISOString().slice(0, 10);

  describe("gerçek istemci yazmaları geçer", () => {
    test("öğün ekleme, malzeme düzeltme, yeniden hesaplama (food_repository)", async () => {
      const a = as("A");
      await assertSucceeds(setDoc(doc(a, "users/A/food_entries/f1"), food()));
      await assertSucceeds(updateDoc(doc(a, "users/A/food_entries/f1"), {malzemeler: ["mercimek"]}));
      await assertSucceeds(updateDoc(doc(a, "users/A/food_entries/f1"), {
        malzemeler: ["mercimek", "zeytinyağı"], kalori: 240, protein: 9, karbonhidrat: 27, yag: 10,
      }));
    });

    test("malzemesi olmayan eski öğün düzeltilebilir", async () => {
      const legacy = food();
      delete legacy.malzemeler;
      await seed("users/A/food_entries/old", legacy);
      await assertSucceeds(updateDoc(doc(as("A"), "users/A/food_entries/old"), {malzemeler: ["pilav"]}));
    });

    test("günlük ekleme ve silme (journal_repository)", async () => {
      const a = as("A");
      await assertSucceeds(setDoc(doc(a, "users/A/journal_entries/j1"), {
        userId: "A", body: "x".repeat(5000), ilndReply: "sıcak bir karşılık", createdAt: Timestamp.now(),
      }));
      await assertSucceeds(deleteDoc(doc(a, "users/A/journal_entries/j1")));
    });

    test("gece ritüeli iki kez merge ile yazılır (sleep_ritual_provider)", async () => {
      const a = as("A");
      const data = {date: today, createdAt: serverTimestamp()};
      await assertSucceeds(setDoc(doc(a, `users/A/sleep_rituals/${today}`), data, {merge: true}));
      await assertSucceeds(setDoc(doc(a, `users/A/sleep_rituals/${today}`), data, {merge: true}));
    });

    test("plan başlat, gün bitir, sıfırla (plans_repository)", async () => {
      const a = as("A");
      const batch = writeBatch(a);
      batch.set(doc(a, "users/A/plan_progress/_state"), {activePlanId: "uyku-7", updatedAt: serverTimestamp()}, {merge: true});
      batch.set(doc(a, "users/A/plan_progress/uyku-7"), {startedAt: serverTimestamp(), updatedAt: serverTimestamp()}, {merge: true});
      await assertSucceeds(batch.commit());
      await assertSucceeds(setDoc(doc(a, "users/A/plan_progress/uyku-7"),
          {completedDayIds: arrayUnion("d1"), updatedAt: serverTimestamp()}, {merge: true}));
      await assertSucceeds(setDoc(doc(a, "users/A/plan_progress/uyku-7"),
          {completedDayIds: [], startedAt: serverTimestamp(), updatedAt: serverTimestamp()}, {merge: true}));
    });

    test("hareket seansı bitir ve sıfırla (movement_repository)", async () => {
      const a = as("A");
      await assertSucceeds(setDoc(doc(a, "users/A/movement_progress/sabah"),
          {completedSessionIds: arrayUnion("s1"), updatedAt: serverTimestamp()}, {merge: true}));
      await assertSucceeds(setDoc(doc(a, "users/A/movement_progress/sabah"),
          {completedSessionIds: [], updatedAt: serverTimestamp()}, {merge: true}));
    });

    test("profil fotoğrafı kaydet ve kaldır (avatar_repository)", async () => {
      const a = as("A");
      await assertSucceeds(setDoc(doc(a, "users/A"),
          {photoBase64: "A".repeat(200000), photoUpdatedAt: serverTimestamp()}, {merge: true}));
      await assertSucceeds(setDoc(doc(a, "users/A"), {photoBase64: null}, {merge: true}));
    });

    test("eski sürümün bıraktığı fazladan alan dokümanı kilitlemez", async () => {
      await seed("users/A", {legacyField: "eski", photoBase64: null});
      await assertSucceeds(setDoc(doc(as("A"), "users/A"), {photoBase64: "AAAA"}, {merge: true}));
    });
  });

  describe("düşmanca yazmalar reddedilir", () => {
    test.each([
      ["fazladan alan", {isPremium: true}],
      ["negatif kalori", {kalori: -5}],
      ["akıl dışı kalori", {kalori: 999999}],
      ["string kalori", {kalori: "180"}],
      ["1 MB yemek adı", {yemekAdi: "x".repeat(1000)}],
      ["51 malzeme", {malzemeler: Array.from({length: 51}, (_, i) => `m${i}`)}],
      ["başka kullanıcı adına", {userId: "B"}],
      ["gelecek tarih", {createdAt: Timestamp.fromMillis(Date.now() + 3 * 86400000)}],
    ])("öğün: %s", async (_, over) => {
      await assertFails(setDoc(doc(as("A"), "users/A/food_entries/f1"), food(over)));
    });

    test("öğün güncellemesi adını ya da sahibini değiştiremez", async () => {
      await seed("users/A/food_entries/f1", food());
      const a = as("A");
      await assertFails(updateDoc(doc(a, "users/A/food_entries/f1"), {yemekAdi: "başka"}));
      await assertFails(updateDoc(doc(a, "users/A/food_entries/f1"), {userId: "B"}));
    });

    test("günlük: aşırı uzun metin, güncelleme ve fazladan alan", async () => {
      const a = as("A");
      await assertFails(setDoc(doc(a, "users/A/journal_entries/big"), {
        userId: "A", body: "x".repeat(50001), ilndReply: "", createdAt: Timestamp.now(),
      }));
      await seed("users/A/journal_entries/j1", {userId: "A", body: "ilk", ilndReply: "", createdAt: Timestamp.now()});
      await assertFails(updateDoc(doc(a, "users/A/journal_entries/j1"), {body: "değişti"}));
      await assertFails(setDoc(doc(a, "users/A/journal_entries/j2"), {
        userId: "A", body: "x", ilndReply: "", createdAt: Timestamp.now(), mood: "sad",
      }));
    });

    test("tanımsız alt koleksiyona yazılamaz", async () => {
      await assertFails(setDoc(doc(as("A"), "users/A/anything/x"), {junk: "x".repeat(1000)}));
    });

    test("gece ritüeli: kimlik gün dizesiyle eşleşmeli", async () => {
      await assertFails(setDoc(doc(as("A"), "users/A/sleep_rituals/junk-1"), {date: "junk-1"}));
      await assertFails(setDoc(doc(as("A"), `users/A/sleep_rituals/${today}`), {date: "2026-01-01"}));
    });

    test("ilerleme listeleri sınırsız büyüyemez", async () => {
      const a = as("A");
      await assertFails(setDoc(doc(a, "users/A/plan_progress/p"),
          {completedDayIds: Array.from({length: 61}, (_, i) => `d${i}`)}));
      await assertFails(setDoc(doc(a, "users/A/movement_progress/m"),
          {completedSessionIds: Array.from({length: 201}, (_, i) => `s${i}`)}));
    });

    test("profil dokümanı: sınırı aşan fotoğraf, başka alan, silme", async () => {
      const a = as("A");
      await assertFails(setDoc(doc(a, "users/A"), {photoBase64: "A".repeat(900001)}));
      await assertFails(setDoc(doc(a, "users/A"), {isAdmin: true}, {merge: true}));
      await seed("users/A", {photoBase64: null});
      await assertFails(deleteDoc(doc(a, "users/A")));
    });

    test("B, A'nın ağacına geçerli şekilde bile yazamaz", async () => {
      await assertFails(setDoc(doc(as("B"), "users/A/food_entries/f1"), food()));
    });
  });
});

describe("users/{uid} profil alanları (Supabase profiles → Firestore)", () => {
  // profile_repository.dart'ın gerçekten gönderdiği şekil: toDoc() + sunucu damgası.
  const profile = (over = {}) => ({
    name: "Ela",
    onboardingDone: true,
    firstEntryDone: false,
    goals: ["uyku"],
    activityLevel: "aktif",
    diet: "vegan",
    allergies: ["gluten"],
    age: 31,
    heightCm: 168,
    weightKg: 72,
    profileUpdatedAt: serverTimestamp(),
    ...over,
  });

  describe("gerçek istemci yazmaları geçer", () => {
    test("onboarding kaydı → sahibi geri okur (uygulama yeniden açılışı)", async () => {
      const a = as("A");
      await assertSucceeds(setDoc(doc(a, "users/A"), profile(), {merge: true}));
      const snap = await assertSucceeds(getDoc(doc(a, "users/A")));
      expect(snap.data()).toMatchObject({name: "Ela", onboardingDone: true, heightCm: 168, weightKg: 72});
    });

    test("tekil bayrak güncellemesi (first_entry_screen) ve kayıt adı (signUp)", async () => {
      const a = as("A");
      await assertSucceeds(setDoc(doc(a, "users/A"),
          {onboardingDone: true, firstEntryDone: true, profileUpdatedAt: serverTimestamp()}, {merge: true}));
      await assertSucceeds(setDoc(doc(a, "users/A"),
          {name: "Deniz", profileUpdatedAt: serverTimestamp()}, {merge: true}));
    });

    test("fotoğraf ve profil aynı dokümanda birbirini kilitlemez", async () => {
      await seed("users/A", {photoBase64: "AAAA", photoUpdatedAt: Timestamp.now()});
      const a = as("A");
      await assertSucceeds(setDoc(doc(a, "users/A"), profile(), {merge: true}));
      await assertSucceeds(setDoc(doc(a, "users/A"),
          {photoBase64: "BBBB", photoUpdatedAt: serverTimestamp()}, {merge: true}));
    });

    test("migration script'inin yazdığı doküman istemci tarafından güncellenebilir", async () => {
      await seed("users/A", {
        name: "Ela", onboardingDone: true, firstEntryDone: true, goals: [], allergies: [],
        age: 31, heightCm: 168, weightKg: 72,
        profileMigratedAt: Timestamp.now(), profileMigratedFrom: "supabase",
      });
      await assertSucceeds(setDoc(doc(as("A"), "users/A"),
          {weightKg: 70, profileUpdatedAt: serverTimestamp()}, {merge: true}));
    });
  });

  describe("düşmanca yazmalar reddedilir", () => {
    test.each([
      ["sunucu damgası yok", {profileUpdatedAt: undefined}],
      ["sahte damga (migration'ı atlatmak)", {profileUpdatedAt: Timestamp.fromMillis(Date.now() + 86400000)}],
      ["131 yaş", {age: 131}],
      ["kesirli yaş", {age: 30.5}],
      ["negatif boy", {heightCm: -1}],
      ["701 kg", {weightKg: 701}],
      ["101 karakter ad", {name: "x".repeat(101)}],
      ["41 karakter diyet", {diet: "x".repeat(41)}],
      ["string bayrak", {onboardingDone: "true"}],
      ["51 hedef", {goals: Array.from({length: 51}, (_, i) => `g${i}`)}],
      ["liste olmayan alerji", {allergies: "gluten"}],
      ["istemci migration işareti koyamaz", {profileMigratedFrom: "supabase"}],
      ["tanımsız alan", {isPremium: true}],
    ])("%s", async (_, over) => {
      const data = profile(over);
      Object.keys(data).forEach((k) => data[k] === undefined && delete data[k]);
      await assertFails(setDoc(doc(as("A"), "users/A"), data, {merge: true}));
    });

    test("başka kullanıcının profili okunamaz ve yazılamaz", async () => {
      await seed("users/A", {name: "Ela", weightKg: 72, allergies: ["gluten"]});
      const b = as("B");
      await assertFails(getDoc(doc(b, "users/A")));
      await assertFails(setDoc(doc(b, "users/A"), profile(), {merge: true}));
      await assertFails(getDoc(doc(anon(), "users/A")));
      await assertFails(setDoc(doc(anon(), "users/A"), profile(), {merge: true}));
    });
  });
});

describe("mevcut sahiplik ve kapalı koleksiyonlar", () => {
  test("B, A'nın users alt ağacını okuyamaz ve yazamaz", async () => {
    await seed("users/A/journal_entries/j1", {body: "özel"});
    const b = as("B");
    await assertFails(getDoc(doc(b, "users/A/journal_entries/j1")));
    await assertFails(getDocs(collection(b, "users/A/journal_entries")));
    await assertFails(setDoc(doc(b, "users/A/journal_entries/j2"), {body: "enjekte"}));
    await assertFails(deleteDoc(doc(b, "users/A/journal_entries/j1")));
  });

  test("A kendi users alt ağacına erişir", async () => {
    const a = as("A");
    await assertSucceeds(setDoc(doc(a, "users/A/journal_entries/j1"), {
      userId: "A", body: "benim", ilndReply: "", createdAt: Timestamp.now(),
    }));
    await assertSucceeds(getDoc(doc(a, "users/A/journal_entries/j1")));
  });

  // ── Phase 8 (denetim H-4): davet kodu istemcide yazılamaz ──────────────
  test("A kendi user_growth dokümanını, eski kuralın izin verdiği biçimde bile oluşturamaz", async () => {
    await assertFails(setDoc(doc(as("A"), "user_growth/A"), {
      referral_code: "B0BSC0DE", // başkasının paylaştığı kod (gasp denemesi)
      referred_by_code: null,
      founding_member: false,
      premium_access_until: null,
    }));
  });

  test("A kendi user_growth dokümanını okuyabilir ama güncelleyemez", async () => {
    await seed("user_growth/A", {referral_code: "ABCD2345", founding_member: false});
    const a = as("A");
    await assertSucceeds(getDoc(doc(a, "user_growth/A")));
    await assertFails(updateDoc(doc(a, "user_growth/A"), {referral_code: "B0BSC0DE"}));
  });

  test("referral_codes eşlemesi okunamaz ve yazılamaz", async () => {
    await seed("referral_codes/ABCD2345", {uid: "B"});
    const a = as("A");
    await assertFails(getDoc(doc(a, "referral_codes/ABCD2345")));
    await assertFails(setDoc(doc(a, "referral_codes/ZZZZ2345"), {uid: "A"}));
  });

  test.each([
    ["island/B", {earned: ["pine"]}],
    ["user_growth/B", {referral_code: "ABCDEFGH"}],
    ["ai_usage/B_W1", {uid: "B", counts: {message: 1}}],
    ["referrals/r1", {referrer_id: "B"}],
    ["ai_token_usage/B_2026-09-13", {uid: "B"}],
    ["config/ai", {enabled: true}],
  ])("A, %s okuyamaz", async (p, data) => {
    await seed(p, data);
    await assertFails(getDoc(doc(as("A"), p)));
  });

  test.each([
    ["island/A", {earned: ["pine", "oven"]}],
    ["ai_usage/A_W1", {uid: "A", counts: {}}],
    ["referrals/r1", {referrer_id: "A"}],
    ["config/ai", {enabled: false}],
    ["articles/a1", {title: "x"}],
    ["plans/p1", {premium: false}],
  ])("A, %s yazamaz", async (p, data) => {
    await assertFails(setDoc(doc(as("A"), p), data));
  });
});
