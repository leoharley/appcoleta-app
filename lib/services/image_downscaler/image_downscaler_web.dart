import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Redimensiona a foto SEM decodificar a imagem inteira na memória.
///
/// POR QUE ISTO EXISTE
/// O maxWidth/maxHeight do image_picker não ajuda na web. O
/// image_picker_for_web redimensiona assim:
///
///   1. cria um HTMLImageElement com a foto em resolução PLENA
///      → o navegador decodifica os 12 MP inteiros (~48 MB de bitmap)
///   2. desenha num canvas menor
///   3. exporta o JPEG reduzido
///
/// O pico acontece no passo 1, ANTES de qualquer redução. Em celular fraco
/// a aba morre aí — foi o que continuou travando mesmo depois de limitarmos
/// maxWidth.
///
/// createImageBitmap com resizeWidth/resizeHeight decodifica JÁ no tamanho
/// final: o bitmap gigante nunca chega a existir. O trabalho ainda roda na
/// thread do navegador, mas o consumo de memória cai de dezenas de MB para
/// poucos MB.
class ImageDownscaler {
  ImageDownscaler._();

  /// Reduz [bytes] para caber em [maxDimension] (lado maior), devolvendo
  /// JPEG com a [quality] informada (0..1).
  ///
  /// Em qualquer falha devolve os bytes originais: é preferível uma foto
  /// grande a perder a evidência de campo.
  static Future<Uint8List> downscale(
    Uint8List bytes, {
    int maxDimension = 1600,
    double quality = 0.7,
  }) async {
    web.Blob? origem;
    web.ImageBitmap? bitmap;

    try {
      origem = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'image/jpeg'),
      );

      // Primeiro decodifica só o cabeçalho para saber as dimensões. O
      // ImageBitmap criado aqui é descartado logo em seguida.
      final web.ImageBitmap medida =
          await web.window.createImageBitmap(origem).toDart;
      final int largura = medida.width;
      final int altura = medida.height;
      medida.close();

      final int maior = largura > altura ? largura : altura;
      if (maior <= maxDimension) {
        // Já está pequena: não recomprime à toa.
        return bytes;
      }

      final double fator = maxDimension / maior;
      final int novaLargura = (largura * fator).round();
      final int novaAltura = (altura * fator).round();

      // AQUI está o ganho: o navegador decodifica direto no tamanho final.
      bitmap = await web.window
          .createImageBitmap(
            origem,
            web.ImageBitmapOptions(
              resizeWidth: novaLargura,
              resizeHeight: novaAltura,
              resizeQuality: 'medium',
            ),
          )
          .toDart;

      final canvas = web.OffscreenCanvas(novaLargura, novaAltura);
      final ctx = canvas.getContext('2d') as web.OffscreenCanvasRenderingContext2D;
      ctx.drawImage(bitmap, 0, 0);
      bitmap.close();
      bitmap = null;

      final web.Blob saida = await canvas
          .convertToBlob(
            web.ImageEncodeOptions(type: 'image/jpeg', quality: quality),
          )
          .toDart;

      final buffer = await saida.arrayBuffer().toDart;
      final reduzido = buffer.toDart.asUint8List();

      print('📉 Foto reduzida: ${largura}x$altura (${bytes.length ~/ 1024} KB) '
          '→ ${novaLargura}x$novaAltura (${reduzido.length ~/ 1024} KB)');

      return reduzido;
    } catch (e) {
      print('⚠️ Falha ao reduzir a foto, usando original: $e');
      return bytes;
    } finally {
      bitmap?.close();
    }
  }
}
