/// Stub para Android/iOS nativos: o app já está instalado, então não há
/// convite de instalação a oferecer. Nada aqui é chamado em produção — a tela
/// de login consulta [PwaInstall.disponivelNaPlataforma] antes de exibir
/// qualquer coisa —, mas o contrato precisa existir para o código compilar
/// nas três plataformas.
class PwaInstall {
  /// Falso no nativo: a tela de login não mostra nada relacionado a instalação.
  static bool get disponivelNaPlataforma => false;

  /// O app nativo é, por definição, o próprio app: nada a barrar.
  static bool get emModoApp => true;

  static bool get estaInstalado => true;

  static bool get podeInstalar => false;

  static bool get ehIos => false;

  static bool get ehCelular => false;

  static Future<PwaInstallResult> instalar() async =>
      PwaInstallResult.indisponivel;

  static void registrarCallback(void Function() aoMudar) {}
}

enum PwaInstallResult { aceito, recusado, indisponivel }
