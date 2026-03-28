import 'package:flutter/foundation.dart';

/// Resolves the REST API base URL for Track A (Flutter → FastAPI).
///
/// - `API_BASE_URL` compile-time env overrides everything (e.g. `--dart-define=API_BASE_URL=http://192.168.1.5:8000`).
/// - Android emulators use `10.0.2.2` to reach the host machine (not `localhost`).
/// - Other platforms default to localhost.
String resolveDefaultApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) {
    return fromEnv;
  }
  if (kIsWeb) {
    return 'http://localhost:8000';
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8000';
    default:
      return 'http://localhost:8000';
  }
}
