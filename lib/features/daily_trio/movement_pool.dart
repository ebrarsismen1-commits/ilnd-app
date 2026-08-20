import 'package:flutter/material.dart';

/// Ekipmansız, ev/yurt odasına sığan kısa hareket önerileri.
///
/// İçerik kod-içi TR+EN taşır (kArticles emsali): bunlar UI metni değil
/// içeriktir; arb şişirilmez. Seçim deterministiktir — aynı gün herkese
/// aynı hareket (kohort hissi), gün değişince döner.
class MovementItem {
  const MovementItem({
    required this.icon,
    required this.tr,
    required this.en,
    required this.minutes,
  });

  final IconData icon;
  final String tr;
  final String en;
  final int minutes;

  String forLocale(String localeCode) => localeCode.startsWith('en') ? en : tr;
}

const kMovementPool = <MovementItem>[
  MovementItem(
    icon: Icons.directions_walk_rounded,
    tr: '20 dakikalık tempolu yürüyüş — telefonsuz, sadece sen',
    en: 'A 20-minute brisk walk — no phone, just you',
    minutes: 20,
  ),
  MovementItem(
    icon: Icons.self_improvement_rounded,
    tr: '10 dakika esneme: boyun, omuz, bel — masa başının panzehiri',
    en: '10 minutes of stretching: neck, shoulders, lower back',
    minutes: 10,
  ),
  MovementItem(
    icon: Icons.stairs_rounded,
    tr: 'Asansör yok bugün: 5 kat merdiven, kendi temponda',
    en: 'No elevator today: 5 flights of stairs at your own pace',
    minutes: 10,
  ),
  MovementItem(
    icon: Icons.music_note_rounded,
    tr: '3 şarkılık dans molası — kimse görmüyor, sesi aç',
    en: 'A 3-song dance break — nobody is watching, turn it up',
    minutes: 10,
  ),
  MovementItem(
    icon: Icons.accessibility_new_rounded,
    tr: 'Yurt odası seti: 3x10 çömelme + 3x10 şınav (dizden serbest)',
    en: 'Dorm-room set: 3x10 squats + 3x10 push-ups (knees allowed)',
    minutes: 12,
  ),
  MovementItem(
    icon: Icons.park_rounded,
    tr: '12-3-30 yürüyüşü: eğimli tempolu 15 dakika (yokuş da olur)',
    en: 'A 12-3-30 style walk: 15 minutes uphill or incline',
    minutes: 15,
  ),
  MovementItem(
    icon: Icons.sports_gymnastics_rounded,
    tr: 'Sabah açılışı: 5 dakika tüm vücut esnetme, yataktan çıkar çıkmaz',
    en: 'Morning opener: 5 minutes of full-body stretching, right out of bed',
    minutes: 5,
  ),
  MovementItem(
    icon: Icons.fitness_center_rounded,
    tr: 'Duvar oturuşu 3x40 saniye + 1 dakika plank — kısa ama gerçek',
    en: 'Wall sit 3x40 seconds + a 1-minute plank — short but real',
    minutes: 8,
  ),
];

/// Günün hareketi — yıl-günü üzerinden döner.
MovementItem movementForDay(DateTime day) {
  final dayOfYear = day.difference(DateTime(day.year)).inDays;
  return kMovementPool[dayOfYear % kMovementPool.length];
}
