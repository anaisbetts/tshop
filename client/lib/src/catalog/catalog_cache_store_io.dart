import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tshop/src/catalog/catalog_cache_store.dart';

const String _cacheDirName = 'tshop_catalog_cache';
const String _pointerFileName = 'pointer.json';
const String _catalogFileName = 'catalog.json';
const String _metaFileName = 'meta.json';

/// Callback returning the base directory used by [FileCatalogCacheStore].
typedef CacheDirectoryProvider = Future<Directory> Function();

/// Local filesystem [CatalogCacheStore] for Android and desktop targets.
class FileCatalogCacheStore implements CatalogCacheStore {
  /// Creates a [FileCatalogCacheStore] backed by [directoryProvider].
  FileCatalogCacheStore({CacheDirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final CacheDirectoryProvider _directoryProvider;

  @override
  Future<CachedCatalogSnapshot?> read() async {
    try {
      final dir = await _cacheDir();
      final pointerFile = File('${dir.path}/$_pointerFileName');
      final catalogFile = File('${dir.path}/$_catalogFileName');
      if (!pointerFile.existsSync() || !catalogFile.existsSync()) {
        return null;
      }

      final pointerJson = await pointerFile.readAsString();
      final catalogBytes = await catalogFile.readAsBytes();
      final metaFile = File('${dir.path}/$_metaFileName');

      String? etag;
      DateTime? savedAt;
      if (metaFile.existsSync()) {
        final decoded = jsonDecode(await metaFile.readAsString());
        if (decoded is Map<String, dynamic>) {
          etag = decoded['etag'] as String?;
          final savedAtRaw = decoded['savedAt'] as String?;
          if (savedAtRaw != null) {
            savedAt = DateTime.tryParse(savedAtRaw);
          }
        }
      }

      return CachedCatalogSnapshot(
        pointerJson: pointerJson,
        catalogBytes: Uint8List.fromList(catalogBytes),
        savedAt: savedAt ?? pointerFile.lastModifiedSync().toUtc(),
        etag: etag,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(CachedCatalogSnapshot snapshot) async {
    final dir = await _cacheDir();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    await _writeBytesAtomically(
      File('${dir.path}/$_catalogFileName'),
      snapshot.catalogBytes,
    );
    await _writeStringAtomically(
      File('${dir.path}/$_pointerFileName'),
      snapshot.pointerJson,
    );
    final meta = <String, Object?>{
      'etag': snapshot.etag,
      'savedAt': snapshot.savedAt.toUtc().toIso8601String(),
    };
    await _writeStringAtomically(
      File('${dir.path}/$_metaFileName'),
      jsonEncode(meta),
    );
  }

  @override
  Future<void> clear() async {
    final dir = await _cacheDir();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  Future<Directory> _cacheDir() async {
    final baseDir = await _directoryProvider();
    return Directory('${baseDir.path}/$_cacheDirName');
  }
}

/// Creates a [FileCatalogCacheStore] backed by application support storage.
CatalogCacheStore createPlatformCatalogCacheStore() => FileCatalogCacheStore();

Future<void> _writeBytesAtomically(File target, Uint8List bytes) async {
  final tempFile = File('${target.path}.tmp');
  await tempFile.writeAsBytes(bytes, flush: true);
  await tempFile.rename(target.path);
}

Future<void> _writeStringAtomically(File target, String contents) async {
  final tempFile = File('${target.path}.tmp');
  await tempFile.writeAsString(contents, flush: true);
  await tempFile.rename(target.path);
}
