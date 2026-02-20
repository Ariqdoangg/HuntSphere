import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'package:huntsphere/providers/report_provider.dart';
import 'package:huntsphere/services/report_service.dart';
import 'package:intl/intl.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String activityId;
  final String activityName;

  const ReportScreen({
    super.key,
    required this.activityId,
    required this.activityName,
  });

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  @override
  void initState() {
    super.initState();
    // Generate report on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reportProvider(widget.activityId).notifier).generateReport(widget.activityId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(reportProvider(widget.activityId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Activity Report'),
        actions: [
          if (reportState.pdfBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () => _printReport(),
              tooltip: 'Print',
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _showShareOptions(),
              tooltip: 'Share',
            ),
          ],
        ],
      ),
      body: _buildBody(reportState),
    );
  }

  Widget _buildBody(ReportState state) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryBlue),
            SizedBox(height: 16),
            Text(
              'Generating Report...',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: const TextStyle(color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref
                  .read(reportProvider(widget.activityId).notifier)
                  .generateReport(widget.activityId),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.data == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(state.data!),
          const SizedBox(height: 24),
          _buildStatistics(state.data!),
          const SizedBox(height: 24),
          _buildLeaderboard(state.data!),
          const SizedBox(height: 24),
          _buildExportButtons(state),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(ActivityReportData data) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.activityName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildHeaderChip(Icons.vpn_key, data.joinCode),
              const SizedBox(width: 12),
              _buildHeaderChip(
                Icons.circle,
                data.status.toUpperCase(),
                color: _getStatusColor(data.status),
              ),
            ],
          ),
          if (data.startedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Started: ${dateFormat.format(data.startedAt!)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (data.endedAt != null)
            Text(
              'Ended: ${dateFormat.format(data.endedAt!)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(ActivityReportData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard('Teams', data.teams.length.toString(), Icons.groups)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Participants', data.totalParticipants.toString(), Icons.person)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('Checkpoints', data.checkpoints.length.toString(), Icons.location_on)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Total Points', data.totalPoints.toString(), Icons.stars)),
          ],
        ),
        if (data.actualDuration != null) ...[
          const SizedBox(height: 12),
          _buildStatCard(
            'Duration',
            '${data.actualDuration!.inMinutes} min',
            Icons.timer,
            fullWidth: true,
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.backgroundElevated),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(ActivityReportData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Final Leaderboard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...data.teams.take(10).map((team) => _buildTeamRow(team)),
      ],
    );
  }

  Widget _buildTeamRow(TeamReportData team) {
    Color rankColor;
    switch (team.rank) {
      case 1:
        rankColor = Colors.amber;
        break;
      case 2:
        rankColor = Colors.grey.shade400;
        break;
      case 3:
        rankColor = Colors.brown.shade400;
        break;
      default:
        rankColor = AppTheme.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: team.rank <= 3
            ? Border.all(color: rankColor.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#${team.rank}',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(team.emoji ?? '', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.teamName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${team.participants.length} members - ${team.checkpointsCompleted} checkpoints',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${team.totalPoints}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'pts',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportButtons(ReportState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Export Options',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildExportButton(
                icon: Icons.picture_as_pdf,
                label: 'Export PDF',
                color: Colors.red,
                onPressed: state.pdfBytes != null
                    ? () => _sharePdf()
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildExportButton(
                icon: Icons.table_chart,
                label: 'Export CSV',
                color: Colors.green,
                onPressed: state.csvContent != null
                    ? () => _shareCsv()
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _buildExportButton(
            icon: Icons.print,
            label: 'Print Report',
            color: AppTheme.primaryBlue,
            onPressed: state.pdfBytes != null
                ? () => _printReport()
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.2),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Share as PDF', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Full detailed report', style: TextStyle(color: AppTheme.textMuted)),
              onTap: () {
                Navigator.pop(context);
                _sharePdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Share as CSV', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Leaderboard data for spreadsheets', style: TextStyle(color: AppTheme.textMuted)),
              onTap: () {
                Navigator.pop(context);
                _shareCsv();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sharePdf() {
    final fileName = '${widget.activityName.replaceAll(' ', '_')}_report';
    ref.read(reportProvider(widget.activityId).notifier).sharePdf(fileName);
  }

  void _shareCsv() {
    final fileName = '${widget.activityName.replaceAll(' ', '_')}_leaderboard';
    ref.read(reportProvider(widget.activityId).notifier).shareCsv(fileName);
  }

  void _printReport() {
    ref.read(reportProvider(widget.activityId).notifier).printReport();
  }
}
