class ParticipantModel {
  final String? id;
  final String activityId;
  final String name;
  final String? teamId;
  final String? selfieUrl;
  final DateTime? joinedAt;
  final Map<String, dynamic>? deviceInfo;

  ParticipantModel({
    this.id,
    required this.activityId,
    required this.name,
    this.teamId,
    this.selfieUrl,
    this.joinedAt,
    this.deviceInfo,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      id: json['id'],
      activityId: json['activity_id'],
      name: json['name'],
      teamId: json['team_id'],
      selfieUrl: json['selfie_url'],
      joinedAt: json['joined_at'] != null 
          ? DateTime.parse(json['joined_at']) 
          : null,
      deviceInfo: json['device_info'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'activity_id': activityId,
      'name': name,
      if (teamId != null) 'team_id': teamId,
      if (selfieUrl != null) 'selfie_url': selfieUrl,
      if (joinedAt != null) 'joined_at': joinedAt!.toIso8601String(),
      if (deviceInfo != null) 'device_info': deviceInfo,
    };
  }
}
