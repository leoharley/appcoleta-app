// Helpers de parsing tolerantes a null e a números enviados como string,
// no mesmo padrão de Questionnaire._parseInt/_parseBool. O backend pode
// retornar null em campos numéricos (ex.: contadores ainda sem respostas),
// e casts estritos (as int) quebravam o carregamento da estratificação.
int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    if (value.isEmpty || value == 'null') return 0;
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    if (value.isEmpty || value == 'null') return 0.0;
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

/// Versões que PRESERVAM o null. Os campos "my_*" (progresso do próprio
/// aplicador) vêm null sempre que a chamada não envia applied_by, e null ali
/// significa "não solicitado", não "zero". Converter para 0 mostraria um
/// recorte individual que o servidor não calculou.
int? _parseIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is String && (value.isEmpty || value == 'null')) return null;
  return _parseInt(value);
}

double? _parseDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is String && (value.isEmpty || value == 'null')) return null;
  return _parseDouble(value);
}

bool _parseBool(dynamic value, {bool ifNull = false}) {
  if (value == null) return ifNull;
  if (value is bool) return value;
  if (value is String) {
    return value.toLowerCase() == 't' ||
        value.toLowerCase() == 'true' ||
        value == '1';
  }
  if (value is int) return value == 1;
  return ifNull;
}

class Stratum {
  final int stratumId;
  final String optionValue;
  final String optionLabel;
  final int targetQuota;
  final int currentCount;
  final double percentage;
  final bool quotaReached;

  /// Recorte do próprio aplicador. Null quando a API é chamada sem
  /// applied_by — ausência de recorte, não zero.
  final int? myCurrentCount;
  final int? myTargetQuota;
  final double? myPercentage;

  const Stratum({
    required this.stratumId,
    required this.optionValue,
    required this.optionLabel,
    required this.targetQuota,
    required this.currentCount,
    required this.percentage,
    required this.quotaReached,
    this.myCurrentCount,
    this.myTargetQuota,
    this.myPercentage,
  });

  factory Stratum.fromJson(Map<String, dynamic> json) {
    return Stratum(
      stratumId: _parseInt(json['stratum_id']),
      optionValue: json['option_value']?.toString() ?? '',
      optionLabel: json['option_label']?.toString() ?? '',
      targetQuota: _parseInt(json['target_quota']),
      currentCount: _parseInt(json['current_count']),
      percentage: _parseDouble(json['percentage']),
      quotaReached: _parseBool(json['quota_reached']),
      myCurrentCount: _parseIntOrNull(json['my_current_count']),
      myTargetQuota: _parseIntOrNull(json['my_target_quota']),
      myPercentage: _parseDoubleOrNull(json['my_percentage']),
    );
  }

  /// Serializa com as MESMAS chaves que [fromJson] lê, para o cache local
  /// voltar pelo mesmo caminho de parsing do servidor.
  Map<String, dynamic> toJson() => {
        'stratum_id': stratumId,
        'option_value': optionValue,
        'option_label': optionLabel,
        'target_quota': targetQuota,
        'current_count': currentCount,
        'percentage': percentage,
        'quota_reached': quotaReached,
        'my_current_count': myCurrentCount,
        'my_target_quota': myTargetQuota,
        'my_percentage': myPercentage,
      };

  int get remaining => targetQuota - currentCount;
}

class StratificationCategory {
  final int categoryId;
  final String categoryName;

  /// "question", "applicator" ou "weekday". Só em "question" existe uma
  /// pergunta por trás da categoria.
  final String dimensionType;

  /// Sempre int, nunca null. Vale 0 quando [dimensionType] não é "question"
  /// (aplicador/dia da semana não têm pergunta associada); nesse caso NÃO
  /// existe pergunta de id 0 para buscar — use [hasQuestion] antes.
  final int questionId;
  final int totalTarget;
  final int totalCurrent;
  final double percentage;

  /// Recorte do próprio aplicador; null quando a API é chamada sem applied_by.
  final int? myTotalCurrent;
  final double? myPercentage;

  final List<Stratum> strata;

  const StratificationCategory({
    required this.categoryId,
    required this.categoryName,
    this.dimensionType = 'question',
    required this.questionId,
    required this.totalTarget,
    required this.totalCurrent,
    required this.percentage,
    this.myTotalCurrent,
    this.myPercentage,
    required this.strata,
  });

  /// True somente quando a categoria vem de uma pergunta do questionário.
  bool get hasQuestion => dimensionType == 'question' && questionId > 0;

  factory StratificationCategory.fromJson(Map<String, dynamic> json) {
    return StratificationCategory(
      categoryId: _parseInt(json['category_id']),
      categoryName: json['category_name']?.toString() ?? '',
      dimensionType: json['dimension_type']?.toString() ?? 'question',
      questionId: _parseInt(json['question_id']),
      totalTarget: _parseInt(json['total_target']),
      totalCurrent: _parseInt(json['total_current']),
      percentage: _parseDouble(json['percentage']),
      myTotalCurrent: _parseIntOrNull(json['my_total_current']),
      myPercentage: _parseDoubleOrNull(json['my_percentage']),
      strata: (json['strata'] as List? ?? [])
          .map((s) => Stratum.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'category_name': categoryName,
        'dimension_type': dimensionType,
        'question_id': questionId,
        'total_target': totalTarget,
        'total_current': totalCurrent,
        'percentage': percentage,
        'my_total_current': myTotalCurrent,
        'my_percentage': myPercentage,
        'strata': strata.map((s) => s.toJson()).toList(),
      };
}

class OverallProgress {
  final int totalTarget;
  final int totalCurrent;
  final double percentage;

  const OverallProgress({
    required this.totalTarget,
    required this.totalCurrent,
    required this.percentage,
  });

  factory OverallProgress.fromJson(Map<String, dynamic> json) {
    return OverallProgress(
      totalTarget: _parseInt(json['total_target']),
      totalCurrent: _parseInt(json['total_current']),
      percentage: _parseDouble(json['percentage']),
    );
  }

  Map<String, dynamic> toJson() => {
        'total_target': totalTarget,
        'total_current': totalCurrent,
        'percentage': percentage,
      };
}

class StratificationData {
  final int questionnaireId;
  final int stratificationId;
  final String title;
  final bool isActive;
  final OverallProgress overallProgress;

  /// Progresso do próprio aplicador; null quando a API é chamada sem
  /// applied_by (é o caso hoje, o app não envia esse filtro).
  final OverallProgress? myOverallProgress;

  final List<StratificationCategory> categories;

  const StratificationData({
    required this.questionnaireId,
    required this.stratificationId,
    required this.title,
    required this.isActive,
    required this.overallProgress,
    this.myOverallProgress,
    required this.categories,
  });

  /// Lê UMA estratificação. Recebe o objeto de dentro de
  /// data["stratifications"][i] — não o envelope. Para o envelope completo
  /// use [StratificationData.listFromEnvelope].
  factory StratificationData.fromJson(Map<String, dynamic> json) {
    return StratificationData(
      questionnaireId: _parseInt(json['questionnaire_id']),
      stratificationId: _parseInt(json['stratification_id']),
      title: json['title']?.toString() ?? '',
      // Se o servidor retornou os dados da estratificação, ela é considerada
      // ativa a menos que ele diga explicitamente o contrário. Um is_active
      // ausente/nulo NÃO pode esconder o painel (hasStratification depende
      // deste campo). Aceita também a variação de nome "active".
      isActive: _parseBool(json['is_active'] ?? json['active'], ifNull: true),
      overallProgress: OverallProgress.fromJson(
          Map<String, dynamic>.from(json['overall_progress'] as Map? ?? {})),
      myOverallProgress: json['my_overall_progress'] == null
          ? null
          : OverallProgress.fromJson(
              Map<String, dynamic>.from(json['my_overall_progress'] as Map)),
      categories: (json['categories'] as List? ?? [])
          .map((c) => StratificationCategory.fromJson(
              Map<String, dynamic>.from(c as Map)))
          .toList(),
    );
  }

  /// Desce o envelope do endpoint GET /api/stratification/{questionnaire_id}.
  ///
  /// Recebe o conteúdo de response["data"] e devolve a LISTA em
  /// data["stratifications"] — um questionário pode ter mais de uma
  /// estratificação, e lista vazia significa "nenhuma configurada".
  ///
  /// Ler os campos direto da raiz de "data" (sem descer este nível) não
  /// lança erro: todos os campos viriam ausentes e os helpers tolerantes a
  /// null produziriam metas 0 e 0 categorias — a tela zerava em silêncio.
  static List<StratificationData> listFromEnvelope(Map<String, dynamic> data) {
    final raw = data['stratifications'];

    // Tolerante ao formato: lista (contrato atual) ou objeto único, caso o
    // backend volte a enviar uma estratificação solta.
    final List items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      items = [raw];
    } else {
      items = const [];
    }

    final questionnaireId = _parseInt(data['questionnaire_id']);

    return items
        .whereType<Map>()
        .map((s) {
          final json = Map<String, dynamic>.from(s);
          // questionnaire_id vive no envelope, não em cada estratificação.
          json.putIfAbsent('questionnaire_id', () => questionnaireId);
          return StratificationData.fromJson(json);
        })
        .toList();
  }

  Map<String, dynamic> toJson() => {
        'questionnaire_id': questionnaireId,
        'stratification_id': stratificationId,
        'title': title,
        'is_active': isActive,
        'overall_progress': overallProgress.toJson(),
        'my_overall_progress': myOverallProgress?.toJson(),
        'categories': categories.map((c) => c.toJson()).toList(),
      };

  /// Retorna informações de alerta se a opção selecionada tem cota atingida.
  /// Retorna null se não encontrada ou cota não atingida.
  Map<String, dynamic>? getQuotaAlert(int questionId, String optionValue) {
    for (final category in categories) {
      // Categorias de aplicador/dia da semana têm question_id 0 e não
      // correspondem a nenhuma pergunta: nunca podem casar aqui.
      if (category.hasQuestion && category.questionId == questionId) {
        for (final stratum in category.strata) {
          if (stratum.optionValue == optionValue && stratum.quotaReached) {
            return {
              'categoryName': category.categoryName,
              'optionLabel': stratum.optionLabel,
              'currentCount': stratum.currentCount,
              'targetQuota': stratum.targetQuota,
            };
          }
        }
      }
    }
    return null;
  }
}
