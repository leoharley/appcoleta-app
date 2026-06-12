// Script para gerar imagem de foreground com padding para icone adaptativo Android.
// O Android adaptive icon corta ~25% de cada lado, entao o logo precisa ficar
// centralizado na zona segura (centro 66% da imagem).
//
// Uso: dart run tool/generate_adaptive_foreground.dart

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final inputPath = 'assets/images/icone_alveslima.png';
  final outputPath = 'assets/images/icone_alveslima_foreground.png';

  print('Lendo $inputPath ...');
  final inputBytes = File(inputPath).readAsBytesSync();
  final original = img.decodePng(inputBytes);
  if (original == null) {
    print('Erro: nao foi possivel decodificar a imagem.');
    exit(1);
  }

  // Tamanho do canvas final (1024x1024 para qualidade maxima)
  const canvasSize = 1024;
  // O logo ocupa ~60% do canvas (zona segura com folga)
  final logoSize = (canvasSize * 0.55).toInt();

  // Redimensionar o logo
  final resized = img.copyResize(original, width: logoSize, height: logoSize, interpolation: img.Interpolation.average);

  // Criar canvas branco
  final canvas = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  // Preencher com transparente (o background ja eh branco via adaptive_icon_background)
  img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 0));

  // Centralizar o logo no canvas
  final offsetX = (canvasSize - logoSize) ~/ 2;
  final offsetY = (canvasSize - logoSize) ~/ 2;
  img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);

  // Salvar
  final outputBytes = img.encodePng(canvas);
  File(outputPath).writeAsBytesSync(outputBytes);
  print('Foreground gerado em $outputPath (${canvasSize}x$canvasSize, logo ${logoSize}x$logoSize)');
}
