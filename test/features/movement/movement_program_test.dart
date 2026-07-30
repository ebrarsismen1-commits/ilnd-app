import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/movement/movement_program.dart';

MovementSession _session(String id, {String? video}) => MovementSession(
  id: id,
  title: 'seans $id',
  videoUrl: video ?? 'https://v/$id.mp4',
  minutes: 5,
);

MovementProgram _program({
  List<MovementSession>? sessions,
  MovementTranslation? en,
  bool premium = false,
}) => MovementProgram(
  id: 'sabah',
  title: 'sabah açılışı',
  description: 'Üç kısa seans.',
  level: MovementLevel.medium,
  premium: premium,
  sessions: sessions ?? [_session('s1'), _session('s2')],
  en: en,
);

void main() {
  group('MovementProgram', () {
    test('videosuz seanslar oynatılabilir sayılmaz', () {
      final program = _program(
        sessions: [
          _session('s1'),
          _session('s2', video: ''),
        ],
      );

      expect(program.sessions.length, 2);
      expect(program.playableSessions.map((s) => s.id), ['s1']);
      // Süre yalnız oynatılabilir seanslardan toplanır — yoksa kullanıcıya
      // izleyemeyeceği dakikalar vaat edilir.
      expect(program.totalMinutes, 5);
    });

    test('hiç oynatılabilir seansı yoksa yayınlanabilir değildir', () {
      final program = _program(sessions: [_session('s1', video: '')]);
      expect(program.isPublishable, isFalse);
    });

    test('forLocale çeviriyi alan bazında uygular, eksikleri TR bırakır', () {
      final program = _program(
        en: const MovementTranslation(
          title: 'morning opener',
          // description bilerek boş: EN kullanıcı boş metin değil Türkçesini
          // görmeli (asla boş ekran).
          sessionTitles: {'s1': 'neck and shoulders'},
        ),
      );

      final en = program.forLocale('en');
      expect(en.title, 'morning opener');
      expect(en.description, 'Üç kısa seans.');
      expect(en.sessions[0].title, 'neck and shoulders');
      expect(en.sessions[1].title, 'seans s2'); // çevirisi yok → TR
      // Çeviri kimlikleri/videoları bozmamalı.
      expect(en.sessions[0].id, 's1');
      expect(en.sessions[0].videoUrl, 'https://v/s1.mp4');
    });

    test('forLocale TR dilinde programı olduğu gibi bırakır', () {
      final program = _program(
        en: const MovementTranslation(title: 'morning opener'),
      );
      expect(program.forLocale('tr').title, 'sabah açılışı');
    });
  });

  group('MovementProgress', () {
    test('sıradaki seans, tamamlanmamış ilk seanstır', () {
      final program = _program(
        sessions: [_session('s1'), _session('s2'), _session('s3')],
      );
      const progress = MovementProgress(completedSessionIds: {'s1'});

      expect(progress.nextSession(program)?.id, 's2');
      expect(progress.doneCountIn(program), 1);
      expect(progress.isComplete(program), isFalse);
    });

    test('hepsi bittiyse program tamamlanmış sayılır ve baştan başlar', () {
      final program = _program();
      const progress = MovementProgress(completedSessionIds: {'s1', 's2'});

      expect(progress.isComplete(program), isTrue);
      // "Yeniden izle": bitmiş programda sıradaki seans ilk seanstır.
      expect(progress.nextSession(program)?.id, 's1');
    });

    test('oynatılamayan seans ilerlemeyi tamamlanmış saymayı engellemez', () {
      // Videosu kaldırılmış bir seans yüzünden program sonsuza dek
      // "yarım" görünmemeli.
      final program = _program(
        sessions: [
          _session('s1'),
          _session('s2', video: ''),
        ],
      );
      const progress = MovementProgress(completedSessionIds: {'s1'});

      expect(progress.isComplete(program), isTrue);
    });

    test('boş programda sıradaki seans yoktur', () {
      final program = _program(sessions: const []);
      expect(const MovementProgress().nextSession(program), isNull);
      expect(const MovementProgress().isComplete(program), isFalse);
    });
  });
}
