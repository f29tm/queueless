import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps the on-device speech recognizer for voice symptom entry (FR-VOICE-01).
///
/// Audio is processed for transcription only and never persisted — callers
/// receive text exclusively (NFR-PRIV-VOICE-01). When the device has no
/// recognizer or the patient denies the microphone permission, [init] returns
/// false and the typed form remains the path forward (FR-VOICE-04/05).
class SpeechInputService {
  SpeechInputService({SpeechToText? speech}) : _stt = speech ?? SpeechToText();

  final SpeechToText _stt;
  bool _ready = false;
  String? _lastError;

  bool get isReady => _ready;
  bool get isListening => _stt.isListening;
  String? get lastError => _lastError;

  /// Initializes the recognizer, prompting for microphone permission at point
  /// of use (FR-VOICE-04). Safe to call repeatedly — a denied attempt can be
  /// retried after the patient grants permission in settings.
  Future<bool> init({void Function(String status)? onStatus}) async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(
        onError: (SpeechRecognitionError e) => _lastError = e.errorMsg,
        onStatus: (status) => onStatus?.call(status),
      );
    } catch (_) {
      // Plugin missing / unsupported platform — fall back to typing.
      _ready = false;
    }
    return _ready;
  }

  /// Picks the best recognition locale for an app language code ('en' or
  /// 'ar') from what the device actually supports (FR-VOICE-02). Returns null
  /// when no match exists so the recognizer uses the device default.
  Future<String?> resolveLocaleId(String languageCode) async {
    if (!_ready) return null;

    final preferred = languageCode == 'ar'
        ? const ['ar_AE', 'ar-AE', 'ar_SA', 'ar-SA']
        : const ['en_US', 'en-US', 'en_GB', 'en-GB'];

    try {
      final locales = await _stt.locales();
      for (final id in preferred) {
        if (locales.any((l) => l.localeId == id)) return id;
      }
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith(languageCode)) {
          return locale.localeId;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Starts listening and streams partial + final transcripts to [onText]
  /// (FR-VOICE-03). No-op when [init] has not succeeded.
  Future<void> start({
    String? localeId,
    required void Function(String text, bool isFinal) onText,
  }) async {
    if (!_ready) return;
    await _stt.listen(
      listenOptions:
          SpeechListenOptions(partialResults: true, localeId: localeId),
      onResult: (SpeechRecognitionResult r) =>
          onText(r.recognizedWords, r.finalResult),
    );
  }

  /// Stops listening and delivers the final result to the [start] callback.
  Future<void> stop() => _stt.stop();

  /// Aborts listening without delivering a final result.
  Future<void> cancel() => _stt.cancel();
}
