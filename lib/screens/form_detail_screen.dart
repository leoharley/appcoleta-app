import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/form_response.dart';
import '../models/question.dart';
import '../models/question_response.dart';
import '../providers/form_provider.dart';
import '../services/local_storage_service.dart';

/// Detalhe de uma coleta já enviada: mostra as respostas capturadas e
/// permite reenviar ao painel.
///
/// O reenvio é seguro por causa do client_id: o backend reconhece a coleta
/// pela chave de idempotência e devolve o registro que já existe, em vez de
/// duplicar. Serve para quando há dúvida se a coleta chegou.
class FormDetailScreen extends StatefulWidget {
  final FormResponse form;

  const FormDetailScreen({super.key, required this.form});

  @override
  State<FormDetailScreen> createState() => _FormDetailScreenState();
}

class _FormDetailScreenState extends State<FormDetailScreen> {
  late FormResponse _form;

  /// Perguntas do questionário, para mostrar o enunciado em vez do id.
  Map<int, Question> _questions = const {};
  bool _loadingQuestions = true;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _form = widget.form;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuestions());
  }

  Future<void> _loadQuestions() async {
    try {
      final questionnaires = await LocalStorageService.getQuestionnaires();
      final questionnaire = questionnaires
          .where((q) => q.id == _form.questionnaireId)
          .firstOrNull;

      if (mounted) {
        setState(() {
          _questions = {
            for (final q in questionnaire?.questions ?? const <Question>[])
              q.id: q,
          };
          _loadingQuestions = false;
        });
      }
    } catch (e) {
      // Sem o questionário em cache ainda dá para mostrar as respostas,
      // só que identificadas pelo id da pergunta.
      print('⚠️ Não foi possível carregar as perguntas: $e');
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);

    final provider = Provider.of<FormProvider>(context, listen: false);
    final resultado = await provider.resendForm(_form);

    if (!mounted) return;
    setState(() => _resending = false);

    // Recarrega a coleta para refletir serverId/syncedAt atualizados.
    final atualizada = (await LocalStorageService.getFormResponses())
        .where((f) => f.id == _form.id)
        .firstOrNull;
    if (atualizada != null && mounted) {
      setState(() => _form = atualizada);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resultado.message),
        backgroundColor:
            resultado.success ? const Color(0xFF198754) : Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
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
        title: Text(
          'Coleta #${_form.serverId ?? _form.id}',
          style: const TextStyle(
            color: Color(0xFF23345F),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF23345F)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildResponsesCard(),
          const SizedBox(height: 16),
          _buildResendButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final confirmada = _form.serverId != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                confirmada ? Icons.verified : Icons.help_outline,
                color: confirmada
                    ? const Color(0xFF198754)
                    : const Color(0xFFE8962E),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                confirmada
                    ? 'Confirmada pelo painel'
                    : 'Sem confirmação do painel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: confirmada
                      ? const Color(0xFF198754)
                      : const Color(0xFFBF6D16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (confirmada)
            _linha('Registro no painel', '#${_form.serverId}')
          else
            // Coletas marcadas como enviadas por versões antigas do app,
            // antes da exigência de id. Não há prova de que chegaram.
            const Text(
              'Esta coleta foi marcada como enviada por uma versão anterior '
              'do app, sem confirmação do servidor. Reenvie para garantir '
              'que ela está no painel.',
              style: TextStyle(fontSize: 12, color: Color(0xFFBF6D16)),
            ),
          if (_form.syncedAt != null)
            _linha('Enviada em', _formatDate(_form.syncedAt!)),
          if (_form.completedAt != null)
            _linha('Concluída em', _formatDate(_form.completedAt!)),
          _linha('Respostas', '${_form.responses.length}'),
          if (_form.clientId != null)
            _linha('Identificador', _form.clientId!, mono: true),
        ],
      ),
    );
  }

  Widget _linha(String rotulo, String valor, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              rotulo,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF23345F),
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsesCard() {
    if (_loadingQuestions) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFE87722)),
        ),
      );
    }

    if (_form.responses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Esta coleta não tem respostas registradas.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Respostas capturadas',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 12),
          ..._form.responses.map(_buildResponseItem),
        ],
      ),
    );
  }

  Widget _buildResponseItem(QuestionResponse r) {
    final pergunta = _questions[r.questionId];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pergunta?.questionText ?? 'Pergunta #${r.questionId}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _formatResponse(r),
              style: const TextStyle(fontSize: 13, color: Color(0xFF23345F)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatResponse(QuestionResponse r) {
    if (r.selectedOptions != null && r.selectedOptions!.isNotEmpty) {
      return r.selectedOptions!.join(', ');
    }
    if (r.responseText != null && r.responseText!.isNotEmpty) {
      return r.responseText!;
    }
    if (r.responseNumber != null) return '${r.responseNumber}';
    if (r.responseDate != null) return _formatDate(r.responseDate!);
    if (r.responseDatetime != null) return _formatDate(r.responseDatetime!);
    return '— sem resposta —';
  }

  Widget _buildResendButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _resending ? null : _resend,
            icon: _resending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(_resending ? 'Reenviando...' : 'Reenviar ao painel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE87722),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Reenviar não duplica: o painel reconhece a coleta e devolve o '
          'registro existente.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
