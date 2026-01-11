class TaskModel {
  final String? id;
  final String checkpointId;
  final String taskType;
  final String title;
  final String? description;
  final int points;
  final String? quizQuestion;
  final List<String>? quizOptions;
  final String? quizCorrectAnswer;
  final String? qrCodeValue;
  final bool requiresApproval;
  final DateTime createdAt;

  TaskModel({
    this.id,
    required this.checkpointId,
    required this.taskType,
    required this.title,
    this.description,
    this.points = 100,
    this.quizQuestion,
    this.quizOptions,
    this.quizCorrectAnswer,
    this.qrCodeValue,
    this.requiresApproval = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      checkpointId: json['checkpoint_id'],
      taskType: json['task_type'],
      title: json['title'],
      description: json['description'],
      points: json['points'] ?? 100,
      quizQuestion: json['quiz_question'],
      quizOptions: json['quiz_options'] != null 
          ? List<String>.from(json['quiz_options']) 
          : null,
      quizCorrectAnswer: json['quiz_correct_answer'],
      qrCodeValue: json['qr_code_value'],
      requiresApproval: json['requires_approval'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'checkpoint_id': checkpointId,
      'task_type': taskType,
      'title': title,
      'description': description,
      'points': points,
      'quiz_question': quizQuestion,
      'quiz_options': quizOptions,
      'quiz_correct_answer': quizCorrectAnswer,
      'qr_code_value': qrCodeValue,
      'requires_approval': requiresApproval,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
