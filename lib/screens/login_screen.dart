import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../services/pwa_install/pwa_install.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _appVersion = '';

  /// True depois que o aplicador leu as instruções de instalação do iPhone.
  ///
  /// O iOS não dispara `appinstalled` nem expõe qualquer sinal de que o atalho
  /// foi criado — só dá para saber quando o app é aberto pelo ícone. Sem esta
  /// marca, o iPhone ficaria preso na tela "Instale o app" mesmo depois de
  /// instalar, enquanto o Android mostra a confirmação.
  bool _seguiuInstrucoesIos = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();

    // O 'beforeinstallprompt' costuma chegar depois desta tela já estar
    // construída; sem o callback, o botão só apareceria na próxima navegação.
    if (PwaInstall.disponivelNaPlataforma) {
      PwaInstall.registrarCallback(() {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
        });
      }
    } catch (e) {
      print('❌ Erro ao obter versão do app: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/logo_alveslima.png',
                    width: 240,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              // No celular, o acesso só acontece pelo app instalado: ver
              // [_exigeInstalacao]. No desktop e no nativo, formulário normal.
              if (_exigeInstalacao)
                _buildInstallRequired()
              else
              // Form
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 15),
                      const Text(
                        'Bem-vindo ao AppColeta',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF23345F),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Faça login para continuar',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFFE8962E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      
                      // Username Field
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Usuário',
                          hintText: 'Digite seu usuário',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, digite seu usuário';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          hintText: 'Digite sua senha',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword 
                                ? Icons.visibility 
                                : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, digite sua senha';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      
                      // Login Button
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          return ElevatedButton(
                            onPressed: authProvider.isLoading ? null : _login,
                            child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Entrar',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      _buildInstallButton(),

                      const SizedBox(height: 10),
                      Text(
                        _appVersion.isEmpty ? '' : 'Versão: $_appVersion',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(255, 145, 145, 145),
                        ),
                        textAlign: TextAlign.center,
                      ),

                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// True quando o acesso deve ser barrado por estar no navegador do celular
  /// em vez do app instalado.
  ///
  /// O motivo é a produção partida: no iPhone, o atalho da tela de início tem
  /// armazenamento próprio, separado do Safari — questionários aplicados num
  /// não existem no outro, e o aplicador conclui que os dados sumiram. No
  /// Android o armazenamento é compartilhado com o Chrome, então lá o risco é
  /// de hábito inconsistente, não de perda; ainda assim exigimos o mesmo ponto
  /// de entrada nos dois, para a instrução em campo ser uma só.
  ///
  /// Restrito ao celular de propósito: no desktop, onde ninguém aplica
  /// questionário, o navegador segue liberado para conferência e testes.
  /// Usa [PwaInstall.emModoApp], e não `estaInstalado`: instalar o app não
  /// transforma a aba atual em app — ela continua sendo navegador até o
  /// aplicador abrir pelo ícone.
  bool get _exigeInstalacao =>
      PwaInstall.disponivelNaPlataforma &&
      PwaInstall.ehCelular &&
      !PwaInstall.emModoApp;

  /// Substitui o formulário de login quando o app está sendo aberto pelo
  /// navegador do celular. Mostra como instalar e como abrir depois, no mesmo
  /// lugar — sem essa saída, seria só uma porta fechada.
  Widget _buildInstallRequired() {
    // Três estados, porque o que o aplicador precisa ler muda conforme onde
    // ele parou — e porque no iPhone não dá para afirmar que instalou:
    //
    //  1. inicial            — ainda não tentou instalar
    //  2. instalado (Android) — evento 'appinstalled' confirmou
    //  3. instruções lidas (iPhone) — não há confirmação possível, só o
    //     lembrete do que fazer em seguida
    final confirmadoInstalado = PwaInstall.estaInstalado;
    final aguardandoIos = !confirmadoInstalado && _seguiuInstrucoesIos;
    final jaInstalou = confirmadoInstalado || aguardandoIos;

    final String titulo;
    final String legenda;
    final IconData icone;
    final Color cor;

    if (confirmadoInstalado) {
      titulo = 'App instalado!';
      legenda = 'Agora feche esta aba e abra pelo ícone do aplicativo';
      icone = Icons.check_circle;
      cor = const Color(0xFF2E7D32);
    } else if (aguardandoIos) {
      titulo = 'Quase lá!';
      legenda = 'Depois de adicionar à tela de início, abra pelo ícone do '
          'aplicativo';
      icone = Icons.touch_app;
      cor = const Color(0xFFE8962E);
    } else {
      titulo = 'Instale o app para continuar';
      legenda = 'Depois de instalar, abra sempre pelo ícone do aplicativo';
      icone = Icons.install_mobile;
      cor = const Color(0xFF23345F);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Icon(icone, size: 56, color: cor),
          const SizedBox(height: 20),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildComoAbrir(legenda: legenda),
          const SizedBox(height: 24),
          if (!jaInstalou)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _instalarApp,
                icon: const Icon(Icons.install_mobile, size: 20),
                label: const Text(
                  'INSTALAR APLICATIVO',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8962E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          if (!jaInstalou) const SizedBox(height: 24),
          Text(
            _appVersion.isEmpty ? '' : 'Versão: $_appVersion',
            style: const TextStyle(
              fontSize: 12,
              color: Color.fromARGB(255, 145, 145, 145),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Exemplo visual de como abrir o app depois de instalado: uma miniatura da
  /// tela de início com o ícone do AppColeta destacado entre os demais.
  ///
  /// Mostrar vale mais que explicar aqui — o aplicador precisa reconhecer o
  /// ícone no meio dos outros do aparelho, e isso um parágrafo não resolve.
  Widget _buildComoAbrir({required String legenda}) {
    return Column(
      children: [
        Text(
          legenda,
          style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD4DAE3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _appOutro(),
              const SizedBox(width: 14),
              _appDestacado(),
              const SizedBox(width: 14),
              _appOutro(),
            ],
          ),
        ),
      ],
    );
  }

  /// Ícone genérico e apagado, só para dar contexto de "tela cheia de apps".
  Widget _appOutro() {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFCBD2DC),
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFCBD2DC),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }

  /// O ícone real do app, com anel de destaque e o nome como aparece na tela
  /// de início — é o que o aplicador vai procurar no aparelho.
  Widget _appDestacado() {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFE8962E), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE8962E).withOpacity(0.25),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/icone_alveslima.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'App\nColeta',
          style: TextStyle(
            fontSize: 10,
            height: 1.15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF23345F),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        const Icon(Icons.touch_app, size: 16, color: Color(0xFFE8962E)),
      ],
    );
  }

  /// Botão de instalar o app na tela de início (só na versão web).
  ///
  /// Existe porque o convite nativo do Chrome é efêmero: aparece sozinho, some
  /// sozinho e, uma vez dispensado, pode não voltar por dias — deixando o
  /// aplicador sem caminho para instalar. Aqui o convite fica sempre à mão.
  Widget _buildInstallButton() {
    if (!PwaInstall.disponivelNaPlataforma) return const SizedBox.shrink();
    // Já rodando pelo ícone da tela de início: não há o que oferecer.
    if (PwaInstall.estaInstalado) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _instalarApp,
          icon: const Icon(Icons.install_mobile, size: 20),
          label: const Text(
            'INSTALAR APLICATIVO',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF23345F),
            side: const BorderSide(color: Color(0xFF23345F), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _instalarApp() async {
    // iPhone não expõe instalação programática — só resta ensinar o caminho.
    if (PwaInstall.ehIos) {
      await _mostrarInstrucoes(
        titulo: 'Instalar no iPhone',
        passos: const [
          'Toque no botão Compartilhar (quadrado com seta para cima), na barra '
              'inferior do Safari.',
          'Role a lista e toque em "Adicionar à Tela de Início".',
          'Confirme em "Adicionar".',
          'Use sempre o ícone criado na tela de início — o app guarda os dados '
              'separadamente do Safari.',
        ],
      );
      // O iOS não avisa quando o atalho é criado; assumir que o aplicador
      // seguiu os passos é o mais próximo de uma confirmação que existe lá.
      if (mounted) {
        setState(() {
          _seguiuInstrucoesIos = true;
        });
      }
      return;
    }

    final resultado = await PwaInstall.instalar();
    if (!mounted) return;

    switch (resultado) {
      case PwaInstallResult.aceito:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App instalado. Use o ícone criado na tela de início.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        setState(() {});
      case PwaInstallResult.recusado:
        // Nada a fazer: o botão continua disponível para uma nova tentativa.
        break;
      case PwaInstallResult.indisponivel:
        // O navegador não guardou o convite (já usado, ou navegador sem
        // suporte). Ensinar o caminho manual em vez de deixar o botão morto.
        _mostrarInstrucoes(
          titulo: 'Instalar pelo navegador',
          passos: const [
            'Toque no menu do navegador (os três pontinhos, no canto superior).',
            'Escolha "Instalar aplicativo" ou "Adicionar à tela inicial".',
            'Confirme em "Instalar".',
          ],
        );
    }
  }

  Future<void> _mostrarInstrucoes({
    required String titulo,
    required List<String> passos,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.install_mobile, color: Color(0xFF23345F)),
            const SizedBox(width: 8),
            Expanded(child: Text(titulo)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < passos.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        passos[i],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF23345F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      try {
        // Usar o método login do AuthProvider
        final success = await authProvider.login(
          _usernameController.text.trim(),
          _passwordController.text.trim(),
        );
        
        if (success && mounted) {
          // Login bem-sucedido - navegar para dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else if (mounted) {
          // Login falhou
          _showError('Usuário ou senha inválidos');
        }
      } catch (e) {
        if (mounted) {
          _showError('Erro ao fazer login: $e');
        }
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}