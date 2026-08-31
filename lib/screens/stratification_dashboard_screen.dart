import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/stratification.dart';
import '../providers/stratification_provider.dart';

class StratificationDashboardScreen extends StatefulWidget {
  final int questionnaireId;

  const StratificationDashboardScreen({
    super.key,
    required this.questionnaireId,
  });

  @override
  State<StratificationDashboardScreen> createState() =>
      _StratificationDashboardScreenState();
}

class _StratificationDashboardScreenState
    extends State<StratificationDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() {
    return Provider.of<StratificationProvider>(context, listen: false)
        .loadStratification(widget.questionnaireId, forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Estratificação',
          style: TextStyle(
            color: Color(0xFF23345F),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF23345F)),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.sync),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Consumer<StratificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.stratification == null) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFE87722),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Carregando estratificação...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Falha de rede / HTTP != 200 / erro de parse. Precisa ser
          // visualmente distinto de "não configurado": antes os dois casos
          // caíam na mesma tela zerada e não dava para saber se o
          // questionário não tinha estratificação ou se algo quebrou.
          if (provider.hasError) {
            return _buildMessage(
              icon: Icons.cloud_off,
              iconColor: const Color(0xFFDC3545),
              title: 'Erro ao carregar a estratificação',
              detail: provider.errorMessage,
            );
          }

          if (!provider.hasStratification) {
            return _buildMessage(
              icon: Icons.bar_chart_outlined,
              iconColor: const Color(0xFF6C757D),
              title:
                  'Nenhuma estratificação configurada para este questionário.',
            );
          }

          final data = provider.stratification!;

          return RefreshIndicator(
            onRefresh: _refresh,
            color: const Color(0xFFE87722),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titulo + badge inativa
                  _buildHeader(data),
                  const SizedBox(height: 16),

                  // Cards de resumo 2x2
                  _buildSummaryCards(data),
                  const SizedBox(height: 20),

                  // Grafico rosca + barra
                  _buildChartsSection(data),
                  const SizedBox(height: 20),

                  // Progresso por categoria
                  _buildCategorySection(data),
                  const SizedBox(height: 20),

                  // Tabela detalhada
                  _buildDetailedList(data),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader(StratificationData data) {
    return Row(
      children: [
        Expanded(
          child: Text(
            data.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF23345F),
            ),
          ),
        ),
        if (!data.isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6C757D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'INATIVA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// Estado vazio/erro com o mesmo layout, mudando só ícone, cor e textos.
  Widget _buildMessage({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? detail,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6C757D),
              ),
            ),
            if (detail != null && detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6C757D),
                ),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.sync),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cards de resumo 2x2
  // ---------------------------------------------------------------------------
  Widget _buildSummaryCards(StratificationData data) {
    final overall = data.overallProgress;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Progresso Geral',
                value: _formatPercent(overall.percentage),
                valueColor: const Color(0xFFE87722),
                icon: Icons.trending_up,
                showProgress: true,
                // percentage pode passar de 100 quando a cota é superada
                // (ex.: 187.5); a barra satura em 100 para não estourar.
                progressValue: _progressFraction(overall.percentage),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Meta Total',
                value: '${overall.totalTarget}',
                valueColor: const Color(0xFF23345F),
                icon: Icons.flag_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Total Coletado',
                value: '${overall.totalCurrent}',
                valueColor: const Color(0xFFE87722),
                icon: Icons.assignment_turned_in_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Categorias',
                value: '${data.categories.length}',
                valueColor: const Color(0xFF23345F),
                icon: Icons.category_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Graficos: Rosca + Barras
  // ---------------------------------------------------------------------------
  Widget _buildChartsSection(StratificationData data) {
    return Column(
      children: [
        // Grafico rosca do progresso geral
        _buildDoughnutChart(data),
        const SizedBox(height: 16),
        // Grafico de barras por categoria
        if (data.categories.isNotEmpty) _buildBarChart(data),
      ],
    );
  }

  Widget _buildDoughnutChart(StratificationData data) {
    final overall = data.overallProgress;
    final collected = overall.totalCurrent.toDouble();
    final remaining =
        (overall.totalTarget - overall.totalCurrent).clamp(0, double.infinity).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Progresso Geral',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 55,
                    sections: [
                      PieChartSectionData(
                        value: collected,
                        color: const Color(0xFFE87722),
                        radius: 28,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: remaining > 0 ? remaining : 0.001,
                        color: const Color(0xFFE0E0E0),
                        radius: 24,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatPercent(overall.percentage),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF23345F),
                      ),
                    ),
                    const Text(
                      'concluído',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFFE87722), 'Coletado'),
              const SizedBox(width: 20),
              _legendDot(const Color(0xFFE0E0E0), 'Restante'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBarChart(StratificationData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coletado vs Meta por Categoria',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                // O topo considera coletado E meta: quando a cota é superada
                // (total_current > total_target) a barra de coletado passaria
                // do teto e sairia do gráfico.
                maxY: data.categories.fold<double>(
                        1,
                        (m, c) => [
                          m,
                          c.totalTarget.toDouble(),
                          c.totalCurrent.toDouble(),
                        ].reduce((a, b) => a > b ? a : b)) *
                    1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final cat = data.categories[groupIndex];
                      final label = rodIndex == 0 ? 'Coletado' : 'Meta';
                      final value = rodIndex == 0 ? cat.totalCurrent : cat.totalTarget;
                      return BarTooltipItem(
                        '$label: $value',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.categories.length) {
                          return const SizedBox.shrink();
                        }
                        final name = data.categories[idx].categoryName;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            name.length > 10 ? '${name.substring(0, 10)}...' : name,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        );
                      },
                      reservedSize: 32,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(data.categories.length, (i) {
                  final cat = data.categories[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: cat.totalCurrent.toDouble(),
                        color: const Color(0xFFE87722),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: cat.totalTarget.toDouble(),
                        color: const Color(0xFF23345F).withOpacity(0.35),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFFE87722), 'Coletado'),
              const SizedBox(width: 20),
              _legendDot(const Color(0xFF23345F).withOpacity(0.35), 'Meta'),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Progresso por categoria (cards expansiveis)
  // ---------------------------------------------------------------------------
  Widget _buildCategorySection(StratificationData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Progresso por Categoria',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF23345F),
          ),
        ),
        const SizedBox(height: 12),
        ...data.categories.map((cat) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CategoryCard(category: cat),
            )),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tabela detalhada
  // ---------------------------------------------------------------------------
  Widget _buildDetailedList(StratificationData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detalhamento por Estrato',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF23345F),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header da tabela
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF23345F),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Estrato', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('Meta / Col.', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text('Progresso', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text('Status', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                  ],
                ),
              ),
              // Rows
              ...data.categories.expand((cat) {
                final rows = <Widget>[];
                // Category header row
                rows.add(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: const Color(0xFFF0F2F5),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_outlined, size: 14, color: Color(0xFF23345F)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${cat.categoryName}  (${cat.totalCurrent}/${cat.totalTarget})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF23345F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                // Stratum rows
                for (int i = 0; i < cat.strata.length; i++) {
                  final s = cat.strata[i];
                  final remaining = (s.targetQuota - s.currentCount).clamp(0, s.targetQuota);
                  rows.add(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.optionLabel,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF23345F)),
                                ),
                                Text(
                                  'Faltam: $remaining',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${s.currentCount} / ${s.targetQuota}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF23345F)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                Text(
                                  _formatPercent(s.percentage, decimals: 0),
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                                const SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: _progressFraction(s.percentage),
                                    minHeight: 6,
                                    backgroundColor: const Color(0xFFE0E0E0),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _progressColor(s.percentage),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(child: _statusBadge(s)),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return rows;
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  /// Fração 0..1 para barras/gráficos. O backend manda percentage acima de
  /// 100 quando a cota é superada (ex.: 120, 187.5) — sem saturar aqui a
  /// barra estoura o layout.
  static double _progressFraction(double percentage) {
    if (percentage.isNaN || percentage.isNegative) return 0.0;
    return (percentage / 100).clamp(0.0, 1.0);
  }

  /// Texto do percentual. Arredonda para 1 casa: o backend manda doubles com
  /// muitas casas (109.09999999999994) e não pode vazar isso para a tela.
  /// Não satura — o usuário precisa ver que passou de 100%.
  static String _formatPercent(double percentage, {int decimals = 1}) {
    if (percentage.isNaN || percentage.isInfinite) return '0%';
    return '${percentage.toStringAsFixed(decimals)}%';
  }

  static Color _progressColor(double percentage) {
    if (percentage >= 100) return const Color(0xFF198754);
    if (percentage > 50) return const Color(0xFFFFC107);
    if (percentage > 0) return const Color(0xFF0DCAF0);
    return const Color(0xFF6C757D);
  }

  Widget _statusBadge(Stratum s) {
    String label;
    Color bg;
    Color fg;

    if (s.quotaReached) {
      label = 'COMPLETO';
      bg = const Color(0xFF198754);
      fg = Colors.white;
    } else if (s.currentCount > 0) {
      label = 'EM ANDAMENTO';
      bg = const Color(0xFFFFC107);
      fg = const Color(0xFF23345F);
    } else {
      label = 'PENDENTE';
      bg = const Color(0xFF6C757D);
      fg = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

// =============================================================================
// Widget: Card de resumo
// =============================================================================
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;
  final bool showProgress;
  final double progressValue;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    this.showProgress = false,
    this.progressValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: valueColor.withOpacity(0.7)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (showProgress) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE87722)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Widget: Card de categoria expansivel
// =============================================================================
class _CategoryCard extends StatefulWidget {
  final StratificationCategory category;

  const _CategoryCard({required this.category});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final fraction = cat.totalTarget > 0 ? cat.totalCurrent / cat.totalTarget : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (tappable)
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cat.categoryName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF23345F),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE87722).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${cat.totalCurrent}/${cat.totalTarget}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE87722),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE0E0E0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _StratificationDashboardScreenState._progressColor(cat.percentage),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Strata list
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
              child: Column(
                children: cat.strata.map((s) => _StratumTile(stratum: s)).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Widget: Tile de estrato dentro do card de categoria
// =============================================================================
class _StratumTile extends StatelessWidget {
  final Stratum stratum;

  const _StratumTile({required this.stratum});

  @override
  Widget build(BuildContext context) {
    final fraction =
        stratum.targetQuota > 0 ? stratum.currentCount / stratum.targetQuota : 0.0;
    final remaining = (stratum.targetQuota - stratum.currentCount).clamp(0, stratum.targetQuota);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          // Icone status
          Icon(
            stratum.quotaReached ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: stratum.quotaReached
                ? const Color(0xFF198754)
                : const Color(0xFF9E9E9E),
          ),
          const SizedBox(width: 8),

          // Label + barra
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        stratum.optionLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: stratum.quotaReached
                              ? const Color(0xFF198754)
                              : const Color(0xFF23345F),
                          fontWeight: stratum.quotaReached
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      '${stratum.currentCount}/${stratum.targetQuota}  (faltam $remaining)',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE0E0E0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _StratificationDashboardScreenState._progressColor(
                          stratum.percentage),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Badge completo
          if (stratum.quotaReached) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF198754),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'COMPLETO',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
