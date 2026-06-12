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

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is String) {
    return value.toLowerCase() == 't' ||
        value.toLowerCase() == 'true' ||
        value == '1';
  }
  if (value is int) return value == 1;
  return false;
}

class Stratum {
  final int stratumId;
  final String optionValue;
  final String optionLabel;
  final int targetQuota;
  final int currentCount;
  final double percentage;
  final bool quotaReached;

  const Stratum({
    required this.stratumId,
    required this.optionValue,
    required this.optionLabel,
    required this.targetQuota,
    required this.currentCount,
    required this.percentage,
    required this.quotaReached,
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
    );
  }

  int get remaining => targetQuota - currentCount;
}

class StratificationCategory {
  final int categoryId;
  final String categoryName;
  final int questionId;
  final int totalTarget;
  final int totalCurrent;
  final double percentage;
  final List<Stratum> strata;

  const StratificationCategory({
    required this.categoryId,
    required this.categoryName,
    required this.questionId,
    required this.totalTarget,
    required this.totalCurrent,
    required this.percentage,
    required this.strata,
  });

  factory StratificationCategory.fromJson(Map<String, dynamic> json) {
    return StratificationCategory(
      categoryId: _parseInt(json['category_id']),
      categoryName: json['category_name']?.toString() ?? '',
      questionId: _parseInt(json['question_id']),
      totalTarget: _parseInt(json['total_target']),
      totalCurrent: _parseInt(json['total_current']),
      percentage: _parseDouble(json['percentage']),
      strata: (json['strata'] as List? ?? [])
          .map((s) => Stratum.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
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
}

class StratificationData {
  final int questionnaireId;
  final int stratificationId;
  final String title;
  final bool isActive;
  final OverallProgress overallProgress;
  final List<StratificationCategory> categories;

  const StratificationData({
    required this.questionnaireId,
    required this.stratificationId,
    required this.title,
    required this.isActive,
    required this.overallProgress,
    required this.categories,
  });

  factory StratificationData.fromJson(Map<String, dynamic> json) {
    return StratificationData(
      questionnaireId: _parseInt(json['questionnaire_id']),
      stratificationId: _parseInt(json['stratification_id']),
      title: json['title']?.toString() ?? '',
      isActive: _parseBool(json['is_active']),
      overallProgress: OverallProgress.fromJson(
          json['overall_progress'] as Map<String, dynamic>? ?? {}),
      categories: (json['categories'] as List? ?? [])
          .map((c) =>
              StratificationCategory.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Retorna informações de alerta se a opção selecionada tem cota atingida.
  /// Retorna null se não encontrada ou cota não atingida.
  Map<String, dynamic>? getQuotaAlert(int questionId, String optionValue) {
    for (final category in categories) {
      if (category.questionId == questionId) {
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
