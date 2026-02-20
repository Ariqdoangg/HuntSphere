import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:huntsphere/core/di/service_locator.dart';
import 'package:huntsphere/services/report_service.dart';

/// Report service provider
final reportServiceProvider = Provider<ReportService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ReportService(client);
});

/// Report generation state
class ReportState {
  final bool isLoading;
  final String? error;
  final ActivityReportData? data;
  final Uint8List? pdfBytes;
  final String? csvContent;

  const ReportState({
    this.isLoading = false,
    this.error,
    this.data,
    this.pdfBytes,
    this.csvContent,
  });

  ReportState copyWith({
    bool? isLoading,
    String? error,
    ActivityReportData? data,
    Uint8List? pdfBytes,
    String? csvContent,
  }) {
    return ReportState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      data: data ?? this.data,
      pdfBytes: pdfBytes ?? this.pdfBytes,
      csvContent: csvContent ?? this.csvContent,
    );
  }
}

/// Report state notifier
class ReportNotifier extends StateNotifier<ReportState> {
  final ReportService _reportService;

  ReportNotifier(this._reportService) : super(const ReportState());

  /// Generate full report for an activity
  Future<void> generateReport(String activityId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Fetch data
      final data = await _reportService.fetchActivityReportData(activityId);

      // Generate PDF
      final pdfBytes = await _reportService.generatePdfReport(data);

      // Generate CSV
      final csvContent = await _reportService.generateCsvReport(data);

      state = state.copyWith(
        isLoading: false,
        data: data,
        pdfBytes: pdfBytes,
        csvContent: csvContent,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to generate report: $e',
      );
    }
  }

  /// Share PDF report
  Future<void> sharePdf(String fileName) async {
    if (state.pdfBytes == null) return;
    await _reportService.sharePdf(state.pdfBytes!, fileName);
  }

  /// Share CSV report
  Future<void> shareCsv(String fileName) async {
    if (state.csvContent == null) return;
    await _reportService.shareCsv(state.csvContent!, fileName);
  }

  /// Print report
  Future<void> printReport() async {
    if (state.pdfBytes == null) return;
    await _reportService.printReport(state.pdfBytes!);
  }

  /// Clear report data
  void clear() {
    state = const ReportState();
  }
}

/// Report provider (per activity)
final reportProvider =
    StateNotifierProvider.family<ReportNotifier, ReportState, String>(
  (ref, activityId) {
    final service = ref.watch(reportServiceProvider);
    return ReportNotifier(service);
  },
);

/// Quick report data provider (just fetches data, no PDF)
final activityReportDataProvider =
    FutureProvider.family<ActivityReportData, String>((ref, activityId) async {
  final service = ref.watch(reportServiceProvider);
  return service.fetchActivityReportData(activityId);
});
