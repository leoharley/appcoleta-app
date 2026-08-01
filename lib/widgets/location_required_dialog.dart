import 'package:flutter/material.dart';

import '../models/form_response.dart';

/// O que o aplicador decidiu quando a captura de GPS falhou na finalização.
enum LocationDialogAction {
  /// Tentar capturar as coordenadas de novo.
  retry,

  /// Concluir mesmo assim. O formulário vai para o painel marcado como
  /// "Sem localização" — o registro fica rastreável em vez de simplesmente
  /// chegar com as coordenadas em branco.
  finishWithout,

  /// Voltar ao questionário sem finalizar (respostas preservadas).
  cancel,
}

/// Diálogo exibido quando o questionário exige localização e a captura falhou.
///
/// Vive fora das telas porque os dois caminhos de finalização — com foto
/// ([PhotoCaptureScreen]) e sem foto ([QuestionScreen]) — precisam do mesmo
/// comportamento, e mantê-los sincronizados por cópia já se mostrou frágil.
Future<LocationDialogAction?> showLocationRequiredDialog(
  BuildContext context,
  String motivo,
) {
  return showDialog<LocationDialogAction>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.location_off, color: Color(0xFFE8962E)),
          SizedBox(width: 8),
          Expanded(child: Text('Localização obrigatória')),
        ],
      ),
      content: Text(
        '$motivo\n\n'
        'Se o sinal não vier de jeito nenhum, você pode concluir sem as '
        'coordenadas — o questionário será enviado ao painel marcado como '
        '"$kSemLocalizacao".',
        style: const TextStyle(fontSize: 14),
      ),
      // Três ações não cabem lado a lado em tela estreita; o OverflowBar do
      // AlertDialog empilha sozinho quando falta largura.
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, LocationDialogAction.cancel),
          child: const Text('Voltar ao questionário'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, LocationDialogAction.finishWithout),
          child: const Text(
            'Finalizar sem localização',
            style: TextStyle(color: Color(0xFF757575)),
          ),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(dialogContext, LocationDialogAction.retry),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE8962E),
            foregroundColor: Colors.white,
          ),
          child: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}
