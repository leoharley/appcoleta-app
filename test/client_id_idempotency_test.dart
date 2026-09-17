import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:appcoleta/models/form_response.dart';
import 'package:appcoleta/services/local_storage_service.dart';

/// client_id: chave de idempotência do backend (coluna UNIQUE).
///
/// O app não enviava esse campo, então a deduplicação do servidor nunca
/// ativava e um reenvio após resposta perdida duplicava ou falhava.
void main() {
  FormResponse build({int id = 1, String? clientId}) {
    return FormResponse(
      id: id,
      questionnaireId: 6,
      appliedBy: 17,
      consentGiven: true,
      clientId: clientId,
      startedAt: DateTime(2026, 9, 16, 10),
      completedAt: DateTime(2026, 9, 16, 10, 30),
      responses: const [],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('client_id no corpo do submit', () {
    test('vai no JSON enviado ao servidor', () {
      final uuid = const Uuid().v4();
      final json = build(clientId: uuid).toJson();

      expect(json['client_id'], uuid);
    });

    test('é omitido quando ausente (coletas antigas)', () {
      expect(build().toJson().containsKey('client_id'), isFalse);
    });

    test('formato UUID v4 válido', () {
      final uuid = const Uuid().v4();

      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
                r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(uuid),
        isTrue,
        reason: 'client_id deve ser UUID v4: $uuid',
      );
    });
  });

  group('estabilidade entre tentativas', () {
    test('o MESMO client_id é reenviado após reiniciar o app', () async {
      final uuid = const Uuid().v4();
      await LocalStorageService.saveFormResponse(build(clientId: uuid));

      // Simula reabrir o app: relê do storage.
      final recarregada =
          (await LocalStorageService.getFormResponses()).single;

      expect(recarregada.clientId, uuid);
      expect(recarregada.toJson()['client_id'], uuid);
    });

    test('sobrevive ao round-trip de serialização', () {
      final uuid = const Uuid().v4();
      final restaurada =
          FormResponse.fromJson(jsonDecode(jsonEncode(build(clientId: uuid)
              .toJson())) as Map<String, dynamic>);

      expect(restaurada.clientId, uuid);
    });

    test('marcar como sincronizado não perde o client_id', () async {
      final uuid = const Uuid().v4();
      await LocalStorageService.saveFormResponse(build(clientId: uuid));

      await LocalStorageService.updateFormSyncStatus(1, 'synced',
          serverId: 900, syncedAt: DateTime(2026, 9, 16));

      final form = (await LocalStorageService.getFormResponses()).single;
      expect(form.clientId, uuid);
      expect(form.serverId, 900);
    });

    test('client_ids de coletas diferentes não colidem', () {
      final ids = List.generate(200, (_) => const Uuid().v4()).toSet();
      expect(ids, hasLength(200));
    });
  });

  group('resposta do servidor', () {
    test('lê form_response_id na raiz (formato atual do backend)', () {
      expect(
        FormResponse.extractServerId(
            {'success': true, 'form_response_id': 777}),
        777,
      );
    });

    test('lê id na raiz', () {
      expect(FormResponse.extractServerId({'success': true, 'id': 778}), 778);
    });

    test('lê data.id', () {
      expect(
        FormResponse.extractServerId({
          'success': true,
          'data': {'id': 779}
        }),
        779,
      );
    });

    test('resposta de deduplicação traz o id do registro existente', () {
      // 200 + duplicated:true é SUCESSO: a coleta já está no painel.
      final resposta = {
        'success': true,
        'duplicated': true,
        'form_response_id': 500,
      };

      expect(FormResponse.extractServerId(resposta), 500);
      expect(resposta['duplicated'], isTrue);
    });
  });
}
