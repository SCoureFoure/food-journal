import 'package:flutter/services.dart';

class WatchFolderLink {
  final String uri;
  final String label;
  const WatchFolderLink(this.uri, this.label);
}

class WatchFileStat {
  final int lastModified;
  final int size;
  const WatchFileStat(this.lastModified, this.size);
}

class WatchFolderAccessLost implements Exception {
  const WatchFolderAccessLost();
}

/// Seam over the platform channel so tests can fake it.
abstract class WatchFolderAccess {
  Future<WatchFolderLink?> pickFolder();

  /// Null = file missing. Throws [WatchFolderAccessLost] when the grant is gone.
  Future<WatchFileStat?> stat(String uri, String name);

  /// Local path of a copy of the file; null = missing. Throws [WatchFolderAccessLost].
  Future<String?> copy(String uri, String name);
}

class PlatformWatchFolderAccess implements WatchFolderAccess {
  static const _channel = MethodChannel('food_journal/watch_folder');

  @override
  Future<WatchFolderLink?> pickFolder() async {
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('pickFolder');
      if (r == null) return null;
      return WatchFolderLink(r['uri'] as String, r['label'] as String);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<WatchFileStat?> stat(String uri, String name) async {
    try {
      final r = await _channel
          .invokeMapMethod<String, dynamic>('stat', {'uri': uri, 'name': name});
      if (r == null) return null;
      return WatchFileStat(
          (r['lastModified'] as num).toInt(), (r['size'] as num).toInt());
    } on PlatformException catch (e) {
      if (e.code == 'no_access') throw const WatchFolderAccessLost();
      rethrow;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<String?> copy(String uri, String name) async {
    try {
      return await _channel
          .invokeMethod<String>('copy', {'uri': uri, 'name': name});
    } on PlatformException catch (e) {
      if (e.code == 'no_access') throw const WatchFolderAccessLost();
      rethrow;
    } on MissingPluginException {
      return null;
    }
  }
}
