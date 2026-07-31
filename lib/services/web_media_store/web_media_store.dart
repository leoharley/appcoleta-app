// Ponto de entrada do WebMediaStore: na web exporta a implementação
// IndexedDB; no nativo, um stub (os chamadores usam PlatformCaps para nunca
// invocá-lo fora da web).
export 'web_media_store_stub.dart'
    if (dart.library.html) 'web_media_store_web.dart';
