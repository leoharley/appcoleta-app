import 'dart:typed_data';

/// Stub do WebMediaStore para plataformas nativas (Android/iOS), onde as
/// mídias offline vivem no sistema de arquivos (PhotoStorageService /
/// offline_audios). Nunca deve ser chamado fora da web — os chamadores são
/// protegidos por PlatformCaps.
class WebMediaStore {
  WebMediaStore._();

  static Future<void> save({
    required String filename,
    required Uint8List bytes,
    required String kind,
  }) async {
    throw UnsupportedError('WebMediaStore é exclusivo da versão web');
  }

  static Future<List<String>> listPendingFilenames(String kind) async {
    throw UnsupportedError('WebMediaStore é exclusivo da versão web');
  }

  static Future<Uint8List?> readBytes(String filename) async {
    throw UnsupportedError('WebMediaStore é exclusivo da versão web');
  }

  static Future<void> delete(String filename) async {
    throw UnsupportedError('WebMediaStore é exclusivo da versão web');
  }

  static Future<int> pendingCount(String kind) async {
    throw UnsupportedError('WebMediaStore é exclusivo da versão web');
  }

  static Future<int> saveFromBlobUrl({
    required String blobUrl,
    required String filename,
    required String kind,
  }) async {
    throw UnsupportedError('WebMediaStore é exclusivo da versão web');
  }
}
