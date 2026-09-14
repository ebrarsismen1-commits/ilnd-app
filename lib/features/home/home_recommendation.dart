enum HomeRecommendation {
  restart,
  morning,
  checkIn,
  rest,
  focus,
  journal,
  night,
}

/// One recommendation, with explicit precedence and no navigation side effects.
HomeRecommendation recommendForHome({
  required int hour,
  required String? mood,
  required bool returning,
  required bool ritualDone,
}) {
  if (returning && mood == null) return HomeRecommendation.restart;
  if ((hour >= 21 || hour < 4) && !ritualDone) return HomeRecommendation.night;
  if (mood == 'tired' || mood == 'hard') return HomeRecommendation.rest;
  if (mood == 'good') return HomeRecommendation.focus;
  if (mood == 'calm' || ritualDone && (hour >= 21 || hour < 4)) {
    return HomeRecommendation.journal;
  }
  if (hour >= 4 && hour < 12) return HomeRecommendation.morning;
  return HomeRecommendation.checkIn;
}
