import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/carbon_activity_model.dart';
import '../../providers/carbon_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/dark_text_field.dart';
import '../../widgets/feature_intro_banner.dart';
import '../../widgets/glass_card.dart';

IconData categoryIcon(String category) {
  switch (category) {
    case 'transportation':
      return Icons.directions_car_outlined;
    case 'electricity':
      return Icons.bolt_outlined;
    case 'fuel':
      return Icons.local_gas_station_outlined;
    case 'food':
      return Icons.restaurant_outlined;
    case 'waste':
      return Icons.delete_outline_rounded;
    case 'water':
      return Icons.water_outlined;
    default:
      return Icons.eco_outlined;
  }
}

String categoryLabel(String category) {
  if (category.isEmpty) return category;
  return category[0].toUpperCase() + category.substring(1);
}

Color categoryColor(String category) {
  switch (category) {
    case 'transportation':
      return DarkPalette.cyanAccent;
    case 'electricity':
      return const Color(0xFFFFC857);
    case 'fuel':
      return const Color(0xFFFF8A50);
    case 'food':
      return DarkPalette.leafGreen;
    case 'waste':
      return const Color(0xFFA67C52);
    case 'water':
      return const Color(0xFF4A90E2);
    default:
      return DarkPalette.leafGreen;
  }
}

class CarbonScreen extends ConsumerWidget {
  const CarbonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carbonState = ref.watch(carbonProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Carbon footprint', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: DarkPalette.textPrimary),
            tooltip: 'Download report',
            onPressed: () => context.push('/reports'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(carbonProvider.notifier).load(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FeatureIntroBanner(
                icon: Icons.eco_outlined,
                title: 'Track your carbon footprint',
                description:
                    'Log daily activities like travel, electricity, and food — we convert them into kg of CO₂ so you can see your impact and find ways to reduce it.',
              ),
              const SizedBox(height: 16),
              if (carbonState.status == CarbonStatus.loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen)),
                )
              else if (carbonState.status == CarbonStatus.error)
                _buildErrorState(ref, carbonState.errorMessage)
              else ...[
                _buildSummaryGrid(carbonState.summary),
                const SizedBox(height: 20),
                CustomButton(
                  label: 'Log activity',
                  onPressed: () => _openLogSheet(context, ref),
                ),
                const SizedBox(height: 24),
                _buildWeeklySection(carbonState),
                const SizedBox(height: 14),
                _buildInsightsLink(context),
                const SizedBox(height: 24),
                const Text('Recent activity', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _buildHistory(carbonState.history),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(CarbonSummaryModel summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _summaryCard('Today', summary.todayKg)),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('This week', summary.thisWeekKg)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _summaryCard('This month', summary.thisMonthKg)),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('This year', summary.thisYearKg)),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(String label, double kg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.eco_outlined, color: DarkPalette.cyanAccent, size: 18),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(kg.toStringAsFixed(1), style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Text('kg CO₂', style: TextStyle(color: DarkPalette.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildWeeklySection(CarbonState state) {
    final daily = state.dailyBreakdown;
    final hasData = daily.any((d) => d.totalKg > 0);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This week', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (!hasData)
            _weeklyEmptyState()
          else ...[
            SizedBox(height: 160, child: _WeeklyBarChart(daily: daily)),
            const SizedBox(height: 16),
            _reductionTipCard(state.summary.monthByCategory),
          ],
        ],
      ),
    );
  }

  Widget _weeklyEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(Icons.insights_outlined, color: DarkPalette.textSecondary, size: 32),
          const SizedBox(height: 10),
          const Text(
            'No activity logged this week yet.',
            style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Log your first activity to start tracking your weekly trend.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DarkPalette.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsLink(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/insights'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: DarkPalette.cyanAccent.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome, color: DarkPalette.cyanAccent, size: 16),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('View AI insights', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right_rounded, color: DarkPalette.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _reductionTipCard(List<CarbonCategoryTotal> monthByCategory) {
    String tip;
    if (monthByCategory.isEmpty) {
      tip = 'Keep logging your activities — personalized tips will appear once we see a pattern.';
    } else {
      final top = monthByCategory.reduce((a, b) => b.co2Kg > a.co2Kg ? b : a);
      tip = _reductionTip(top.category);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [DarkPalette.leafGreen.withOpacity(0.12), DarkPalette.cyanAccent.withOpacity(0.08)]),
        border: Border.all(color: DarkPalette.leafGreen.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.lightbulb_outline, color: DarkPalette.leafGreen, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reduction tip', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(tip, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _reductionTip(String category) {
    switch (category) {
      case 'transportation':
        return 'Transportation is your biggest source this month. Try carpooling, cycling, or public transit for short trips.';
      case 'electricity':
        return 'Electricity use is driving your footprint this month. Switch off idle appliances and swap in LED bulbs where you can.';
      case 'fuel':
        return 'Fuel is your top emission source this month. Combine errands into fewer trips to cut down on driving.';
      case 'food':
        return 'Food choices are your biggest emission source this month. Try a plant-forward meal a few times a week.';
      case 'waste':
        return 'Waste is your top contributor this month. Composting food scraps and recycling more can make a real dent.';
      case 'water':
        return 'Water heating is your biggest source this month. Shorter showers and fixing leaks can help reduce it.';
      default:
        return 'Keep logging your activities — personalized tips will appear once we see a pattern.';
    }
  }

  Widget _buildHistory(List<CarbonActivityModel> history) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Text('No activity logged yet.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _historyTile(history[i]),
    );
  }

  Widget _historyTile(CarbonActivityModel activity) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(categoryIcon(activity.category), color: DarkPalette.leafGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${categoryLabel(activity.category)} · ${activity.subType.replaceAll('_', ' ')}',
                  style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${activity.quantity.toStringAsFixed(1)} ${activity.unit} · ${DateFormat('MMM d, h:mm a').format(activity.recordedAt.toLocal())}',
                  style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${activity.co2Kg.toStringAsFixed(2)} kg',
            style: const TextStyle(color: DarkPalette.cyanAccent, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref, String? message) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(
            message ?? 'Could not load carbon data.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(carbonProvider.notifier).load(),
            style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  void _openLogSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogActivitySheet(),
    );
  }
}

enum _TypeInputMode { list, custom }

class _LogActivitySheet extends ConsumerStatefulWidget {
  const _LogActivitySheet();

  @override
  ConsumerState<_LogActivitySheet> createState() => _LogActivitySheetState();
}

class _LogActivitySheetState extends ConsumerState<_LogActivitySheet> {
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  final _customSubTypeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _category;
  String? _subType;
  _TypeInputMode _mode = _TypeInputMode.list;
  String? _error;

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    _customSubTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(carbonProvider.select((s) => s.options));
    final isLogging = ref.watch(carbonProvider.select((s) => s.isLogging));
    final categories = options.keys.toList();
    final subTypes = _category != null ? options[_category] ?? [] : <CarbonSubTypeOption>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: DarkPalette.navyDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Log activity', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: DarkPalette.textPrimary, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Category', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map(_categoryChip).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Type', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Expanded(child: _modeTab('Choose from list', _TypeInputMode.list)),
                            Expanded(child: _modeTab('Custom', _TypeInputMode.custom)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_mode == _TypeInputMode.list)
                        // DropdownButtonFormField discards InputDecoration's
                        // hintText/hintStyle entirely — it converts hintText
                        // into a bare, unstyled Text widget and hands it to
                        // the underlying DropdownButton, which wraps its
                        // hint (enabled or disabled) in its own
                        // DefaultTextStyle keyed off Theme.of(context)
                        // .hintColor, not .disabledColor. disabledColor only
                        // affects the *selected value* text once the
                        // dropdown is enabled and something's chosen — kept
                        // here for that path, but hintColor is what actually
                        // colors "Choose a category first"/"Select a type".
                        // The app's real Theme is a light theme never
                        // otherwise visible, whose default hintColor
                        // (60%-opaque black) is nearly invisible on this
                        // dark background, so both are overridden locally.
                        Theme(
                          data: Theme.of(context).copyWith(
                            disabledColor: DarkPalette.textSecondary,
                            hintColor: DarkPalette.textSecondary,
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _subType,
                            isExpanded: true,
                            dropdownColor: DarkPalette.navyCard,
                            style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.06),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                              hintText: _category == null ? 'Choose a category first' : 'Select a type',
                              hintStyle: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
                            ),
                            items: subTypes
                                .map((s) => DropdownMenuItem(
                                      value: s.subType,
                                      child: Text(
                                        '${s.subType.replaceAll('_', ' ')} (${s.unit})',
                                        style: const TextStyle(color: DarkPalette.textPrimary),
                                      ),
                                    ))
                                .toList(),
                            onChanged: subTypes.isEmpty ? null : (v) => setState(() => _subType = v),
                            validator: (v) => v == null ? 'Select a type' : null,
                          ),
                        )
                      else ...[
                        DarkTextField(
                          hint: 'e.g. e-scooter, backyard compost',
                          icon: Icons.edit_outlined,
                          controller: _customSubTypeController,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Describe the activity' : null,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFFFFC857), size: 15),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "CO₂ won't be calculated for custom entries yet — pick from the list for accurate tracking.",
                                style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 11.5, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quantity', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      DarkTextField(
                        hint: _mode == _TypeInputMode.list && _subType != null
                            ? 'Amount in ${subTypes.firstWhere((s) => s.subType == _subType, orElse: () => CarbonSubTypeOption(subType: '', unit: 'units', factorKgCo2PerUnit: 0)).unit}'
                            : 'Amount',
                        icon: Icons.numbers_outlined,
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Enter a valid quantity';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Notes (optional)', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      DarkTextField(hint: 'Add a note', icon: Icons.notes_outlined, controller: _notesController),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: Color(0xFFE0605A), fontSize: 12)),
                ],
                const SizedBox(height: 20),
                _GradientSubmitButton(
                  label: 'Save',
                  isLoading: isLogging,
                  onPressed: _category == null ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String category) {
    final selected = category == _category;
    final color = categoryColor(category);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() {
        _category = category;
        _subType = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(categoryIcon(category), size: 15, color: selected ? color : DarkPalette.textSecondary),
            const SizedBox(width: 6),
            Text(
              categoryLabel(category),
              style: TextStyle(
                color: selected ? color : DarkPalette.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeTab(String label, _TypeInputMode value) {
    final selected = _mode == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _mode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? DarkPalette.leafGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : DarkPalette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _error = null);

    final subType = _mode == _TypeInputMode.list ? _subType! : _customSubTypeController.text.trim();

    final success = await ref.read(carbonProvider.notifier).logActivity(
          category: _category!,
          subType: subType,
          // The validator above already requires a valid, positive number
          // before this runs, but falls back to 0 rather than throwing if
          // that invariant is ever broken by a future change.
          quantity: double.tryParse(_quantityController.text) ?? 0,
          notes: _notesController.text,
        );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = ref.read(carbonProvider).errorMessage ?? 'Could not log activity.');
    }
  }
}

class _GradientSubmitButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GradientSubmitButton({required this.label, required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: DarkPalette.primaryButtonGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: DarkPalette.leafGreen.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(width: 8),
                        const Icon(Icons.check_rounded, color: Colors.black, size: 18),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<DailyBreakdown> daily;

  const _WeeklyBarChart({required this.daily});

  @override
  Widget build(BuildContext context) {
    final maxTotal = daily.map((d) => d.totalKg).fold<double>(0, (a, b) => b > a ? b : a);
    final chartMax = maxTotal <= 0 ? 1.0 : maxTotal * 1.25;
    final today = DateTime.now();

    return BarChart(
      BarChartData(
        maxY: chartMax,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        backgroundColor: Colors.transparent,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => DarkPalette.navyCard,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${daily[group.x.toInt()].totalKg.toStringAsFixed(1)} kg',
                const TextStyle(color: DarkPalette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= daily.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('E').format(daily[i].date),
                    style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(daily.length, (i) {
          final d = daily[i];
          final isToday = d.date.year == today.year && d.date.month == today.month && d.date.day == today.day;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: d.totalKg,
                color: isToday ? DarkPalette.cyanAccent : DarkPalette.leafGreen,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }
}
