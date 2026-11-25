import 'settings_service.dart';
import 'storage_service.dart';
import 'watch_folder.dart';
import 'watch_import_service.dart';

enum WatchSyncState { notLinked, missing, noAccess, unchanged, imported, failed }

class WatchSyncOutcome {
  final WatchSyncState state;
  final WatchImportResult? result;
  final String? error;

  const WatchSyncOutcome(this.state, {this.result, this.error});
}

class WatchSyncService {
  WatchSyncService({
    required StorageService storage,
    required SettingsService settings,
    required WatchFolderAccess access,
  })  : _storage = storage,
        _settings = settings,
        _access = access;

  final StorageService _storage;
  final SettingsService _settings;
  final WatchFolderAccess _access;

  static const fileName = 'Gadgetbridge.db';

  /// Imports the linked folder's Gadgetbridge.db when its last-modified time
  /// differs from the last imported one. Never throws. [force] skips the
  /// unchanged check.
  Future<WatchSyncOutcome> syncIfNewer({bool force = false}) async {
    try {
      final uri = await _settings.watchFolderUri;
      if (uri == null) return const WatchSyncOutcome(WatchSyncState.notLinked);

      final stat = await _access.stat(uri, fileName);
      if (stat == null) return const WatchSyncOutcome(WatchSyncState.missing);

      if (!force && stat.lastModified == await _settings.watchDbLastModified) {
        return const WatchSyncOutcome(WatchSyncState.unchanged);
      }

      final path = await _access.copy(uri, fileName);
      if (path == null) return const WatchSyncOutcome(WatchSyncState.missing);

      final result = await WatchImportService(_storage).importGadgetbridge(path);
      await _settings.setWatchDbLastModified(stat.lastModified);
      return WatchSyncOutcome(WatchSyncState.imported, result: result);
    } on WatchFolderAccessLost {
      return const WatchSyncOutcome(WatchSyncState.noAccess);
    } on WatchImportException catch (e) {
      return WatchSyncOutcome(WatchSyncState.failed, error: e.message);
    } catch (e) {
      return WatchSyncOutcome(WatchSyncState.failed, error: e.toString());
    }
  }
}
