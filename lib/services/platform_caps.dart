import 'package:flutter/foundation.dart' show kIsWeb;

/// Capacidades por plataforma — concentra as ramificações web/nativo da
/// versão PWA (ver docs/plano_versao_web.md) para não espalhar kIsWeb pelo
/// código.
class PlatformCaps {
  PlatformCaps._();

  /// Rodando no navegador (PWA)?
  static bool get isWeb => kIsWeb;

  /// Sistema de arquivos real (path_provider + dart:io). Na web, fotos e
  /// áudios offline vivem no IndexedDB via MediaStore.
  static bool get hasFileSystem => !kIsWeb;

  /// permission_handler funciona (Android/iOS). Na web, as permissões são
  /// pedidas pelo próprio navegador no momento do uso de cada API.
  static bool get hasPermissionHandler => !kIsWeb;

  /// Gravação de áudio contínua em arquivo (nativo). Na web a gravação é por
  /// segmentos e somente com a tela ativa (Fase 4 do plano web).
  static bool get hasContinuousAudioRecording => !kIsWeb;
}
