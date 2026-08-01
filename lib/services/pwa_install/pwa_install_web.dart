import 'dart:js_interop';

/// Ponte com o JS declarado em `web/index.html`, que captura o evento
/// `beforeinstallprompt` do navegador.
///
/// O evento precisa ser guardado no momento em que o navegador o dispara — não
/// dá para pedi-lo depois. Por isso a captura mora no index.html e aqui só
/// consultamos e acionamos o que foi guardado.
@JS('pwaPodeInstalar')
external bool _pwaPodeInstalar();

@JS('pwaEstaInstalado')
external bool _pwaEstaInstalado();

@JS('pwaEmModoApp')
external bool _pwaEmModoApp();

@JS('pwaEhIos')
external bool _pwaEhIos();

@JS('pwaEhCelular')
external bool _pwaEhCelular();

@JS('pwaInstalar')
external JSPromise<JSString> _pwaInstalar();

@JS('pwaRegistrarCallback')
external void _pwaRegistrarCallback(JSFunction callback);

/// Resultado de uma tentativa de instalação.
enum PwaInstallResult {
  /// O aplicador aceitou e o app foi instalado.
  aceito,

  /// O aplicador viu o convite e recusou.
  recusado,

  /// O navegador não ofereceu instalação (iPhone, ou convite já consumido).
  indisponivel,
}

/// Instalação do app na tela de início, na versão web.
///
/// Existe porque o convite nativo do Chrome é efêmero: aparece sozinho, some
/// sozinho e, uma vez dispensado, pode não voltar por dias. Sem um botão
/// explícito, o aplicador que fechou o banner fica sem caminho para instalar.
class PwaInstall {
  static bool get disponivelNaPlataforma => true;

  /// True quando ESTA página está rodando pelo ícone, fora do navegador.
  ///
  /// É o sinal que libera o login — e é diferente de [estaInstalado]. Instalar
  /// o app não transforma a aba atual em app: ela continua sendo navegador até
  /// o aplicador abrir pelo ícone. Usar [estaInstalado] aqui liberava o login
  /// no navegador logo após a instalação.
  static bool get emModoApp {
    try {
      return _pwaEmModoApp();
    } catch (e) {
      print('⚠️ pwaEmModoApp indisponível: $e');
      return false;
    }
  }

  /// True quando o app está instalado no aparelho — inclusive quando a
  /// instalação acabou de acontecer nesta aba. Serve para esconder o convite
  /// de instalação, não para liberar acesso (para isso use [emModoApp]).
  static bool get estaInstalado {
    try {
      return _pwaEstaInstalado();
    } catch (e) {
      print('⚠️ pwaEstaInstalado indisponível: $e');
      return false;
    }
  }

  /// True quando o navegador guardou o convite e a instalação pode ser feita
  /// com um toque. Falso no iPhone e quando o convite já foi consumido.
  static bool get podeInstalar {
    try {
      return _pwaPodeInstalar();
    } catch (e) {
      print('⚠️ pwaPodeInstalar indisponível: $e');
      return false;
    }
  }

  /// iOS não expõe instalação programática — o caminho é Compartilhar >
  /// Adicionar à Tela de Início, e o app precisa ensinar isso.
  static bool get ehIos {
    try {
      return _pwaEhIos();
    } catch (e) {
      print('⚠️ pwaEhIos indisponível: $e');
      return false;
    }
  }

  /// Celular (Android ou iPhone). Usado para exigir o app instalado apenas
  /// onde o aplicador de fato trabalha; no desktop o navegador segue liberado.
  ///
  /// Em caso de falha, assume `false` de propósito: um erro de detecção não
  /// pode trancar o aplicador fora do sistema em campo.
  static bool get ehCelular {
    try {
      return _pwaEhCelular();
    } catch (e) {
      print('⚠️ pwaEhCelular indisponível: $e');
      return false;
    }
  }

  static Future<PwaInstallResult> instalar() async {
    try {
      final resultado = (await _pwaInstalar().toDart).toDart;
      switch (resultado) {
        case 'aceito':
          return PwaInstallResult.aceito;
        case 'recusado':
          return PwaInstallResult.recusado;
        default:
          return PwaInstallResult.indisponivel;
      }
    } catch (e) {
      print('❌ Erro ao instalar PWA: $e');
      return PwaInstallResult.indisponivel;
    }
  }

  /// Avisa quando a disponibilidade muda: o `beforeinstallprompt` costuma
  /// chegar depois da tela de login já estar construída, e sem isso o botão
  /// só apareceria na próxima navegação.
  static void registrarCallback(void Function() aoMudar) {
    try {
      _pwaRegistrarCallback(aoMudar.toJS);
    } catch (e) {
      print('⚠️ Não foi possível registrar callback de instalação: $e');
    }
  }
}
