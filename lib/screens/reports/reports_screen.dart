import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/dark_palette.dart';
import '../../services/reports_service.dart';

enum _ReportStatus { idle, generating, error }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _period = 'week';
  _ReportStatus _status = _ReportStatus.idle;
  String? _error;

  Future<void> _downloadReport() async {
    setState(() {
      _status = _ReportStatus.generating;
      _error = null;
    });
    try {
      final bytes = await ref.read(reportsServiceProvider).generateReport(period: _period);

      final dir = await getApplicationDocumentsDirectory();
      final dateStamp = DateTime.now().toIso8601String().split('T').first;
      final file = File('${dir.path}/climatetech-report-$dateStamp.pdf');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      setState(() => _status = _ReportStatus.idle);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report saved, but could not open it: ${result.message}')),
        );
      }
    } on ReportException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _ReportStatus.error;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _ReportStatus.error;
        _error = 'Could not generate the report.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Download Report', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_status == _ReportStatus.generating) {
      return const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen));
    }
    if (_status == _ReportStatus.error) {
      return _buildErrorState(_error);
    }
    return _buildForm();
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Generate a PDF summary of your carbon footprint, climate activity, and achievements.',
            style: TextStyle(color: DarkPalette.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          const Text('Period', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _periodOption('week', 'This Week')),
              const SizedBox(width: 10),
              Expanded(child: _periodOption('month', 'This Month')),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _downloadReport,
              style: ButtonStyle(
                // Explicit per-state resolvers instead of styleFrom's single
                // foregroundColor/overlayColor — styleFrom applies the same
                // (near-black) foreground and a black-tinted overlay across
                // every state, which is what washed out the white text on
                // press/disabled. WidgetStateProperty.resolveWith lets each
                // state (pressed, disabled, default) get its own correct,
                // high-contrast value instead of inheriting one compromise
                // color for all of them.
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return DarkPalette.leafGreen.withOpacity(0.4);
                  }
                  return DarkPalette.leafGreen;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return Colors.white.withOpacity(0.7);
                  }
                  return Colors.white;
                }),
                // A light (white-based) overlay for the press/hover ripple —
                // visible against the solid green fill without darkening the
                // white label text the way a black overlay did.
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return Colors.white.withOpacity(0.16);
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return Colors.white.withOpacity(0.08);
                  }
                  return Colors.transparent;
                }),
                elevation: const WidgetStatePropertyAll(0),
                surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              child: const Text('Download Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodOption(String value, String label) {
    final selected = _period == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _period = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? DarkPalette.leafGreen.withOpacity(0.15) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? DarkPalette.leafGreen.withOpacity(0.5) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? DarkPalette.leafGreen : DarkPalette.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              message ?? 'Could not generate the report.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _downloadReport,
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
