import 'package:flutter/foundation.dart';
import '../models/stratification.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class StratificationProvider extends ChangeNotifier {
  StratificationData? _stratification;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;
  int? _lastQuestionnaireId;
  DateTime? _cachedAt;

  static const _cacheDuration = Duration(minutes: 5);

  StratificationData? get stratification => _stratification;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Quando os dados exibidos vieram do cache local (offline), traz a data do
  /// último download bem-sucedido. Null quando os dados são do servidor.
  DateTime? get cachedAt => _cachedAt;
  bool get isFromCache => _cachedAt != null;

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
      _cachedAt = null; // dados frescos do servidor

      if (_stratification != null) {
        print('✅ Estratificação carregada: ${_stratification!.title}');
        print('   Categorias: ${_stratification!.categories.length}');
        print('   Ativa: ${_stratification!.isActive}');
        // Guardar para uso offline nas próximas aberturas.
        await LocalStorageService.saveStratification(
            questionnaireId, _stratification!);
      } else {
        print('ℹ️ Nenhuma estratificação configurada para este questionário');
      }
    } catch (e) {
      // Offline ou servidor inacessível: usar a última versão baixada em vez
      // de esconder o painel e mostrar um erro de rede ao aplicador.
      print('❌ Erro ao carregar estratificação: $e');
      final cached = await LocalStorageService.getStratification(questionnaireId);

      if (cached != null) {
        _stratification = cached.data;
        _cachedAt = cached.cachedAt;
        _lastQuestionnaireId = questionnaireId;
        _lastFetchTime = null; // não vale como cache de 5 min; retentar depois
        _errorMessage = null;
        print('✅ Estratificação exibida a partir do cache local');
      } else {
        // Nunca houve download bem-sucedido: aí sim não há o que mostrar.
        _errorMessage = 'sem conexão e sem dados salvos neste aparelho';
        _stratification = null;
        _cachedAt = null;
      }
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
    _cachedAt = null;
    notifyListeners();
  }
}
