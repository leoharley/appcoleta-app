// Ponto de entrada do PwaInstall: na web exporta a implementação que conversa
// com o JS do index.html; no nativo, um stub inerte (o app nativo já está
// instalado — não há o que oferecer).
export 'pwa_install_stub.dart'
    if (dart.library.html) 'pwa_install_web.dart';
