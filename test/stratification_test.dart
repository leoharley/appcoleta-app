import 'dart:convert';

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

  // O cache offline grava com toJson e relê com fromJson. Se as chaves
  // divergirem, a estratificação volta zerada em campo — sem erro visível,
  // que é o pior tipo de falha aqui.
  group('toJson (cache offline)', () {
    final original = StratificationData.fromJson({
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
              'current_count': 30,
              'percentage': 100.0,
              'quota_reached': true,
            },
            {
              'stratum_id': 8,
              'option_value': '25-34',
              'option_label': '25-34 anos',
              'target_quota': 40,
              'current_count': 15,
              'percentage': 37.5,
              'quota_reached': false,
            },
          ],
        },
      ],
    });

    test('round-trip preserva todos os campos', () {
      final restaurado = StratificationData.fromJson(original.toJson());

      expect(restaurado.questionnaireId, original.questionnaireId);
      expect(restaurado.stratificationId, original.stratificationId);
      expect(restaurado.title, original.title);
      expect(restaurado.isActive, original.isActive);
      expect(restaurado.overallProgress.totalTarget,
          original.overallProgress.totalTarget);
      expect(restaurado.overallProgress.totalCurrent,
          original.overallProgress.totalCurrent);
      expect(restaurado.overallProgress.percentage,
          original.overallProgress.percentage);
      expect(restaurado.categories.length, original.categories.length);

      final cat = restaurado.categories.first;
      final catOriginal = original.categories.first;
      expect(cat.categoryId, catOriginal.categoryId);
      expect(cat.categoryName, catOriginal.categoryName);
      expect(cat.questionId, catOriginal.questionId);
      expect(cat.totalTarget, catOriginal.totalTarget);
      expect(cat.totalCurrent, catOriginal.totalCurrent);
      expect(cat.percentage, catOriginal.percentage);
      expect(cat.strata.length, catOriginal.strata.length);

      final stratum = cat.strata.first;
      final stratumOriginal = catOriginal.strata.first;
      expect(stratum.stratumId, stratumOriginal.stratumId);
      expect(stratum.optionValue, stratumOriginal.optionValue);
      expect(stratum.optionLabel, stratumOriginal.optionLabel);
      expect(stratum.targetQuota, stratumOriginal.targetQuota);
      expect(stratum.currentCount, stratumOriginal.currentCount);
      expect(stratum.percentage, stratumOriginal.percentage);
      expect(stratum.quotaReached, stratumOriginal.quotaReached);
    });

    test('sobrevive à serialização JSON real do SharedPreferences', () {
      // jsonEncode/jsonDecode é o que acontece de fato no cache — um tipo não
      // serializável passaria no teste acima e explodiria só em campo.
      final restaurado = StratificationData.fromJson(
        Map<String, dynamic>.from(
            jsonDecode(jsonEncode(original.toJson())) as Map),
      );

      expect(restaurado.title, 'Pesquisa Municipal');
      expect(restaurado.isActive, isTrue);
      expect(restaurado.categories.first.strata.length, 2);
    });

    test('alerta de cota continua funcionando após o round-trip', () {
      final restaurado = StratificationData.fromJson(original.toJson());
      final alerta = restaurado.getQuotaAlert(55, '18-24');

      expect(alerta, isNotNull);
      expect(alerta!['optionLabel'], '18-24 anos');
      expect(alerta['currentCount'], 30);
      expect(alerta['targetQuota'], 30);
    });
  });

  // ===========================================================================
  // Envelope do endpoint GET /api/stratification/{questionnaire_id}
  //
  // Fixture: resposta real do questionário 6. A estratificação "teste" tem
  // id 20 e PERTENCE ao questionário 6 — chamar /stratification/20 devolve
  // 200 com "stratifications":[], e a tela zerava sem erro visível.
  // ===========================================================================
  group('listFromEnvelope (payload real do questionário 6)', () {
    const respostaCrua = r'''
{"success":true,"data":{"questionnaire_id":6,"applied_by_filter":null,
"stratifications":[{"stratification_id":20,"title":"teste","is_active":true,
"overall_progress":{"total_target":33,"total_current":36,
"percentage":109.09999999999994},
"my_overall_progress":null,
"categories":[
 {"category_id":132,"category_name":"Qual o seu sexo?",
  "dimension_type":"question","question_id":95,
  "total_target":25,"total_current":21,"percentage":84,
  "my_total_current":null,"my_percentage":null,
  "strata":[
   {"stratum_id":456,"option_value":"masculino","option_label":"Masculino",
    "target_quota":10,"current_count":12,"percentage":120,"quota_reached":true,
    "my_current_count":null,"my_target_quota":null,"my_percentage":null},
   {"stratum_id":457,"option_value":"feminino","option_label":"Feminino",
    "target_quota":15,"current_count":9,"percentage":60,"quota_reached":false,
    "my_current_count":null,"my_target_quota":null,"my_percentage":null}]},
 {"category_id":133,"category_name":"Por Aplicador",
  "dimension_type":"applicator","question_id":0,
  "total_target":8,"total_current":15,"percentage":187.5,
  "my_total_current":null,"my_percentage":null,
  "strata":[
   {"stratum_id":458,"option_value":"17","option_label":"Aplicador2 (aplicador)",
    "target_quota":8,"current_count":15,"percentage":187.5,"quota_reached":true,
    "my_current_count":null,"my_target_quota":null,"my_percentage":null}]}]}]}}
''';

    Map<String, dynamic> envelope() {
      final resposta = jsonDecode(respostaCrua) as Map<String, dynamic>;
      return Map<String, dynamic>.from(resposta['data'] as Map);
    }

    test('desce data.stratifications em vez de ler a raiz (tela zerada)', () {
      final lista = StratificationData.listFromEnvelope(envelope());

      expect(lista, hasLength(1));
      final data = lista.first;

      // Exatamente os números que apareciam zerados na tela.
      expect(data.overallProgress.totalTarget, 33);
      expect(data.overallProgress.totalCurrent, 36);
      expect(data.categories, hasLength(2));
      expect(data.title, 'teste');
      expect(data.stratificationId, 20);
      // questionnaire_id vem do envelope, não de dentro da estratificação.
      expect(data.questionnaireId, 6);
      expect(data.isActive, isTrue);
    });

    test('ler a raiz do envelope (sem descer) produz a tela zerada', () {
      // Documenta o modo de falha silencioso: nenhuma exceção, tudo zero.
      final errado = StratificationData.fromJson(envelope());

      expect(errado.overallProgress.totalTarget, 0);
      expect(errado.categories, isEmpty);
    });

    test('"stratifications" vazio devolve lista vazia, não erro', () {
      final envelopeVazio = Map<String, dynamic>.from(jsonDecode(
              '{"questionnaire_id":20,"applied_by_filter":null,"stratifications":[]}')
          as Map);

      expect(StratificationData.listFromEnvelope(envelopeVazio), isEmpty);
    });

    test('trata várias estratificações no mesmo questionário', () {
      final varias = {
        'questionnaire_id': 6,
        'stratifications': [
          {'stratification_id': 20, 'title': 'A', 'overall_progress': {}},
          {'stratification_id': 21, 'title': 'B', 'overall_progress': {}},
        ],
      };

      final lista = StratificationData.listFromEnvelope(varias);
      expect(lista, hasLength(2));
      expect(lista.map((s) => s.title), ['A', 'B']);
      expect(lista.every((s) => s.questionnaireId == 6), isTrue);
    });

    test('aceita objeto único no lugar da lista', () {
      final unico = {
        'questionnaire_id': 6,
        'stratifications': {'stratification_id': 20, 'title': 'solta'},
      };

      final lista = StratificationData.listFromEnvelope(unico);
      expect(lista, hasLength(1));
      expect(lista.first.title, 'solta');
    });

    test('chave "stratifications" ausente ou nula não quebra', () {
      expect(
          StratificationData.listFromEnvelope({'questionnaire_id': 6}), isEmpty);
      expect(
          StratificationData.listFromEnvelope(
              {'questionnaire_id': 6, 'stratifications': null}),
          isEmpty);
    });

    test('campos my_* nulos permanecem null (não viram 0)', () {
      final data = StratificationData.listFromEnvelope(envelope()).first;
      final categoria = data.categories.first;
      final estrato = categoria.strata.first;

      expect(data.myOverallProgress, isNull);
      expect(categoria.myTotalCurrent, isNull);
      expect(categoria.myPercentage, isNull);
      expect(estrato.myCurrentCount, isNull);
      expect(estrato.myTargetQuota, isNull);
      expect(estrato.myPercentage, isNull);
    });

    test('campos my_* preenchidos são lidos quando applied_by é enviado', () {
      final data = StratificationData.fromJson({
        'stratification_id': 20,
        'overall_progress': {'total_target': 33, 'total_current': 36},
        'my_overall_progress': {'total_target': 10, 'total_current': 4},
        'categories': [
          {
            'category_id': 1,
            'my_total_current': 4,
            'my_percentage': 40.0,
            'strata': [
              {
                'stratum_id': 1,
                'my_current_count': 4,
                'my_target_quota': 10,
                'my_percentage': 40.0,
              }
            ],
          }
        ],
      });

      expect(data.myOverallProgress!.totalCurrent, 4);
      expect(data.categories.first.myTotalCurrent, 4);
      expect(data.categories.first.myPercentage, 40.0);
      expect(data.categories.first.strata.first.myTargetQuota, 10);
    });

    test('percentage acima de 100 é preservado no modelo', () {
      final data = StratificationData.listFromEnvelope(envelope()).first;

      expect(data.overallProgress.percentage, closeTo(109.1, 0.001));
      expect(data.categories[1].percentage, 187.5);
      expect(data.categories.first.strata.first.percentage, 120);
    });

    test('question_id 0 em dimension_type applicator não vira pergunta', () {
      final data = StratificationData.listFromEnvelope(envelope()).first;
      final porAplicador = data.categories[1];

      expect(porAplicador.dimensionType, 'applicator');
      expect(porAplicador.questionId, 0);
      expect(porAplicador.hasQuestion, isFalse);

      final porPergunta = data.categories.first;
      expect(porPergunta.dimensionType, 'question');
      expect(porPergunta.hasQuestion, isTrue);

      // Buscar alerta pela "pergunta 0" não pode casar com a categoria de
      // aplicador, mesmo com a cota atingida (15/8).
      expect(data.getQuotaAlert(0, '17'), isNull);
    });

    test('alerta de cota funciona na categoria de pergunta real', () {
      final data = StratificationData.listFromEnvelope(envelope()).first;
      final alerta = data.getQuotaAlert(95, 'masculino');

      expect(alerta, isNotNull);
      expect(alerta!['optionLabel'], 'Masculino');
      expect(alerta['currentCount'], 12);
      expect(alerta['targetQuota'], 10);

      expect(data.getQuotaAlert(95, 'feminino'), isNull);
    });

    test('round-trip pelo cache preserva o payload real', () {
      final original = StratificationData.listFromEnvelope(envelope());

      // Mesmo formato de envelope que LocalStorageService grava.
      final cacheado = {
        'questionnaire_id': 6,
        'stratifications': original.map((s) => s.toJson()).toList(),
      };
      final restaurado = StratificationData.listFromEnvelope(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(cacheado)) as Map));

      expect(restaurado, hasLength(1));
      expect(restaurado.first.overallProgress.totalTarget, 33);
      expect(restaurado.first.categories, hasLength(2));
      expect(restaurado.first.categories[1].dimensionType, 'applicator');
      expect(
          restaurado.first.categories.first.strata.first.myPercentage, isNull);
      expect(restaurado.first.myOverallProgress, isNull);
    });
  });

  // ===========================================================================
  // Metas por aplicador: view_mode e quota_source
  //
  // O token no header decide a visão. Com token de aplicador o servidor
  // devolve view_mode "individual" e target_quota/current_count/percentage
  // JÁ SÃO os números dele — nada de somar ou comparar com outros.
  // ===========================================================================
  group('view_mode (visão individual x geral)', () {
    Map<String, dynamic> envelopeIndividual() => {
          'questionnaire_id': 6,
          'applied_by_filter': null,
          'view_mode': 'individual',
          'stratifications': [
            {
              'stratification_id': 20,
              'title': 'teste',
              'is_active': true,
              'overall_progress': {
                'total_target': 12,
                'total_current': 5,
                'percentage': 41.666666666666664,
              },
              'my_overall_progress': null,
              'categories': [
                {
                  'category_id': 132,
                  'category_name': 'Qual o seu sexo?',
                  'dimension_type': 'question',
                  'question_id': 95,
                  'total_target': 8,
                  'total_current': 5,
                  'percentage': 62.5,
                  'strata': [
                    {
                      'stratum_id': 456,
                      'option_value': 'masculino',
                      'option_label': 'Masculino',
                      'target_quota': 5,
                      'current_count': 5,
                      'percentage': 100,
                      'quota_reached': true,
                      'quota_source': 'individual',
                    },
                    {
                      'stratum_id': 457,
                      'option_value': 'feminino',
                      'option_label': 'Feminino',
                      'target_quota': 3,
                      'current_count': 0,
                      'percentage': 0,
                      'quota_reached': false,
                      'quota_source': 'individual',
                    },
                  ],
                },
                {
                  'category_id': 134,
                  'category_name': 'Dia da semana',
                  'dimension_type': 'weekday',
                  'question_id': 0,
                  'total_target': 4,
                  'total_current': 0,
                  'percentage': 0,
                  'strata': [
                    {
                      'stratum_id': 460,
                      'option_value': 'seg',
                      'option_label': 'Segunda',
                      'target_quota': 4,
                      'current_count': 0,
                      'percentage': 0,
                      'quota_reached': false,
                      // Sem cota individual: mostra a meta geral só como
                      // referência.
                      'quota_source': 'geral',
                    },
                  ],
                },
              ],
            }
          ],
        };

    test('view_mode do envelope chega em cada estratificação', () {
      final lista = StratificationData.listFromEnvelope(envelopeIndividual());

      expect(lista, hasLength(1));
      expect(lista.first.viewMode, 'individual');
      expect(lista.first.isIndividualView, isTrue);
    });

    test('sem view_mode no envelope o default é "geral"', () {
      final lista = StratificationData.listFromEnvelope({
        'questionnaire_id': 6,
        'stratifications': [
          {'stratification_id': 20, 'title': 'x', 'overall_progress': {}}
        ],
      });

      expect(lista.first.viewMode, 'geral');
      expect(lista.first.isIndividualView, isFalse);
    });

    test('view_mode "geral" do payload real do servidor', () {
      final lista = StratificationData.listFromEnvelope({
        'questionnaire_id': 6,
        'applied_by_filter': null,
        'view_mode': 'geral',
        'stratifications': [
          {'stratification_id': 20, 'title': 'teste', 'overall_progress': {}}
        ],
      });

      expect(lista.first.isIndividualView, isFalse);
    });

    test('em individual os números são usados direto, sem my_*', () {
      final data = StratificationData.listFromEnvelope(envelopeIndividual())
          .first;

      // my_overall_progress vem null e NÃO deve ser necessário: os campos
      // principais já são os do aplicador logado.
      expect(data.myOverallProgress, isNull);
      expect(data.overallProgress.totalTarget, 12);
      expect(data.overallProgress.totalCurrent, 5);

      final masculino = data.categories.first.strata.first;
      expect(masculino.targetQuota, 5);
      expect(masculino.currentCount, 5);
      expect(masculino.quotaReached, isTrue);
    });

    test('quota_source distingue cota individual de meta geral', () {
      final data = StratificationData.listFromEnvelope(envelopeIndividual())
          .first;

      final porPergunta = data.categories.first.strata.first;
      expect(porPergunta.quotaSource, 'individual');
      expect(porPergunta.isQuotaFromGeneral, isFalse);

      final diaDaSemana = data.categories[1].strata.first;
      expect(diaDaSemana.quotaSource, 'geral');
      expect(diaDaSemana.isQuotaFromGeneral, isTrue);
    });

    test('quota_source ausente (visão geral) não marca nada', () {
      final estrato = Stratum.fromJson({
        'stratum_id': 456,
        'option_value': 'masculino',
        'target_quota': 10,
        'current_count': 12,
      });

      expect(estrato.quotaSource, isNull);
      expect(estrato.isQuotaFromGeneral, isFalse);
    });

    test('weekday tem question_id 0 e não vira busca de pergunta', () {
      final data = StratificationData.listFromEnvelope(envelopeIndividual())
          .first;
      final diaDaSemana = data.categories[1];

      expect(diaDaSemana.dimensionType, 'weekday');
      expect(diaDaSemana.questionId, 0);
      expect(diaDaSemana.hasQuestion, isFalse);
      expect(data.getQuotaAlert(0, 'seg'), isNull);
    });

    test('round-trip do cache preserva view_mode e quota_source', () {
      final original =
          StratificationData.listFromEnvelope(envelopeIndividual());

      // Mesmo envelope que LocalStorageService grava, incluindo view_mode.
      final cacheado = {
        'questionnaire_id': 6,
        'view_mode': original.first.viewMode,
        'stratifications': original.map((s) => s.toJson()).toList(),
      };
      final restaurado = StratificationData.listFromEnvelope(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(cacheado)) as Map));

      expect(restaurado.first.viewMode, 'individual');
      expect(restaurado.first.isIndividualView, isTrue);
      expect(restaurado.first.categories.first.strata.first.quotaSource,
          'individual');
      expect(restaurado.first.categories[1].strata.first.isQuotaFromGeneral,
          isTrue);
    });

    test('percentage acima de 100 continua valendo na visão individual', () {
      final estrato = Stratum.fromJson({
        'stratum_id': 1,
        'target_quota': 4,
        'current_count': 9,
        'percentage': 225.0,
        'quota_reached': true,
        'quota_source': 'individual',
      });

      expect(estrato.percentage, 225.0);
      expect(estrato.quotaReached, isTrue);
    });
  });

  // ===========================================================================
  // Recorte por aplicador
  //
  // Rede de proteção para quando o perfil é aplicador mas o servidor devolve
  // view_mode "geral": sem isso o aplicador vê o progresso dos colegas na
  // dimensão "Por Aplicador". Baseado no payload real do questionário 6.
  // ===========================================================================
  group('restrictToApplicator', () {
    // Mesma forma do print reportado: categoria de pergunta + categoria
    // "Por Aplicador" com mais de um aplicador.
    StratificationData geralComDoisAplicadores() {
      return StratificationData.listFromEnvelope({
        'questionnaire_id': 6,
        'view_mode': 'geral',
        'stratifications': [
          {
            'stratification_id': 20,
            'title': 'teste',
            'is_active': true,
            'overall_progress': {
              'total_target': 33,
              'total_current': 30,
              'percentage': 90.9,
            },
            'categories': [
              {
                'category_id': 132,
                'category_name': 'Qual o seu sexo?',
                'dimension_type': 'question',
                'question_id': 95,
                'total_target': 25,
                'total_current': 15,
                'percentage': 60,
                'strata': [
                  {
                    'stratum_id': 456,
                    'option_value': 'masculino',
                    'option_label': 'Masculino',
                    'target_quota': 10,
                    'current_count': 10,
                    'percentage': 100,
                    'quota_reached': true,
                  },
                  {
                    'stratum_id': 457,
                    'option_value': 'feminino',
                    'option_label': 'Feminino',
                    'target_quota': 15,
                    'current_count': 5,
                    'percentage': 33.3,
                    'quota_reached': false,
                  },
                ],
              },
              {
                'category_id': 133,
                'category_name': 'Por Aplicador',
                'dimension_type': 'applicator',
                'question_id': 0,
                'total_target': 8,
                'total_current': 15,
                'percentage': 187.5,
                'strata': [
                  {
                    'stratum_id': 458,
                    'option_value': '17',
                    'option_label': 'Aplicador2 (aplicador)',
                    'target_quota': 8,
                    'current_count': 8,
                    'percentage': 100,
                    'quota_reached': true,
                  },
                  {
                    'stratum_id': 459,
                    'option_value': '18',
                    'option_label': 'Aplicador3 (aplicador)',
                    'target_quota': 6,
                    'current_count': 7,
                    'percentage': 116.7,
                    'quota_reached': true,
                  },
                ],
              },
            ],
          }
        ],
      }).first;
    }

    test('mantém apenas o estrato do próprio aplicador', () {
      final recortada = geralComDoisAplicadores().restrictToApplicator(17);
      final porAplicador = recortada.categories
          .firstWhere((c) => c.dimensionType == 'applicator');

      expect(porAplicador.strata, hasLength(1));
      expect(porAplicador.strata.first.optionValue, '17');
      // O colega não pode aparecer de forma alguma.
      expect(
        recortada.categories
            .expand((c) => c.strata)
            .map((s) => s.optionLabel)
            .join(' '),
        isNot(contains('Aplicador3')),
      );
    });

    test('recalcula o total da categoria sem os outros aplicadores', () {
      final recortada = geralComDoisAplicadores().restrictToApplicator(17);
      final porAplicador = recortada.categories
          .firstWhere((c) => c.dimensionType == 'applicator');

      // Antes: 15/8 somando os dois. Agora: só o 8/8 dele.
      expect(porAplicador.totalCurrent, 8);
      expect(porAplicador.totalTarget, 8);
      expect(porAplicador.percentage, 100);
    });

    test('recalcula o progresso geral a partir do que sobrou', () {
      final recortada = geralComDoisAplicadores().restrictToApplicator(17);

      // 25 (pergunta) + 8 (dele) = 33 de meta; 15 + 8 = 23 coletados.
      expect(recortada.overallProgress.totalTarget, 33);
      expect(recortada.overallProgress.totalCurrent, 23);
      expect(recortada.overallProgress.percentage, closeTo(69.7, 0.1));
    });

    test('categorias de pergunta são preservadas', () {
      final recortada = geralComDoisAplicadores().restrictToApplicator(17);
      final pergunta =
          recortada.categories.firstWhere((c) => c.dimensionType == 'question');

      expect(pergunta.strata, hasLength(2));
      expect(pergunta.totalTarget, 25);
    });

    test('aplicador sem estrato na categoria: categoria inteira sai', () {
      final recortada = geralComDoisAplicadores().restrictToApplicator(99);

      expect(recortada.categories.any((c) => c.dimensionType == 'applicator'),
          isFalse);
      // Sobra só a categoria de pergunta.
      expect(recortada.categories, hasLength(1));
      expect(recortada.overallProgress.totalTarget, 25);
    });

    test('marca restrictedLocally para a tela rotular como individual', () {
      final original = geralComDoisAplicadores();
      expect(original.isIndividualView, isFalse);

      final recortada = original.restrictToApplicator(17);
      expect(recortada.restrictedLocally, isTrue);
      expect(recortada.isIndividualView, isTrue);
    });

    test('em view_mode individual não altera nada', () {
      final individual = StratificationData.listFromEnvelope({
        'questionnaire_id': 6,
        'view_mode': 'individual',
        'stratifications': [
          {
            'stratification_id': 20,
            'overall_progress': {'total_target': 8, 'total_current': 5},
            'categories': [
              {
                'category_id': 133,
                'dimension_type': 'applicator',
                'question_id': 0,
                'total_target': 8,
                'total_current': 5,
                'strata': [
                  {
                    'stratum_id': 458,
                    'option_value': '17',
                    'target_quota': 8,
                    'current_count': 5,
                  }
                ],
              }
            ],
          }
        ],
      }).first;

      final resultado = individual.restrictToApplicator(17);

      expect(identical(resultado, individual), isTrue);
      expect(resultado.overallProgress.totalCurrent, 5);
    });

    test('round-trip do cache preserva o recorte', () {
      final recortada = geralComDoisAplicadores().restrictToApplicator(17);

      final cacheado = {
        'questionnaire_id': 6,
        'view_mode': recortada.viewMode,
        'stratifications': [recortada.toJson()],
      };
      final restaurada = StratificationData.listFromEnvelope(
              Map<String, dynamic>.from(jsonDecode(jsonEncode(cacheado)) as Map))
          .first;

      expect(restaurada.restrictedLocally, isTrue);
      expect(restaurada.isIndividualView, isTrue);
      final porAplicador = restaurada.categories
          .firstWhere((c) => c.dimensionType == 'applicator');
      expect(porAplicador.strata, hasLength(1));
      expect(porAplicador.strata.first.optionValue, '17');
    });
  });
}
