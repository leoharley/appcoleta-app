import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Resultado de uma tentativa de captura de localização.
class LocationResult {
  final Position? position;

  /// Motivo da falha, já escrito para o aplicador. Null em caso de sucesso.
  final String? erro;

  const LocationResult.sucesso(this.position) : erro = null;
  const LocationResult.falha(this.erro) : position = null;

  bool get ok => position != null;
}

/// Captura de coordenadas com estratégia em etapas e aquecimento do GPS.
///
/// A versão anterior fazia uma única tentativa de alta precisão com 15 s de
/// limite, na hora de finalizar o questionário. Isso falhava com frequência:
///
/// - o GPS parte do zero (cold start) e num iPhone dentro de casa leva bem
///   mais de 15 s para o primeiro fix;
/// - não havia plano B — um timeout virava "sem localização", mesmo com o
///   aparelho sabendo sua posição aproximada por antena e Wi-Fi.
///
/// Aqui o GPS é aquecido desde o início do questionário, com o melhor fix
/// sendo guardado enquanto o aplicador preenche as perguntas. Na finalização,
/// quase sempre já existe posição pronta; se não existir, há uma escada de
/// alternativas antes de desistir.
class LocationService {
  LocationService._();

  static StreamSubscription<Position>? _assinatura;
  static Position? _melhorPosicao;
  static DateTime? _capturadaEm;

  /// Acima disso, a leitura é boa o suficiente para não valer a pena esperar
  /// por outra. Em campo aberto o GPS entrega 5–20 m; 50 m ainda identifica o
  /// domicílio com folga.
  static const double _precisaoDesejadaMetros = 50;

  /// Fix mais velho que isto é descartado: o aplicador pode ter andado desde
  /// que o questionário começou.
  static const Duration _validade = Duration(minutes: 5);

  /// Melhor posição já obtida no aquecimento, se ainda válida.
  static Position? get posicaoAquecida {
    if (_melhorPosicao == null || _capturadaEm == null) return null;
    if (DateTime.now().difference(_capturadaEm!) > _validade) return null;
    return _melhorPosicao;
  }

  /// Começa a ouvir o GPS em segundo plano. Chamado ao abrir o questionário,
  /// para que na finalização já exista posição — é o que evita o aplicador
  /// ficar parado esperando o sinal no fim da entrevista.
  ///
  /// Seguro para chamar mais de uma vez; falhas são silenciosas de propósito,
  /// já que a captura definitiva acontece em [obterPosicao].
  static Future<void> iniciarAquecimento() async {
    if (_assinatura != null) return;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        return;
      }

      _assinatura = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).listen(
        _registrar,
        onError: (e) => print('📍 Aquecimento do GPS interrompido: $e'),
        cancelOnError: false,
      );

      print('📍 Aquecimento do GPS iniciado');
    } catch (e) {
      print('⚠️ Não foi possível iniciar o aquecimento do GPS: $e');
    }
  }

  static void pararAquecimento() {
    _assinatura?.cancel();
    _assinatura = null;
    print('📍 Aquecimento do GPS encerrado');
  }

  /// Guarda a leitura apenas se for melhor que a atual — ou se a atual já
  /// venceu. Sem essa comparação, um fix ruim recém-chegado substituiria um
  /// bom obtido segundos antes.
  static void _registrar(Position p) {
    final atual = posicaoAquecida;
    if (atual == null || p.accuracy <= atual.accuracy) {
      _melhorPosicao = p;
      _capturadaEm = DateTime.now();
      print('📍 Fix guardado: ${p.latitude}, ${p.longitude} '
          '(±${p.accuracy.toStringAsFixed(0)} m)');
    }
  }

  /// Limpa o estado entre questionários, para a posição de uma aplicação não
  /// vazar para a seguinte.
  static void limpar() {
    pararAquecimento();
    _melhorPosicao = null;
    _capturadaEm = null;
  }

  /// Obtém a melhor posição possível, em etapas, da mais precisa à mais
  /// tolerante. Só devolve falha quando todas se esgotam.
  static Future<LocationResult> obterPosicao() async {
    // Etapa 0 — pré-requisitos. Estes dois casos o aplicador resolve no
    // aparelho, então vale mensagem específica em vez de tentar mais.
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.falha(
          'O GPS do aparelho está desligado. Ative a localização nas '
          'configurações e tente novamente.',
        );
      }
    } catch (e) {
      print('⚠️ Falha ao checar serviço de localização: $e');
    }

    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.deniedForever) {
      return const LocationResult.falha(
        'A permissão de localização foi negada permanentemente. Libere o '
        'acesso à localização nas configurações do aparelho.',
      );
    }
    if (permissao == LocationPermission.denied) {
      return const LocationResult.falha(
        'A permissão de localização não foi concedida. Ela é obrigatória '
        'para finalizar este questionário.',
      );
    }

    // Etapa 1 — o aquecimento já entregou algo preciso? Caminho mais comum, e
    // instantâneo.
    final aquecida = posicaoAquecida;
    if (aquecida != null && aquecida.accuracy <= _precisaoDesejadaMetros) {
      print('📍 Usando posição do aquecimento '
          '(±${aquecida.accuracy.toStringAsFixed(0)} m)');
      return LocationResult.sucesso(aquecida);
    }

    // Etapa 2 — tentativa de alta precisão, com prazo generoso. 30 s dá tempo
    // de um cold start do GPS, que os 15 s anteriores cortavam pela metade.
    final precisa = await _tentar(LocationAccuracy.best, 30, 'alta precisão');
    if (precisa != null) return LocationResult.sucesso(precisa);

    // Etapa 3 — qualquer fix do aquecimento serve mais do que nada, mesmo
    // impreciso: localiza o bairro, o que é infinitamente melhor que vazio.
    if (aquecida != null) {
      print('📍 Usando posição imprecisa do aquecimento '
          '(±${aquecida.accuracy.toStringAsFixed(0)} m)');
      return LocationResult.sucesso(aquecida);
    }

    // Etapa 4 — última posição conhecida do sistema (indisponível na web).
    try {
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null) {
        print('📍 Usando última posição conhecida do aparelho');
        return LocationResult.sucesso(ultima);
      }
    } catch (e) {
      print('📍 getLastKnownPosition indisponível: $e');
    }

    // Etapa 5 — precisão reduzida: usa antena e Wi-Fi, que costumam responder
    // onde o GPS não alcança (dentro de prédios, por exemplo).
    final aproximada =
        await _tentar(LocationAccuracy.medium, 20, 'precisão reduzida');
    if (aproximada != null) return LocationResult.sucesso(aproximada);

    return const LocationResult.falha(
      'Não foi possível obter o sinal de GPS após várias tentativas. Vá para '
      'um local mais aberto, longe de paredes e coberturas, e tente '
      'novamente.',
    );
  }

  static Future<Position?> _tentar(
    LocationAccuracy precisao,
    int segundos,
    String rotulo,
  ) async {
    try {
      print('📍 Tentando $rotulo (limite de ${segundos}s)...');
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: precisao,
      ).timeout(Duration(seconds: segundos));

      print('📍 Obtida por $rotulo: ${p.latitude}, ${p.longitude} '
          '(±${p.accuracy.toStringAsFixed(0)} m)');
      _registrar(p);
      return p;
    } catch (e) {
      print('📍 Falhou por $rotulo: $e');
      return null;
    }
  }
}
