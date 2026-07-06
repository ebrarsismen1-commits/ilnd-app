# ADR-0002: Etkinlik + RSVP şeması (Topluluk v2)

**Status:** Accepted
**Date:** 2026-07-04

## Decision
Kök koleksiyon `events` (yalnız admin/seed yazar, articles deseni) +
alt koleksiyon `events/{id}/rsvps/{uid}` (kullanıcı yalnız kendi RSVP
dokümanını oluşturur/siler; sayım aggregate `count()` ile).

## Context
Roadmap NEXT-2: elle girilen İstanbul etkinlikleri + RSVP. Blueprint §3
Etkinlik primitifi bu şemanın üstüne büyüyecek (festival = mega etkinlik).

## Alternatives
1. Event dokümanında `rsvpIds` array'i — basit ama: yazma çekişmesi (aynı
   doküman), 1MB doküman sınırı (festival ölçeğinde patlar), "yalnız kendini
   ekle" kuralı array'de kirli.
2. Kök `rsvps` koleksiyonu (eventId+userId alanlı) — çalışır ama composite
   index ister ve event-altı okuma doğallığını kaybeder.

## Pros / Cons
+ Deterministik doc id (`uid`) = idempotent RSVP, çift kayıt imkânsız
+ `count()` aggregate = katılımcı sayısı için doküman okuma maliyeti yok
+ 10k katılımcılı etkinlikte de aynı şema (İlke #4)
− Kullanıcının "katıldığım etkinlikler" listesi ileride collectionGroup
  sorgusu ister (rsvps'e userId alanı şimdiden yazılıyor — hazır)

## Reason
Articles ile kanıtlanmış admin-seed deseninin simetriği + ölçekte tek
doğru RSVP modeli.

## Consequences
- firestore.rules'a events + rsvps blokları; client events'e asla yazamaz
- İçerik kaynağı `content/events.json` + `functions/scripts/seedEvents.js`
- Sert Kural #2 gereği tüm event provider'ları köprü-auth gated

## Future Impact
Bilet/ödeme geldiğinde RSVP dokümanı `status` (going|paid|checked_in) alanı
kazanır — şema kırılmaz. Circle bağlantısı `events.circleId` ile eklenir.
