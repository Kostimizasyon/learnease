import 'package:shared_preferences/shared_preferences.dart';

import '../data_models/recording_session.dart';

class PreferencesService {
  PreferencesService({this._preferences});

  static const String lastBufferSecondsKey = 'last_buffer_seconds';
  static const String overlayHintDismissedKey = 'overlay_hint_dismissed';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _getPrefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<int> getLastBufferSeconds() async {
    final prefs = await _getPrefs();
    final stored = prefs.getInt(lastBufferSecondsKey);
    if (stored == null) {
      return RecordingSession.defaultBufferSeconds;
    }
    return stored.clamp(
      RecordingSession.minBufferSeconds,
      RecordingSession.maxBufferSeconds,
    );
  }

  Future<void> setLastBufferSeconds(int seconds) async {
    if (seconds < RecordingSession.minBufferSeconds ||
        seconds > RecordingSession.maxBufferSeconds) {
      throw RangeError.range(
        seconds,
        RecordingSession.minBufferSeconds,
        RecordingSession.maxBufferSeconds,
        'seconds',
      );
    }
    final prefs = await _getPrefs();
    await prefs.setInt(lastBufferSecondsKey, seconds);
  }

  Future<bool> isOverlayHintDismissed() async {
    final prefs = await _getPrefs();
    return prefs.getBool(overlayHintDismissedKey) ?? false;
  }

  Future<void> setOverlayHintDismissed(bool dismissed) async {
    final prefs = await _getPrefs();
    await prefs.setBool(overlayHintDismissedKey, dismissed);
  }
}
