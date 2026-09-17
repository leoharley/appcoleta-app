import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appcoleta/models/questionnaire.dart';
import 'package:appcoleta/services/local_storage_service.dart';

/// Cobre a reconciliação do cache de questionários.
///
/// Bug de origem: um questionário desativado no painel (id 21, "QUESTIONÁRIO
/// POÇOS DE CALDAS") continuava aparecendo no app com badge "Ativo" — status
/// que a API não devolve, porque o registro nem vem na resposta. O dado vinha
/// do cache local.
void main() {
  Questionnaire build(int id, String title, {String status = 'active'}) {
    return Questionnaire(
      id: id,
      title: title,
      description: '',
      createdBy: 1,
      status: status,
      requiresConsent: false,
      requiresLocation: false,
      requiresPhoto: false,
      estimatedTime: null,
      version: '1',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      questions: const [],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('saveQuestionnaires (reconciliação)', () {
    test('substitui o cache inteiro em vez de mesclar (UPSERT)', () async {
      // Estado anterior: o 21 estava disponível.
      await LocalStorageService.saveQuestionnaires([
        build(6, 'Pesquisa Municipal'),
        build(21, 'QUESTIONÁRIO POÇOS DE CALDAS'),
      ]);

      // Sincronização seguinte: o painel desativou o 21, e ele não vem mais.
      await LocalStorageService.saveQuestionnaires([
        build(6, 'Pesquisa Municipal'),
      ]);

      final cache = await LocalStorageService.getQuestionnaires();

      expect(cache, hasLength(1));
      expect(cache.single.id, 6);
      // O desativado não pode sobreviver no cache.
      expect(cache.any((q) => q.id == 21), isFalse);
    });

    test('lista vazia limpa o cache (usuário sem questionários ativos)',
        () async {
      await LocalStorageService.saveQuestionnaires([
        build(21, 'QUESTIONÁRIO POÇOS DE CALDAS'),
      ]);

      await LocalStorageService.saveQuestionnaires([]);

      expect(await LocalStorageService.getQuestionnaires(), isEmpty);
    });

    test('mantém os questionários que continuam vindo', () async {
      await LocalStorageService.saveQuestionnaires([
        build(6, 'Pesquisa Municipal'),
        build(21, 'QUESTIONÁRIO POÇOS DE CALDAS'),
      ]);
      await LocalStorageService.saveQuestionnaires([
        build(6, 'Pesquisa Municipal (v2)'),
        build(9, 'Outra Pesquisa'),
      ]);

      final cache = await LocalStorageService.getQuestionnaires();

      expect(cache.map((q) => q.id).toList()..sort(), [6, 9]);
      expect(cache.firstWhere((q) => q.id == 6).title,
          'Pesquisa Municipal (v2)');
    });

    test('cache vazio no primeiro uso não quebra', () async {
      expect(await LocalStorageService.getQuestionnaires(), isEmpty);
    });
  });

  group('fila de envio', () {
    test('respostas pendentes não são tocadas pela reconciliação', () async {
      // As respostas ficam em outra chave ('form_responses'), então gravar
      // questionários não pode afetá-las. Garante o item "não perder dados
      // de campo": a coleta do questionário removido continua na fila.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('form_responses', '[{"id":1,"questionnaire_id":21}]');

      await LocalStorageService.saveQuestionnaires([build(6, 'Outra')]);

      expect(prefs.getString('form_responses'),
          '[{"id":1,"questionnaire_id":21}]');
    });
  });
}
