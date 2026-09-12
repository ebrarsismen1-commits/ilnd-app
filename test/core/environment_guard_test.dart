import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/services/app_config.dart';

// Güvenlik denetimi C-2: debug derlemenin canlı projeye bağlandığı durum
// tespit edilebilir olmalı (ekran bandı + analitik kapalı).
void main() {
  test('debug derleme canlı projeye bağlıysa işaretlenir', () {
    expect(
      AppConfig.isDebugBuildOnProd(isDebug: true, projectId: 'ilnd-app-8dcbd'),
      isTrue,
    );
  });

  test('release derlemesi canlı projede işaretlenmez', () {
    expect(
      AppConfig.isDebugBuildOnProd(isDebug: false, projectId: 'ilnd-app-8dcbd'),
      isFalse,
    );
  });

  test('debug derleme staging/emülatör projesinde işaretlenmez', () {
    expect(
      AppConfig.isDebugBuildOnProd(isDebug: true, projectId: 'ilnd-staging'),
      isFalse,
    );
    expect(AppConfig.isDebugBuildOnProd(isDebug: true, projectId: ''), isFalse);
  });
}
