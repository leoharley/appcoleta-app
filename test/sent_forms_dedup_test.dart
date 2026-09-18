import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appcoleta/models/form_response.dart';
import 'package:appcoleta/services/local_storage_service.dart';

/// Deduplicação das coletas enviadas.
///
/// O aparelho pode guardar mais de uma cópia local da mesma coleta (reenvios
/// feitos antes da idempotência por client_id). Todas apontam para o mesmo
/// registro do painel, então a contagem da tela não batia com a do painel —
/// 421 linhas no app para bem menos registros lá.
void main() {
  FormResponse build({
    required int id,
    int? serverId,
    String? clientId,
    String syncStatus = 'synced',
  }) {
    return FormResponse(
      id: id,
      questionnaireId: 6,
      appliedBy: 17,
      consentGiven: true,
      clientId: clientId,
      serverId: serverId,
      syncStatus: syncStatus,
      syncedAt: DateTime(2026, 9, 17, 15, 2),
      startedAt: DateTime(2026, 9, 17, 14),
      completedAt: DateTime(2026, 9, 17, 15),
      responses: const [],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('contagem de enviadas (sem repetição)', () {
    test('duas cópias do mesmo registro contam como uma', () async {
      // Exatamente o caso do relato: #4309 aparecendo duas vezes.
      await LocalStorageService.saveFormResponse(build(id: 1, serverId: 4309));
      await LocalStorageService.saveFormResponse(build(id: 2, serverId: 4309));

      final counts = await LocalStorageService.getFormCountsByStatus();

      expect(counts['synced'], 1);
    });

    test('registros diferentes continuam contando separado', () async {
      await LocalStorageService.saveFormResponse(build(id: 1, serverId: 4309));
      await LocalStorageService.saveFormResponse(build(id: 2, serverId: 4308));
      await LocalStorageService.saveFormResponse(build(id: 3, serverId: 4307));

      final counts = await LocalStorageService.getFormCountsByStatus();

      expect(counts['synced'], 3);
    });

    test('pares repetidos: 6 cópias locais = 3 registros', () async {
      for (final par in [4309, 4308, 4307]) {
        await LocalStorageService.saveFormResponse(
            build(id: par * 10, serverId: par));
        await LocalStorageService.saveFormResponse(
            build(id: par * 10 + 1, serverId: par));
      }

      final counts = await LocalStorageService.getFormCountsByStatus();

      expect(counts['synced'], 3);
    });

    test('sem server_id, agrupa por client_id', () async {
      await LocalStorageService.saveFormResponse(
          build(id: 1, clientId: 'abc-123'));
      await LocalStorageService.saveFormResponse(
          build(id: 2, clientId: 'abc-123'));

      final counts = await LocalStorageService.getFormCountsByStatus();

      expect(counts['synced'], 1);
    });

    test('sem server_id nem client_id, cada uma conta (não dá para provar '
        'que são a mesma)', () async {
      await LocalStorageService.saveFormResponse(build(id: 1));
      await LocalStorageService.saveFormResponse(build(id: 2));

      final counts = await LocalStorageService.getFormCountsByStatus();

      expect(counts['synced'], 2);
    });

    test('pendentes não são afetadas pela deduplicação', () async {
      await LocalStorageService.saveFormResponse(
          build(id: 1, syncStatus: 'pending'));
      await LocalStorageService.saveFormResponse(
          build(id: 2, syncStatus: 'pending'));
      await LocalStorageService.saveFormResponse(build(id: 3, serverId: 4309));
      await LocalStorageService.saveFormResponse(build(id: 4, serverId: 4309));

      final counts = await LocalStorageService.getFormCountsByStatus();

      expect(counts['pending'], 2);
      expect(counts['synced'], 1);
    });
  });

  group('nada é apagado do aparelho', () {
    test('as cópias continuam no storage, só não são exibidas', () async {
      await LocalStorageService.saveFormResponse(build(id: 1, serverId: 4309));
      await LocalStorageService.saveFormResponse(build(id: 2, serverId: 4309));

      // A deduplicação é de exibição/contagem, não de dados: nenhuma
      // resposta de campo pode ser destruída.
      final todas = await LocalStorageService.getFormResponses();
      expect(todas, hasLength(2));
    });
  });
}
