import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/category.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/month_selector.dart';
import '../widgets/page_header.dart';
import '../widgets/theme_artwork.dart';
import 'recap_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  TxType _type = TxType.expense;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final entries = provider.totalsByCategory(_type);
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);

    return SafeArea(
      child: Column(
        children: [
          PageHeader(
            title: 'Statistik',
            artworkTile: 8,
            action: IconButton(
              icon: const Icon(Icons.summarize_outlined),
              tooltip: 'Rekap',
              onPressed: () {
                Navigator.push(context, slideUpRoute(const RecapScreen()));
              },
            ),
          ),
          const MonthSelector(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<TxType>(
              expandedInsets: EdgeInsets.zero,
              segments: const [
                ButtonSegment(
                  value: TxType.expense,
                  label: Text('Pengeluaran'),
                  icon: Icon(Icons.arrow_upward, size: 16),
                ),
                ButtonSegment(
                  value: TxType.income,
                  label: Text('Pemasukan'),
                  icon: Icon(Icons.arrow_downward, size: 16),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                const _TrendChart(),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    decoration: BoxDecoration(
                      color: cardColor(context),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: cardShadow(context),
                    ),
                    child: Column(
                      children: [
                        const ThemeArtwork(tile: 8, size: 96),
                        const SizedBox(height: 10),
                        Text(
                          'Belum ada data bulan ini',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _CategoryChart(entries: entries, total: total, type: _type),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Rincian Kategori',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${entries.length} kategori',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < entries.length; i++)
                    StaggeredItem(
                      key: ValueKey(
                        'stat-${provider.month}-${_type.name}'
                        '-${entries[i].key.id}',
                      ),
                      index: i,
                      child: _CategoryRow(
                        category: entries[i].key,
                        amount: entries[i].value,
                        fraction: total == 0 ? 0 : entries[i].value / total,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChart extends StatefulWidget {
  final List<MapEntry<Category, double>> entries;
  final double total;
  final TxType type;

  const _CategoryChart({
    required this.entries,
    required this.total,
    required this.type,
  });

  @override
  State<_CategoryChart> createState() => _CategoryChartState();
}

class _CategoryChartState extends State<_CategoryChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final label = widget.type == TxType.expense
        ? 'Total Pengeluaran'
        : 'Total Pemasukan';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rupiah(widget.total),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutCubic,
                  PieChartData(
                    centerSpaceRadius: 52,
                    sectionsSpace: 3,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response?.touchedSection == null) {
                            _touchedIndex = null;
                            return;
                          }
                          _touchedIndex =
                              response!.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sections: [
                      for (var i = 0; i < widget.entries.length; i++)
                        PieChartSectionData(
                          value: widget.entries[i].value,
                          color: widget.entries[i].key.color,
                          radius: _touchedIndex == i ? 62 : 54,
                          title: widget.entries[i].value / widget.total < 0.1
                              ? ''
                              : '${(widget.entries[i].value / widget.total * 100).round()}%',
                          titleStyle: TextStyle(
                            fontSize: _touchedIndex == i ? 14 : 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.entries.length}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'kategori',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grafik garis tren pemasukan vs pengeluaran 6 bulan terakhir.
class _TrendChart extends StatefulWidget {
  const _TrendChart();

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  // Cache hasil query: cuma fetch ulang kalau data transaksi
  // beneran berubah (revision naik) atau jumlah bulannya diganti user,
  // bukan tiap rebuild.
  int? _lastRevision;
  int? _lastMonthsBack;
  Future<Map<String, ({double income, double expense})>>? _future;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final monthsBack = context.watch<SettingsProvider>().trendMonths;
    if (_lastRevision != provider.revision || _lastMonthsBack != monthsBack) {
      _lastRevision = provider.revision;
      _lastMonthsBack = monthsBack;
      _future = DatabaseHelper.instance.monthlyTotals(monthsBack);
    }
    final now = DateTime.now();
    final months = List.generate(
      monthsBack,
      (i) => DateTime(now.year, now.month - (monthsBack - 1) + i),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tren $monthsBack Bulan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const _LegendDot(color: incomeColor, label: 'Masuk'),
              const SizedBox(width: 10),
              const _LegendDot(color: expenseColor, label: 'Keluar'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child:
                FutureBuilder<Map<String, ({double income, double expense})>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Tren belum bisa dimuat',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final data = snapshot.data!;
                    String ym(DateTime d) =>
                        '${d.year}-${d.month.toString().padLeft(2, '0')}';
                    final incomeSpots = <FlSpot>[];
                    final expenseSpots = <FlSpot>[];
                    for (var i = 0; i < months.length; i++) {
                      final totals =
                          data[ym(months[i])] ?? (income: 0.0, expense: 0.0);
                      incomeSpots.add(FlSpot(i.toDouble(), totals.income));
                      expenseSpots.add(FlSpot(i.toDouble(), totals.expense));
                    }
                    return LineChart(
                      duration: const Duration(milliseconds: 400),
                      LineChartData(
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.1),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(),
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= months.length) {
                                  return const SizedBox();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    bulanPendek(months[index]),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) => [
                              for (final spot in spots)
                                LineTooltipItem(
                                  rupiah(spot.y),
                                  TextStyle(
                                    color: spot.bar.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        lineBarsData: [
                          _line(incomeSpots, incomeColor),
                          _line(expenseSpots, expenseColor),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 2.5,
      isCurved: true,
      curveSmoothness: 0.3,
      preventCurveOverShooting: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.06),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;
  final double amount;
  final double fraction;

  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: categoryGradient(category.color),
              boxShadow: [
                BoxShadow(
                  color: category.color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: category.iconWidget(color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      rupiah(amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fraction),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedFraction, _) =>
                        LinearProgressIndicator(
                          value: animatedFraction,
                          minHeight: 6,
                          backgroundColor: category.color.withValues(
                            alpha: 0.1,
                          ),
                          valueColor: AlwaysStoppedAnimation(category.color),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
