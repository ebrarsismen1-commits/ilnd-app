import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/home/home_recommendation.dart';

void main() {
  test('return, time and mood resolve to one next step', () {
    HomeRecommendation choose(
      int hour,
      String? mood, {
      bool returning = false,
      bool done = false,
    }) => recommendForHome(
      hour: hour,
      mood: mood,
      returning: returning,
      ritualDone: done,
    );
    expect(choose(22, null, returning: true), HomeRecommendation.restart);
    expect(choose(9, null), HomeRecommendation.morning);
    expect(choose(15, null), HomeRecommendation.checkIn);
    expect(choose(15, 'tired'), HomeRecommendation.rest);
    expect(choose(15, 'hard'), HomeRecommendation.rest);
    expect(choose(15, 'good'), HomeRecommendation.focus);
    expect(choose(15, 'calm'), HomeRecommendation.journal);
    expect(choose(22, 'tired', returning: true), HomeRecommendation.night);
    expect(choose(22, null, done: true), HomeRecommendation.journal);
    expect(choose(3, null), HomeRecommendation.night);
    expect(choose(4, null), HomeRecommendation.morning);
  });
}
