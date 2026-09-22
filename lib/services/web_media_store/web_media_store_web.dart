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
  static const _kindIndex = 'kind_idx';
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
      // v2: índice por 'kind'. Sem ele, listar as pendências obrigava a ler
      // todos os registros — com os bytes das fotos junto — só para
      // descobrir os nomes.
      version: 2,
      onUpgradeNeeded: (VersionChangeEvent e) {
        final db = e.database;
        final store = db.objectStoreNames.contains(_storeName)
            ? e.transaction.objectStore(_storeName)
            : db.createObjectStore(_storeName, keyPath: 'id');

        if (!store.indexNames.contains(_kindIndex)) {
          store.createIndex(_kindIndex, 'kind');
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

  /// Lista os nomes das mídias pendentes SEM carregar os bytes.
  ///
  /// Antes usava getAll(), que trazia cada registro inteiro — todas as
  /// fotos completas na memória só para ler os nomes. Com 3-4 fotos isso
  /// eram dezenas de MB por chamada, e a contagem roda sempre que o painel
  /// principal abre, volta do segundo plano ou reconecta. Era o que
  /// derrubava aparelhos de 4 GB.
  ///
  /// openKeyCursor sobre o índice 'kind' devolve apenas as CHAVES; os bytes
  /// nunca saem do IndexedDB.
  static Future<List<String>> listPendingFilenames(String kind) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final index = txn.objectStore(_storeName).index(_kindIndex);

    final nomes = <String>[];
    await for (final cursor in index.openKeyCursor(
      key: kind,
      autoAdvance: true,
    )) {
      nomes.add(cursor.primaryKey as String);
    }
    await txn.completed;

    return nomes;
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

  /// Conta as pendências sem ler nenhum registro — nem chaves, nem bytes.
  /// É o caminho usado pelo painel principal a cada carga.
  static Future<int> pendingCount(String kind) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final total =
        await txn.objectStore(_storeName).index(_kindIndex).count(kind);
    await txn.completed;
    return total;
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
