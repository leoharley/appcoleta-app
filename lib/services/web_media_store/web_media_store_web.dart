import 'dart:js_interop';
import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';
import 'package:web/web.dart' as web;

/// Armazenamento offline de mídias (fotos/áudios) da versão web, em
/// IndexedDB. Papel equivalente ao das pastas offline_photos/offline_audios
/// do nativo: o que está aqui é pendente por definição — cada item é apagado
/// após upload bem-sucedido, o que dá retry natural em caso de falha de rede.
class WebMediaStore {
  WebMediaStore._();

  static const _dbName = 'appcoleta_media';
  static const _storeName = 'media';
  static Database? _db;
  static bool _persistenceRequested = false;

  static Future<Database> _open() async {
    if (_db != null) return _db!;

    // Pedir armazenamento persistente ao navegador (mitiga a limpeza
    // automática de dados do Safari/Chrome sob pressão de espaço).
    if (!_persistenceRequested) {
      _persistenceRequested = true;
      try {
        await web.window.navigator.storage.persist().toDart;
      } catch (e) {
        print('⚠️ storage.persist() indisponível: $e');
      }
    }

    final factory = idbFactoryBrowser;
    _db = await factory.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (VersionChangeEvent e) {
        final db = e.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName, keyPath: 'id');
        }
      },
    );
    return _db!;
  }

  /// Salva uma mídia pendente. [kind] é 'photo' ou 'audio'.
  static Future<void> save({
    required String filename,
    required Uint8List bytes,
    required String kind,
  }) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    await txn.objectStore(_storeName).put({
      'id': filename,
      'kind': kind,
      'bytes': bytes,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await txn.completed;
    print('💾 WebMediaStore: $kind salvo ($filename, ${bytes.length} bytes)');
  }

  static Future<List<String>> listPendingFilenames(String kind) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final all = await txn.objectStore(_storeName).getAll();
    await txn.completed;

    return all
        .whereType<Map>()
        .where((m) => m['kind'] == kind)
        .map((m) => m['id'] as String)
        .toList();
  }

  static Future<Uint8List?> readBytes(String filename) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final record = await txn.objectStore(_storeName).getObject(filename);
    await txn.completed;

    if (record is Map && record['bytes'] != null) {
      final bytes = record['bytes'];
      if (bytes is Uint8List) return bytes;
      if (bytes is List) return Uint8List.fromList(bytes.cast<int>());
    }
    return null;
  }

  static Future<void> delete(String filename) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    await txn.objectStore(_storeName).delete(filename);
    await txn.completed;
  }

  static Future<int> pendingCount(String kind) async {
    return (await listPendingFilenames(kind)).length;
  }

  /// Salva o conteúdo de um blob URL (retornado pelo MediaRecorder via
  /// pacote record na web) como mídia pendente, e libera o blob.
  /// Retorna o tamanho salvo em bytes.
  static Future<int> saveFromBlobUrl({
    required String blobUrl,
    required String filename,
    required String kind,
  }) async {
    final response = await web.window.fetch(blobUrl.toJS).toDart;
    final buffer = await response.arrayBuffer().toDart;
    final bytes = buffer.toDart.asUint8List();

    await save(filename: filename, bytes: bytes, kind: kind);

    try {
      web.URL.revokeObjectURL(blobUrl);
    } catch (_) {}

    return bytes.length;
  }
}
