class TeamModel {
  final String? id;
  final String activityId;
  final String? teamName;
  final String? color;
  final String? emoji;
  final int totalPoints;
  final DateTime? finishTime;
  final DateTime? createdAt;

  TeamModel({
    this.id,
    required this.activityId,
    this.teamName,
    this.color,
    this.emoji,
    this.totalPoints = 0,
    this.finishTime,
    this.createdAt,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id'],
      activityId: json['activity_id'],
      teamName: json['team_name'],
      color: json['color'],
      emoji: json['emoji'],
      totalPoints: json['total_points'] ?? 0,
      finishTime: json['finish_time'] != null 
          ? DateTime.parse(json['finish_time']) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'activity_id': activityId,
      if (teamName != null) 'team_name': teamName,
      if (color != null) 'color': color,
      if (emoji != null) 'emoji': emoji,
      'total_points': totalPoints,
      if (finishTime != null) 'finish_time': finishTime!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
