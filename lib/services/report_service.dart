import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Report types available
enum ReportType {
  activitySummary,
  leaderboard,
  teamDetails,
  participantList,
  checkpointAnalysis,
}

/// Activity report data model
class ActivityReportData {
  final String activityId;
  final String activityName;
  final String joinCode;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int totalDuration;
  final List<TeamReportData> teams;
  final List<CheckpointReportData> checkpoints;
  final int totalParticipants;
  final int totalPoints;

  ActivityReportData({
    required this.activityId,
    required this.activityName,
    required this.joinCode,
    required this.status,
    this.startedAt,
    this.endedAt,
    required this.totalDuration,
    required this.teams,
    required this.checkpoints,
    required this.totalParticipants,
    required this.totalPoints,
  });

  Duration? get actualDuration {
    if (startedAt == null || endedAt == null) return null;
    return endedAt!.difference(startedAt!);
  }
}

/// Team report data model
class TeamReportData {
  final String teamId;
  final String teamName;
  final String? emoji;
  final String? color;
  final int totalPoints;
  final int checkpointsCompleted;
  final int rank;
  final List<ParticipantReportData> participants;
  final DateTime? finishedAt;

  TeamReportData({
    required this.teamId,
    required this.teamName,
    this.emoji,
    this.color,
    required this.totalPoints,
    required this.checkpointsCompleted,
    required this.rank,
    required this.participants,
    this.finishedAt,
  });
}

/// Participant report data model
class ParticipantReportData {
  final String participantId;
  final String name;
  final String? teamName;
  final DateTime joinedAt;

  ParticipantReportData({
    required this.participantId,
    required this.name,
    this.teamName,
    required this.joinedAt,
  });
}

/// Checkpoint report data model
class CheckpointReportData {
  final String checkpointId;
  final String name;
  final double latitude;
  final double longitude;
  final int orderIndex;
  final int tasksCount;
  final int completionCount;

  CheckpointReportData({
    required this.checkpointId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.orderIndex,
    required this.tasksCount,
    required this.completionCount,
  });
}

/// Service for generating reports
class ReportService {
  final SupabaseClient _client;

  ReportService(this._client);

  /// Fetch complete activity data for report
  Future<ActivityReportData> fetchActivityReportData(String activityId) async {
    // Fetch activity
    final activityResponse = await _client
        .from('activities')
        .select()
        .eq('id', activityId)
        .single();

    // Fetch teams with participants (order by points, then finish time for tiebreaker)
    final teamsResponse = await _client
        .from('teams')
        .select('*, participants(*)')
        .eq('activity_id', activityId)
        .order('total_points', ascending: false)
        .order('finished_at', ascending: true, nullsFirst: false);

    // Fetch checkpoints
    final checkpointsResponse = await _client
        .from('checkpoints')
        .select()
        .eq('activity_id', activityId)
        .order('order_index', ascending: true);

    // Process teams
    final teams = <TeamReportData>[];
    int totalParticipants = 0;
    int rank = 1;

    for (final teamData in teamsResponse as List) {
      final participants = <ParticipantReportData>[];

      if (teamData['participants'] != null) {
        for (final p in teamData['participants'] as List) {
          participants.add(ParticipantReportData(
            participantId: p['id'],
            name: p['name'] ?? 'Unknown',
            teamName: teamData['team_name'],
            joinedAt: DateTime.parse(p['created_at']),
          ));
          totalParticipants++;
        }
      }

      teams.add(TeamReportData(
        teamId: teamData['id'],
        teamName: teamData['team_name'] ?? 'Team ${rank}',
        emoji: teamData['emoji'],
        color: teamData['color'],
        totalPoints: teamData['total_points'] ?? 0,
        checkpointsCompleted: teamData['checkpoints_completed'] ?? 0,
        rank: rank,
        participants: participants,
        finishedAt: teamData['finished_at'] != null
            ? DateTime.parse(teamData['finished_at'])
            : null,
      ));
      rank++;
    }

    // Process checkpoints
    final checkpoints = <CheckpointReportData>[];
    for (final cp in checkpointsResponse as List) {
      checkpoints.add(CheckpointReportData(
        checkpointId: cp['id'],
        name: cp['name'] ?? 'Checkpoint',
        latitude: (cp['latitude'] ?? 0).toDouble(),
        longitude: (cp['longitude'] ?? 0).toDouble(),
        orderIndex: cp['order_index'] ?? 0,
        tasksCount: (cp['tasks'] as List?)?.length ?? 0,
        completionCount: 0, // Would need additional query
      ));
    }

    // Calculate total points
    final totalPoints = teams.fold<int>(0, (sum, t) => sum + t.totalPoints);

    return ActivityReportData(
      activityId: activityId,
      activityName: activityResponse['name'] ?? 'Activity',
      joinCode: activityResponse['join_code'] ?? '',
      status: activityResponse['status'] ?? 'unknown',
      startedAt: activityResponse['started_at'] != null
          ? DateTime.parse(activityResponse['started_at'])
          : null,
      endedAt: activityResponse['ended_at'] != null
          ? DateTime.parse(activityResponse['ended_at'])
          : null,
      totalDuration: activityResponse['total_duration_minutes'] ?? 0,
      teams: teams,
      checkpoints: checkpoints,
      totalParticipants: totalParticipants,
      totalPoints: totalPoints,
    );
  }

  /// Generate PDF report
  Future<Uint8List> generatePdfReport(ActivityReportData data) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    // Title page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'HuntSphere Activity Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    data.activityName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Activity Details
            _buildSectionTitle('Activity Details'),
            pw.SizedBox(height: 10),
            _buildInfoRow('Join Code', data.joinCode),
            _buildInfoRow('Status', data.status.toUpperCase()),
            _buildInfoRow('Duration', '${data.totalDuration} minutes'),
            if (data.startedAt != null)
              _buildInfoRow('Started', dateFormat.format(data.startedAt!)),
            if (data.endedAt != null)
              _buildInfoRow('Ended', dateFormat.format(data.endedAt!)),
            if (data.actualDuration != null)
              _buildInfoRow('Actual Duration',
                  '${data.actualDuration!.inMinutes} minutes'),
            pw.SizedBox(height: 20),

            // Statistics
            _buildSectionTitle('Statistics'),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildStatBox('Teams', data.teams.length.toString()),
                _buildStatBox('Participants', data.totalParticipants.toString()),
                _buildStatBox('Checkpoints', data.checkpoints.length.toString()),
                _buildStatBox('Total Points', data.totalPoints.toString()),
              ],
            ),
            pw.SizedBox(height: 30),

            // Leaderboard
            _buildSectionTitle('Final Leaderboard'),
            pw.SizedBox(height: 10),
            _buildLeaderboardTable(data.teams),
          ],
        ),
      ),
    );

    // Team Details Page
    if (data.teams.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            _buildSectionTitle('Team Details'),
            pw.SizedBox(height: 20),
            ...data.teams.map((team) => _buildTeamDetailsWidget(team)),
          ],
        ),
      );
    }

    // Checkpoint Analysis Page
    if (data.checkpoints.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Checkpoint Analysis'),
              pw.SizedBox(height: 20),
              _buildCheckpointTable(data.checkpoints),
            ],
          ),
        ),
      );
    }

    // Footer on last page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              'Generated by HuntSphere on ${dateFormat.format(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue800,
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Text(value),
        ],
      ),
    );
  }

  pw.Widget _buildStatBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildLeaderboardTable(List<TeamReportData> teams) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue800),
          children: [
            _buildTableCell('Rank', isHeader: true),
            _buildTableCell('Team', isHeader: true),
            _buildTableCell('Points', isHeader: true),
            _buildTableCell('Checkpoints', isHeader: true),
            _buildTableCell('Members', isHeader: true),
          ],
        ),
        // Data rows
        ...teams.take(10).map((team) => pw.TableRow(
              children: [
                _buildTableCell('#${team.rank}'),
                _buildTableCell('${team.emoji ?? ""} ${team.teamName}'),
                _buildTableCell(team.totalPoints.toString()),
                _buildTableCell(team.checkpointsCompleted.toString()),
                _buildTableCell(team.participants.length.toString()),
              ],
            )),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : null,
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontSize: isHeader ? 11 : 10,
        ),
      ),
    );
  }

  pw.Widget _buildTeamDetailsWidget(TeamReportData team) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '#${team.rank} ${team.emoji ?? ""} ${team.teamName}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${team.totalPoints} pts',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.amber,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Members: ${team.participants.map((p) => p.name).join(", ")}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Checkpoints: ${team.checkpointsCompleted}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (team.finishedAt != null)
            pw.Text(
              'Finished: ${DateFormat('h:mm a').format(team.finishedAt!)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildCheckpointTable(List<CheckpointReportData> checkpoints) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue800),
          children: [
            _buildTableCell('#', isHeader: true),
            _buildTableCell('Checkpoint', isHeader: true),
            _buildTableCell('Tasks', isHeader: true),
            _buildTableCell('Location', isHeader: true),
          ],
        ),
        ...checkpoints.map((cp) => pw.TableRow(
              children: [
                _buildTableCell((cp.orderIndex + 1).toString()),
                _buildTableCell(cp.name),
                _buildTableCell(cp.tasksCount.toString()),
                _buildTableCell(
                    '${cp.latitude.toStringAsFixed(4)}, ${cp.longitude.toStringAsFixed(4)}'),
              ],
            )),
      ],
    );
  }

  /// Generate CSV report
  Future<String> generateCsvReport(ActivityReportData data) async {
    final rows = <List<dynamic>>[];

    // Header
    rows.add([
      'Rank',
      'Team Name',
      'Emoji',
      'Total Points',
      'Checkpoints Completed',
      'Participants',
      'Participant Names',
      'Finished At',
    ]);

    // Data
    for (final team in data.teams) {
      rows.add([
        team.rank,
        team.teamName,
        team.emoji ?? '',
        team.totalPoints,
        team.checkpointsCompleted,
        team.participants.length,
        team.participants.map((p) => p.name).join('; '),
        team.finishedAt?.toIso8601String() ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Save PDF to file and return path
  Future<String> savePdfToFile(Uint8List pdfBytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName.pdf');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  /// Save CSV to file and return path
  Future<String> saveCsvToFile(String csvContent, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName.csv');
    await file.writeAsString(csvContent);
    return file.path;
  }

  /// Share PDF report
  Future<void> sharePdf(Uint8List pdfBytes, String fileName) async {
    final path = await savePdfToFile(pdfBytes, fileName);
    await Share.shareXFiles([XFile(path)], text: 'HuntSphere Activity Report');
  }

  /// Share CSV report
  Future<void> shareCsv(String csvContent, String fileName) async {
    final path = await saveCsvToFile(csvContent, fileName);
    await Share.shareXFiles([XFile(path)], text: 'HuntSphere Leaderboard Data');
  }

  /// Print PDF report
  Future<void> printReport(Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'HuntSphere Report',
    );
  }

  /// Preview PDF report
  Future<void> previewReport(Uint8List pdfBytes) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: 'huntsphere_report.pdf');
  }
}
