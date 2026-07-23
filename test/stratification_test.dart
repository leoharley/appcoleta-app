import 'package:flutter_test/flutter_test.dart';
import 'package:appcoleta/models/stratification.dart';

void main() {
  group('StratificationData.fromJson', () {
    test('payload completo e típico do backend', () {
      final data = StratificationData.fromJson({
        'questionnaire_id': 10,
        'stratification_id': 3,
        'title': 'Pesquisa Municipal',
        'is_active': true,
        'overall_progress': {
          'total_target': 200,
          'total_current': 85,
          'percentage': 42.5,
        },
        'categories': [
          {
            'category_id': 1,
            'category_name': 'Faixa Etária',
            'question_id': 55,
            'total_target': 100,
            'total_current': 45,
            'percentage': 45.0,
            'strata': [
              {
                'stratum_id': 7,
                'option_value': '18-24',
                'option_label': '18-24 anos',
                'target_quota': 30,
                'current_count': 10,
                'percentage': 33.3,
                'quota_reached': false,
              },
              {
                'stratum_id': 8,
                'option_value': '35-44',
                'option_label': '35-44 anos',
                'target_quota': 20,
                'current_count': 20,
                'percentage': 100.0,
                'quota_reached': true,
              },
            ],
          },
        ],
      });

      expect(data.isActive, isTrue);
      expect(data.overallProgress.totalTarget, 200);
      expect(data.categories, hasLength(1));
      expect(data.categories.first.strata, hasLength(2));
      expect(data.categories.first.strata[1].quotaReached, isTrue);
    });

    test('campos numéricos nulos não quebram o parse (bug do type Null/int)',
        () {
      final data = StratificationData.fromJson({
        'questionnaire_id': 10,
        'stratification_id': null,
        'title': 'Pesquisa',
        'is_active': true,
        'overall_progress': {
          'total_target': null,
          'total_current': null,
          'percentage': null,
        },
        'categories': [
          {
            'category_id': 1,
            'category_name': 'Gênero',
            'question_id': null,
            'total_target': null,
            'total_current': null,
            'percentage': null,
            'strata': [
              {
                'stratum_id': null,
                'option_value': 'M',
                'option_label': 'Masculino',
                'target_quota': null,
                'current_count': null,
                'percentage': null,
                'quota_reached': null,
              },
            ],
          },
        ],
      });

      expect(data.isActive, isTrue);
      expect(data.overallProgress.totalTarget, 0);
      expect(data.categories.first.strata.first.currentCount, 0);
      expect(data.categories.first.strata.first.quotaReached, isFalse);
    });

    test(
        'is_active ausente NÃO esconde o painel (bug do painel invisível '
        'para o aplicador)', () {
      final data = StratificationData.fromJson({
        'questionnaire_id': 10,
        'stratification_id': 3,
        'title': 'Pesquisa',
        'overall_progress': {
          'total_target': 100,
          'total_current': 10,
          'percentage': 10.0,
        },
        'categories': [],
      });

      expect(data.isActive, isTrue,
          reason: 'sem is_active na resposta, o painel deve aparecer');
    });

    test('is_active nulo também é tratado como ativa', () {
      final data = StratificationData.fromJson({
        'questionnaire_id': 10,
        'stratification_id': 3,
        'title': 'Pesquisa',
        'is_active': null,
        'overall_progress': {},
        'categories': [],
      });

      expect(data.isActive, isTrue);
    });

    test('is_active false explícito continua escondendo o painel', () {
      final data = StratificationData.fromJson({
        'questionnaire_id': 10,
        'stratification_id': 3,
        'title': 'Pesquisa',
        'is_active': false,
        'overall_progress': {},
        'categories': [],
      });

      expect(data.isActive, isFalse);
    });

    test('variações de formato vindas do banco: "t", 1, "true" e chave "active"',
        () {
      for (final ativo in ['t', 1, 'true', true]) {
        final data = StratificationData.fromJson({
          'questionnaire_id': 10,
          'stratification_id': 3,
          'title': 'Pesquisa',
          'is_active': ativo,
          'overall_progress': {},
          'categories': [],
        });
        expect(data.isActive, isTrue, reason: 'is_active=$ativo deve ser ativa');
      }

      final comChaveActive = StratificationData.fromJson({
        'questionnaire_id': 10,
        'stratification_id': 3,
        'title': 'Pesquisa',
        'active': 'f',
        'overall_progress': {},
        'categories': [],
      });
      expect(comChaveActive.isActive, isFalse);
    });

    test('números como string (padrão comum em PostgreSQL/JSON) são aceitos',
        () {
      final data = StratificationData.fromJson({
        'questionnaire_id': '10',
        'stratification_id': '3',
        'title': 'Pesquisa',
        'is_active': 't',
        'overall_progress': {
          'total_target': '200',
          'total_current': '85',
          'percentage': '42.5',
        },
        'categories': [],
      });

      expect(data.questionnaireId, 10);
      expect(data.overallProgress.totalTarget, 200);
      expect(data.overallProgress.percentage, 42.5);
    });

    test('overall_progress e categories ausentes não quebram', () {
      final data = StratificationData.fromJson({
        'questionnaire_id': 10,
        'stratification_id': 3,
        'title': 'Pesquisa',
        'is_active': true,
      });

      expect(data.overallProgress.totalTarget, 0);
      expect(data.categories, isEmpty);
    });
  });

  group('getQuotaAlert (alerta durante o preenchimento)', () {
    StratificationData buildData({required bool quotaReached}) {
      return StratificationData.fromJson({
        'questionnaire_id': 10,
        'stratification_id': 3,
        'title': 'Pesquisa',
        'is_active': true,
        'overall_progress': {},
        'categories': [
          {
            'category_id': 1,
            'category_name': 'Faixa Etária',
            'question_id': 55,
            'total_target': 100,
            'total_current': 45,
            'percentage': 45.0,
            'strata': [
              {
                'stratum_id': 7,
                'option_value': '35-44 anos',
                'option_label': '35-44 anos',
                'target_quota': 20,
                'current_count': 20,
                'percentage': 100.0,
                'quota_reached': quotaReached,
              },
            ],
          },
        ],
      });
    }

    test('retorna alerta quando a cota da opção selecionada foi atingida', () {
      final alert = buildData(quotaReached: true).getQuotaAlert(55, '35-44 anos');
      expect(alert, isNotNull);
      expect(alert!['categoryName'], 'Faixa Etária');
      expect(alert['currentCount'], 20);
      expect(alert['targetQuota'], 20);
    });

    test('não retorna alerta quando a cota ainda não foi atingida', () {
      expect(buildData(quotaReached: false).getQuotaAlert(55, '35-44 anos'),
          isNull);
    });

    test('não retorna alerta para questão sem estratificação', () {
      expect(buildData(quotaReached: true).getQuotaAlert(99, '35-44 anos'),
          isNull);
    });
  });
}
