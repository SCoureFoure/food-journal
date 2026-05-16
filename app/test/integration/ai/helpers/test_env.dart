import 'dart:io';

/// Reads [key] from Platform.environment first, then falls back to parsing
/// the root-level ../.env (one level above app/). Never throws.
String? readRootEnv(String key) {
  final fromEnv = Platform.environment[key];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  try {
    for (final line in File('../.env').readAsLinesSync()) {
      if (line.startsWith('$key=')) return line.substring(key.length + 1).trim();
    }
  } catch (_) {}
  return null;
}
