import 'package:flutter/foundation.dart';
import '../models/stratification.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

/// Como terminou a última tentativa de carregar a estratificação.
///
/// Existe para a tela distinguir dois casos que antes eram idênticos para o
/// usuário (ambos renderizavam 0.0% / Meta 0 / Categorias 0):
/// questionário sem estratificação configurada x falha de rede/parse.
enum StratificationStatus {
  /// Nunca carregado nesta sessão.
  idle,

  /// Carregou e há pelo menos uma estratificação.
  loaded,

  /// Carregou com sucesso e o questionário não tem estratificação
  /// configurada ("stratifications": []).
  empty,

  /// Falha de rede, HTTP != 200 ou erro de parse.
  error,
}

class StratificationProvider extends ChangeNotifier {
  List<StratificationData> _stratifications = const [];
  StratificationStatus _status = StratificationStatus.idle;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;
  int? _lastQuestionnaireId;
  DateTime? _cachedAt;

  static const _cacheDuration = Duration(minutes: 5);

  /// Todas as estratificações do questionário (pode haver mais de uma).
  List<StratificationData> get stratifications => _stratifications;

  /// A primeira estratificação, para as telas que mostram apenas uma.
  StratificationData? get stratification =>
      _stratifications.isEmpty ? null : _stratifications.first;

  StratificationStatus get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _status == StratificationStatus.error;

  /// True quando o servidor respondeu certo e não há estratificação
  /// configurada — diferente de erro.
  bool get isEmpty => _status == StratificationStatus.empty;

  /// Quando os dados exibidos vieram do cache local (offline), traz a data do
  /// último download bem-sucedido. Null quando os dados são do servidor.
  DateTime? get cachedAt => _cachedAt;
  bool get isFromCache => _cachedAt != null;

  /// Retorna true se existe estratificação ativa carregada.
  bool get hasStratification =>
      stratification != null && stratification!.isActive;

  /// Procura alerta de cota atingida em TODAS as estratificações ativas do
  /// questionário, não só na primeira.
  Map<String, dynamic>? getQuotaAlert(int questionId, String optionValue) {
    for (final s in _stratifications) {
      if (!s.isActive) continue;
      final alert = s.getQuotaAlert(questionId, optionValue);
      if (alert != null) return alert;
    }
    return null;
  }

  /// Carrega estratificação do servidor para o questionário informado.
  ///
  /// [questionnaireId] é o ID DO QUESTIONÁRIO aberto — não o stratification_id
  /// e não um id de coleta. Ver ApiService.getStratification.
  ///
  /// Usa cache de 5 minutos a menos que [forceRefresh] seja true.
  Future<void> loadStratification(int questionnaireId,
      {bool forceRefresh = false}) async {
    // Retorna cache se valido
    if (!forceRefresh &&
        _lastQuestionnaireId == questionnaireId &&
        _lastFetchTime != null &&
        _status != StratificationStatus.error &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('📊 Carregando estratificação do questionário $questionnaireId...');
      final list = await ApiService.getStratification(questionnaireId);
      _stratifications = list;
      _lastQuestionnaireId = questionnaireId;
      _lastFetchTime = DateTime.now();
      _cachedAt = null; // dados frescos do servidor
      _errorMessage = null;

      if (list.isNotEmpty) {
        _status = StratificationStatus.loaded;
        print('✅ Estratificação carregada: ${list.first.title}');
        print('   Estratificações: ${list.length}');
        print('   Categorias: ${list.first.categories.length}');
        print('   Ativa: ${list.first.isActive}');
        // Guardar para uso offline nas próximas aberturas.
        await LocalStorageService.saveStratification(questionnaireId, list);
      } else {
        _status = StratificationStatus.empty;
        print('ℹ️ Nenhuma estratificação configurada para este questionário');
      }
    } catch (e) {
      // Offline ou servidor inacessível: usar a última versão baixada em vez
      // de esconder o painel e mostrar um erro de rede ao aplicador.
      print('❌ Erro ao carregar estratificação: $e');
      final cached =
          await LocalStorageService.getStratification(questionnaireId);

      if (cached != null) {
        _stratifications = cached.data;
        _cachedAt = cached.cachedAt;
        _lastQuestionnaireId = questionnaireId;
        _lastFetchTime = null; // não vale como cache de 5 min; retentar depois
        _errorMessage = null;
        _status = cached.data.isEmpty
            ? StratificationStatus.empty
            : StratificationStatus.loaded;
        print('✅ Estratificação exibida a partir do cache local');
      } else {
        // Nunca houve download bem-sucedido: aí sim é erro, e a tela precisa
        // dizer isso em vez de mostrar tudo zerado.
        _status = StratificationStatus.error;
        _errorMessage = _friendlyError(e);
        _stratifications = const [];
        _cachedAt = null;
        _lastFetchTime = null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('401')) {
      return 'Sessão expirada. Entre novamente para ver a estratificação.';
    }
    if (text.contains('SocketException') ||
        text.contains('TimeoutException') ||
        text.contains('Failed host lookup')) {
      return 'Sem conexão com o servidor e sem dados salvos neste aparelho.';
    }
    return 'Não foi possível carregar a estratificação. Tente novamente.';
  }

  void clear() {
    _stratifications = const [];
    _status = StratificationStatus.idle;
    _errorMessage = null;
    _lastFetchTime = null;
    _lastQuestionnaireId = null;
    _cachedAt = null;
    notifyListeners();
  }
}
