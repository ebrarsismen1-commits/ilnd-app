import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Tema kurulumu font stillerine dokunuyor; testte ağdan font çekilmesin.
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('dark theme mirrors AppPalette.dark so Material overlays match', (
    tester,
  ) async {
    final t = AppTheme.dark;
    expect(t.scaffoldBackgroundColor, AppPalette.dark.base);
    expect(t.dialogTheme.backgroundColor, AppPalette.dark.surfaceStrong);
    expect(t.bottomSheetTheme.backgroundColor, AppPalette.dark.surfaceStrong);
    expect(t.colorScheme.primary, AppPalette.dark.accent);
    expect(t.colorScheme.onSurface, AppPalette.dark.text);
  });

  testWidgets('light theme keeps brand colors', (tester) async {
    final t = AppTheme.light;
    expect(t.scaffoldBackgroundColor, AppColors.cream);
    expect(t.colorScheme.primary, AppColors.sage);
  });
}
