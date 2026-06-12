import 'package:flutter/foundation.dart';
import '../models/stratification.dart';
import '../services/api_service.dart';

class StratificationProvider extends ChangeNotifier {
  StratificationData? _stratification;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;
  int? _lastQuestionnaireId;

  static const _cacheDuration = Duration(minutes: 5);

  StratificationData? get stratification => _stratification;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Retorna true se existe estratificação ativa carregada.
  bool get hasStratification =>
      _stratification != null && _stratification!.isActive;

  /// Carrega estratificação do servidor para o questionário informado.
  /// Usa cache de 5 minutos a menos que [forceRefresh] seja true.
  /// Em caso de erro ou offline, silencia e segue sem estratificação.
  Future<void> loadStratification(int questionnaireId, {bool forceRefresh = false}) async {
    // Retorna cache se valido
    if (!forceRefresh &&
        _stratification != null &&
        _lastQuestionnaireId == questionnaireId &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('📊 Carregando estratificação para questionário $questionnaireId...');
      _stratification = await ApiService.getStratification(questionnaireId);
      _lastQuestionnaireId = questionnaireId;
      _lastFetchTime = DateTime.now();

      if (_stratification != null) {
        print('✅ Estratificação carregada: ${_stratification!.title}');
        print('   Categorias: ${_stratification!.categories.length}');
        print('   Ativa: ${_stratification!.isActive}');
      } else {
        print('ℹ️ Nenhuma estratificação configurada para este questionário');
      }
    } catch (e) {
      print('❌ Erro ao carregar estratificação: $e');
      _errorMessage = e.toString();
      _stratification = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _stratification = null;
    _errorMessage = null;
    _lastFetchTime = null;
    _lastQuestionnaireId = null;
    notifyListeners();
  }
}
