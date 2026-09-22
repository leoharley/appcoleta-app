import 'dart:typed_data';

/// Stub para plataformas nativas: lá o próprio image_picker redimensiona
/// antes de entregar os bytes, então não há nada a fazer.
class ImageDownscaler {
  ImageDownscaler._();

  static Future<Uint8List> downscale(
    Uint8List bytes, {
    int maxDimension = 1600,
    double quality = 0.7,
  }) async =>
      bytes;
}
