import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/form_response.dart';
import '../providers/form_provider.dart';
import 'form_detail_screen.dart';

/// Coletas já CONFIRMADAS pelo painel.
///
/// Elas continuam salvas no aparelho como comprovante (com o id do registro
/// no servidor), mas ficam fora da tela principal: lá aparecem apenas as que
/// ainda precisam ser enviadas.
///
/// O carregamento acontece só quando esta tela é aberta, e em páginas — a
/// lista cresce indefinidamente em campo e não pode pesar na abertura do app.
class SentFormsScreen extends StatefulWidget {
  const SentFormsScreen({super.key});

  @override
  State<SentFormsScreen> createState() => _SentFormsScreenState();
}

class _SentFormsScreenState extends State<SentFormsScreen> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final List<FormResponse> _visible = [];

  List<FormResponse> _all = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = Provider.of<FormProvider>(context, listen: false);
    final forms = await provider.getSyncedForms();

    // Mais recentes primeiro.
    forms.sort((a, b) {
      final da = a.syncedAt ?? a.completedAt ?? a.startedAt;
      final db = b.syncedAt ?? b.completedAt ?? b.startedAt;
      return db.compareTo(da);
    });

    if (!mounted) return;
    setState(() {
      _all = forms;
      _visible
        ..clear()
        ..addAll(forms.take(_pageSize));
      _loading = false;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) {
      return;
    }
    if (_visible.length >= _all.length) return;

    setState(() {
      _visible.addAll(
        _all.skip(_visible.length).take(_pageSize),
      );
    });
  }

  Future<void> _openDetail(FormResponse form) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FormDetailScreen(form: form)),
    );
    // Ao voltar, recarrega: o reenvio pode ter atualizado serverId/syncedAt.
    if (mounted) await _load();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year} às '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Coletas Enviadas',
          style: TextStyle(
            color: Color(0xFF23345F),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF23345F)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE87722)),
            )
          : _all.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _visible.length +
                            (_visible.length < _all.length ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _visible.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFE87722),
                                ),
                              ),
                            );
                          }
                          return _SentFormTile(
                            form: _visible[index],
                            formatDate: _formatDate,
                            onTap: () => _openDetail(_visible[index]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFE8F5E9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.verified, size: 18, color: Color(0xFF198754)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_all.length} coleta(s) enviada(s). Toque para ver as '
              'respostas e reenviar se precisar.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Nenhuma coleta enviada ainda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'As coletas aparecem aqui depois que o painel confirmar '
              'o recebimento.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentFormTile extends StatelessWidget {
  final FormResponse form;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _SentFormTile({
    required this.form,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final quando = form.syncedAt ?? form.completedAt ?? form.startedAt;
    // Sem serverId a coleta foi marcada como enviada por uma versão antiga
    // do app, sem confirmação — pode não estar no painel.
    final confirmada = form.serverId != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Icon(
              confirmada ? Icons.check_circle : Icons.help_outline,
              color: confirmada
                  ? const Color(0xFF198754)
                  : const Color(0xFFE8962E),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    confirmada
                        ? 'Coleta #${form.serverId}'
                        : 'Coleta local #${form.id}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF23345F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Enviada em ${formatDate(quando)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '${form.responses.length} resposta(s)',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (confirmada
                        ? const Color(0xFF198754)
                        : const Color(0xFFE8962E))
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                confirmada ? 'no painel' : 'não confirmada',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: confirmada
                      ? const Color(0xFF198754)
                      : const Color(0xFFBF6D16),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}
