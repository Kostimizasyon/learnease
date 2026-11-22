import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/recording_session.dart';
import 'package:learnese/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PreferencesService', () {
    late PreferencesService prefsService;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefsService = PreferencesService();
    });

    test('returns default buffer seconds and persists valid updates', () async {
      expect(
        await prefsService.getLastBufferSeconds(),
        RecordingSession.defaultBufferSeconds,
      );

      await prefsService.setLastBufferSeconds(90);
      expect(await prefsService.getLastBufferSeconds(), 90);
    });

    test(
      'clamps out-of-range stored values and rejects invalid writes',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          PreferencesService.lastBufferSecondsKey: 999,
        });
        final service = PreferencesService();
        expect(
          await service.getLastBufferSeconds(),
          RecordingSession.maxBufferSeconds,
        );

        await expectLater(service.setLastBufferSeconds(0), throwsRangeError);
        await expectLater(
          service.setLastBufferSeconds(RecordingSession.maxBufferSeconds + 1),
          throwsRangeError,
        );
      },
    );

    test('persists overlay hint dismissed flag', () async {
      expect(await prefsService.isOverlayHintDismissed(), isFalse);
      await prefsService.setOverlayHintDismissed(true);
      expect(await prefsService.isOverlayHintDismissed(), isTrue);
    });
  });
}
