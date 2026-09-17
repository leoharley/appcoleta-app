import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appcoleta/models/form_response.dart';
import 'package:appcoleta/services/local_storage_service.dart';

/// Cobre a confirmação de envio das coletas.
///
/// Bug de origem: respostas com foto/áudio sumiam do app após o botão
/// Sincronizar e não chegavam ao painel. O app dava a coleta como enviada
/// apenas com success=true, antes mesmo das mídias subirem.
void main() {
  FormResponse build({
    int id = 1,
    String syncStatus = 'pending',
    int? serverId,
  }) {
    return FormResponse(
      id: id,
      questionnaireId: 6,
      appliedBy: 17,
      consentGiven: true,
      syncStatus: syncStatus,
      serverId: serverId,
      startedAt: DateTime(2026, 9, 16, 10),
      completedAt: DateTime(2026, 9, 16, 10, 30),
      responses: const [],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('extractServerId (prova de gravação no painel)', () {
    test('lê o id na raiz da resposta', () {
      expect(FormResponse.extractServerId({'success': true, 'id': 42}), 42);
    });

    test('lê o id aninhado em data', () {
      expect(
        FormResponse.extractServerId({
          'success': true,
          'data': {'form_id': 99},
        }),
        99,
      );
    });

    test('aceita id como string (PHP costuma devolver assim)', () {
      expect(FormResponse.extractServerId({'id': '123'}), 123);
    });

    test('aceita os nomes alternativos de chave', () {
      expect(FormResponse.extractServerId({'response_id': 7}), 7);
      expect(FormResponse.extractServerId({'form_response_id': 8}), 8);
      expect(FormResponse.extractServerId({'inserted_id': 9}), 9);
    });

    test('200 sem identificador retorna null — não pode dar como enviado', () {
      expect(FormResponse.extractServerId({'success': true}), isNull);
      expect(
        FormResponse.extractServerId({'success': true, 'message': 'ok'}),
        isNull,
      );
    });

    test('id zero ou negativo não conta como gravação', () {
      expect(FormResponse.extractServerId({'id': 0}), isNull);
      expect(FormResponse.extractServerId({'id': -1}), isNull);
    });

    test('resposta que não é mapa não quebra', () {
      expect(FormResponse.extractServerId(null), isNull);
      expect(FormResponse.extractServerId('erro'), isNull);
      expect(FormResponse.extractServerId([1, 2]), isNull);
    });
  });

  group('updateFormSyncStatus (confirmação persistida)', () {
    test('grava serverId e syncedAt junto do status', () async {
      await LocalStorageService.saveFormResponse(build());

      final quando = DateTime(2026, 9, 16, 11);
      await LocalStorageService.updateFormSyncStatus(
        1,
        'synced',
        serverId: 555,
        syncedAt: quando,
      );

      final forms = await LocalStorageService.getFormResponses();
      final form = forms.firstWhere((f) => f.id == 1);

      expect(form.syncStatus, 'synced');
      expect(form.serverId, 555);
      expect(form.syncedAt, quando);
      expect(form.isConfirmedByServer, isTrue);
    });

    test('coleta pendente não é considerada confirmada', () {
      expect(build().isConfirmedByServer, isFalse);
      expect(build(syncStatus: 'error').isConfirmedByServer, isFalse);
    });

    test('a coleta continua no storage depois de confirmada (não some)',
        () async {
      await LocalStorageService.saveFormResponse(build());
      await LocalStorageService.updateFormSyncStatus(1, 'synced',
          serverId: 555, syncedAt: DateTime(2026, 9, 16));

      final forms = await LocalStorageService.getFormResponses();

      // O requisito: nunca apagar do aparelho, só marcar como enviada.
      expect(forms, hasLength(1));
      expect(forms.single.serverId, 555);
    });
  });

  group('round-trip do storage', () {
    test('serverId e syncedAt sobrevivem à serialização', () {
      final original = build(syncStatus: 'synced', serverId: 321)
          .copyWith(syncedAt: DateTime(2026, 9, 16, 12));

      final restaurado = FormResponse.fromJson(original.toJson());

      expect(restaurado.serverId, 321);
      expect(restaurado.syncedAt, DateTime(2026, 9, 16, 12));
      expect(restaurado.isConfirmedByServer, isTrue);
    });

    test('coleta antiga sem os campos novos continua legível', () {
      final antiga = {
        'id': 5,
        'questionnaire_id': 6,
        'applied_by': 17,
        'consent_given': true,
        'sync_status': 'pending',
        'started_at': '2026-09-16T10:00:00.000',
        'responses': [],
      };

      final form = FormResponse.fromJson(antiga);

      expect(form.serverId, isNull);
      expect(form.syncedAt, isNull);
      expect(form.isConfirmedByServer, isFalse);
    });
  });
}
