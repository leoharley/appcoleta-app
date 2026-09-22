// Ponto de entrada do ImageDownscaler: na web usa createImageBitmap para
// reduzir a foto sem decodificá-la inteira; no nativo é no-op, porque lá o
// próprio image_picker já entrega a imagem redimensionada.
export 'image_downscaler_stub.dart'
    if (dart.library.html) 'image_downscaler_web.dart';
