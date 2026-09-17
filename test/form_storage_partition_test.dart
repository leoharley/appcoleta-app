import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appcoleta/models/form_response.dart';
import 'package:appcoleta/services/local_storage_service.dart';

/// Separação entre coletas pendentes e já enviadas.
///
/// As enviadas continuam salvas no aparelho como comprovante, mas não podem
/// pesar a tela principal: ela carrega só as pendentes e usa contagem para
/// o resto.
void main() {
  FormResponse build({
    required int id,
    required String syncStatus,
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

  Future<void> seed() async {
    await LocalStorageService.saveFormResponse(
        build(id: 1, syncStatus: 'pending'));
    await LocalStorageService.saveFormResponse(
        build(id: 2, syncStatus: 'synced', serverId: 500));
    await LocalStorageService.saveFormResponse(
        build(id: 3, syncStatus: 'synced', serverId: 501));
    await LocalStorageService.saveFormResponse(
        build(id: 4, syncStatus: 'error'));
    await LocalStorageService.saveFormResponse(
        build(id: 5, syncStatus: 'offline'));
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('getFormResponsesByStatus', () {
    test('traz apenas as pendentes, sem as enviadas', () async {
      await seed();

      final pendentes =
          await LocalStorageService.getFormResponsesByStatus('pending');

      expect(pendentes, hasLength(1));
      expect(pendentes.single.id, 1);
    });

    test('traz apenas as enviadas', () async {
      await seed();

      final enviadas =
          await LocalStorageService.getFormResponsesByStatus('synced');

      expect(enviadas.map((f) => f.id).toList()..sort(), [2, 3]);
      expect(enviadas.every((f) => f.serverId != null), isTrue);
    });

    test('status inexistente devolve lista vazia', () async {
      await seed();
      expect(await LocalStorageService.getFormResponsesByStatus('nada'),
          isEmpty);
    });

    test('storage vazio não quebra', () async {
      expect(await LocalStorageService.getFormResponsesByStatus('pending'),
          isEmpty);
    });

    test('um registro corrompido não derruba os demais', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'form_responses',
        '[{"sync_status":"pending","id":"quebrado"},'
            '{"id":2,"questionnaire_id":6,"applied_by":17,'
            '"consent_given":true,"sync_status":"pending",'
            '"started_at":"2026-09-16T10:00:00.000","responses":[]}]',
      );

      final pendentes =
          await LocalStorageService.getFormResponsesByStatus('pending');

      expect(pendentes, hasLength(1));
      expect(pendentes.single.id, 2);
    });
  });

  group('getFormCountsByStatus', () {
    test('conta por status sem instanciar as coletas', () async {
      await seed();

      final counts = await LocalStorageService.getFormCountsByStatus();

      expect(counts['pending'], 1);
      expect(counts['synced'], 2);
      expect(counts['error'], 1);
      expect(counts['offline'], 1);
    });

    test('storage vazio devolve zeros', () async {
      final counts = await LocalStorageService.getFormCountsByStatus();

      expect(counts['pending'], 0);
      expect(counts['synced'], 0);
    });
  });

  group('as enviadas permanecem no aparelho', () {
    test('nada é apagado ao separar por status', () async {
      await seed();

      final todas = await LocalStorageService.getFormResponses();

      // Requisito: a coleta confirmada continua salva como comprovante.
      expect(todas, hasLength(5));
      expect(todas.firstWhere((f) => f.id == 2).serverId, 500);
    });
  });
}
