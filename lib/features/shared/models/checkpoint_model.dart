class CheckpointModel {
  final String? id;
  final String activityId;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final int arrivalPoints;
  final int sequenceOrder;
  final DateTime createdAt;

  CheckpointModel({
    this.id,
    required this.activityId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 20,
    this.arrivalPoints = 50,
    required this.sequenceOrder,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CheckpointModel.fromJson(Map<String, dynamic> json) {
    return CheckpointModel(
      id: json['id'],
      activityId: json['activity_id'],
      name: json['name'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      radiusMeters: json['radius_meters'] ?? 20,
      arrivalPoints: json['arrival_points'] ?? 50,
      sequenceOrder: json['sequence_order'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'activity_id': activityId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'arrival_points': arrivalPoints,
      'sequence_order': sequenceOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CheckpointModel copyWith({
    String? id,
    String? activityId,
    String? name,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    int? arrivalPoints,
    int? sequenceOrder,
  }) {
    return CheckpointModel(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      arrivalPoints: arrivalPoints ?? this.arrivalPoints,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
      createdAt: createdAt,
    );
  }
}
