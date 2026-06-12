import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/questionnaire.dart';
import '../models/stratification.dart';
import '../providers/stratification_provider.dart';
import 'consent_screen.dart';
import 'question_screen.dart';
import 'stratification_dashboard_screen.dart';

class QuestionnairePreviewScreen extends StatefulWidget {
  final Questionnaire questionnaire;

  const QuestionnairePreviewScreen({
    super.key,
    required this.questionnaire,
  });

  @override
  State<QuestionnairePreviewScreen> createState() =>
      _QuestionnairePreviewScreenState();
}

class _QuestionnairePreviewScreenState
    extends State<QuestionnairePreviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StratificationProvider>(context, listen: false)
          .loadStratification(widget.questionnaire.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF23345F),
                      size: 24,
                    ),
                  ),
                  Image.asset(
                    'assets/images/logo_alveslima.png',
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildPreviewCard(),
                            const SizedBox(height: 20),
                            _buildInfoCard(),
                            // Painel de estratificação
                            Consumer<StratificationProvider>(
                              builder: (context, stratProvider, _) {
                                if (stratProvider.isLoading) {
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 20),
                                    child: _StratificationLoadingCard(),
                                  );
                                }
                                if (!stratProvider.hasStratification) {
                                  // Mostrar erro se houver
                                  if (stratProvider.errorMessage != null) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 20),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3E0),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE8962E).withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.warning_amber, color: Color(0xFFE8962E), size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Estratificação: ${stratProvider.errorMessage}',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFFBF6D16)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: Column(
                                    children: [
                                      _StratificationCard(
                                        data: stratProvider.stratification!,
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    StratificationDashboardScreen(
                                                  questionnaireId:
                                                      widget.questionnaire.id,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.bar_chart,
                                            size: 18,
                                          ),
                                          label: const Text('Ver Dashboard de Cotas'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF23345F),
                                            side: const BorderSide(
                                              color: Color(0xFF23345F),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildActionButtons(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.questionnaire.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL DE PERGUNTAS',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${widget.questionnaire.questions.length} questões',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF23345F),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TEMPO ESTIMADO',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${widget.questionnaire.estimatedTime ?? 10}-${(widget.questionnaire.estimatedTime ?? 10) + 2} min',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF23345F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ÚLTIMA ATUALIZAÇÃO',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${widget.questionnaire.createdAt.day.toString().padLeft(2, '0')}/${widget.questionnaire.createdAt.month.toString().padLeft(2, '0')}/${widget.questionnaire.createdAt.year}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF23345F),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.questionnaire.status == 'active'
                          ? '✓ Ativo'
                          : '⏸ Pausado',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: widget.questionnaire.status == 'active'
                            ? const Color(0xFFE8962E)
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Visão Geral:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF23345F),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.questionnaire.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    List<String> requirements = [];

    if (widget.questionnaire.requiresConsent) {
      requirements.add('Consentimento obrigatório');
    }
    if (widget.questionnaire.requiresLocation) {
      requirements.add('Geolocalização ativa');
    }
    if (widget.questionnaire.requiresPhoto) {
      requirements.add('Foto requerida');
    }

    if (requirements.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info,
            color: Color(0xFFBF6D16),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requirements.join(' • '),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFBF6D16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.grey),
              ),
              child: const Text(
                'Voltar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _startQuestionnaire(context),
              child: const Text(
                'Iniciar Questionário',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startQuestionnaire(BuildContext context) {
    if (widget.questionnaire.requiresConsent) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ConsentScreen(questionnaire: widget.questionnaire),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuestionScreen(
            questionnaire: widget.questionnaire,
            currentQuestionIndex: 0,
          ),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Widgets internos do painel de estratificação
// ---------------------------------------------------------------------------

class _StratificationLoadingCard extends StatelessWidget {
  const _StratificationLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Carregando estratificação...',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _StratificationCard extends StatelessWidget {
  final StratificationData data;

  const _StratificationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final overall = data.overallProgress;
    final overallFraction =
        overall.totalTarget > 0 ? overall.totalCurrent / overall.totalTarget : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título do painel
          Row(
            children: [
              const Icon(
                Icons.bar_chart,
                color: Color(0xFF23345F),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF23345F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progresso geral
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progresso Geral',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                '${overall.totalCurrent}/${overall.totalTarget} (${overall.percentage.toStringAsFixed(1)}%)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF23345F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: overallFraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(
                overallFraction >= 1.0
                    ? const Color(0xFFE8962E)
                    : const Color(0xFF23345F),
              ),
            ),
          ),

          // Categorias
          if (data.categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...data.categories.map((category) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _CategorySection(category: category),
                )),
          ],
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final StratificationCategory category;

  const _CategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    final fraction = category.totalTarget > 0
        ? category.totalCurrent / category.totalTarget
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nome da categoria e progresso total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category.categoryName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF23345F),
              ),
            ),
            Text(
              '${category.totalCurrent}/${category.totalTarget}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(
              fraction >= 1.0
                  ? const Color(0xFFE8962E)
                  : const Color(0xFF5b7bbf),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Estratos
        ...category.strata.map((stratum) => _StratumRow(stratum: stratum)),
      ],
    );
  }
}

class _StratumRow extends StatelessWidget {
  final Stratum stratum;

  const _StratumRow({required this.stratum});

  @override
  Widget build(BuildContext context) {
    final fraction =
        stratum.targetQuota > 0 ? stratum.currentCount / stratum.targetQuota : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // Ícone de status
          Icon(
            stratum.quotaReached ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: stratum.quotaReached
                ? const Color(0xFFE8962E)
                : const Color(0xFF9E9E9E),
          ),
          const SizedBox(width: 6),

          // Label da opção
          Expanded(
            child: Text(
              stratum.optionLabel,
              style: TextStyle(
                fontSize: 12,
                color: stratum.quotaReached
                    ? const Color(0xFFE8962E)
                    : const Color(0xFF23345F),
                fontWeight: stratum.quotaReached
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),

          // Barra de progresso do estrato
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  stratum.quotaReached
                      ? const Color(0xFFE8962E)
                      : const Color(0xFF5b7bbf),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Contagem / restante
          SizedBox(
            width: 52,
            child: Text(
              stratum.quotaReached
                  ? '${stratum.targetQuota}/${stratum.targetQuota}'
                  : '${stratum.currentCount}/${stratum.targetQuota}',
              style: TextStyle(
                fontSize: 11,
                color: stratum.quotaReached
                    ? const Color(0xFFE8962E)
                    : Colors.grey,
                fontWeight: stratum.quotaReached
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
