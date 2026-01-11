class ActivityModel {
  final String? id;
  final String name;
  final String joinCode;
  final int totalDurationMinutes;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;

  ActivityModel({
    this.id,
    required this.name,
    required this.joinCode,
    required this.totalDurationMinutes,
    this.status = 'setup',
    this.startedAt,
    this.endedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'],
      name: json['name'],
      joinCode: json['join_code'],
      totalDurationMinutes: json['total_duration_minutes'],
      status: json['status'] ?? 'setup',
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      endedAt:
          json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'join_code': joinCode,
      'total_duration_minutes': totalDurationMinutes,
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  ActivityModel copyWith({
    String? id,
    String? name,
    String? joinCode,
    int? totalDurationMinutes,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      joinCode: joinCode ?? this.joinCode,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt,
    );
  }
}
