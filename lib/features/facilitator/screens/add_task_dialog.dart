import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'package:huntsphere/features/shared/models/task_model.dart';
import 'package:huntsphere/services/supabase_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';

class AddTaskDialog extends StatefulWidget {
  final String checkpointId;

  const AddTaskDialog({
    super.key,
    required this.checkpointId,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'photo';
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pointsController = TextEditingController(text: '100');

  // Quiz fields
  final _quizQuestionController = TextEditingController();
  final _option1Controller = TextEditingController();
  final _option2Controller = TextEditingController();
  final _option3Controller = TextEditingController();
  final _option4Controller = TextEditingController();
  int _correctAnswerIndex = 0;

  // QR Code field
  final _qrValueController = TextEditingController();

  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    _quizQuestionController.dispose();
    _option1Controller.dispose();
    _option2Controller.dispose();
    _option3Controller.dispose();
    _option4Controller.dispose();
    _qrValueController.dispose();
    super.dispose();
  }

  String _generateRandomQRCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate quiz
    if (_selectedType == 'quiz') {
      final options = [
        _option1Controller.text.trim(),
        _option2Controller.text.trim(),
        _option3Controller.text.trim(),
        _option4Controller.text.trim(),
      ];

      if (options.any((opt) => opt.isEmpty)) {
        _showSnackBar('Please fill all 4 quiz options', isError: true);
        return;
      }
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      List<String>? quizOptions;
      String? correctAnswer;

      if (_selectedType == 'quiz') {
        quizOptions = [
          _option1Controller.text.trim(),
          _option2Controller.text.trim(),
          _option3Controller.text.trim(),
          _option4Controller.text.trim(),
        ];
        correctAnswer = quizOptions[_correctAnswerIndex];
      }

      final task = TaskModel(
        checkpointId: widget.checkpointId,
        taskType: _selectedType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        points: int.parse(_pointsController.text),
        quizQuestion:
            _selectedType == 'quiz' ? _quizQuestionController.text.trim() : null,
        quizOptions: quizOptions,
        quizCorrectAnswer: correctAnswer,
        qrCodeValue:
            _selectedType == 'qr_code' ? _qrValueController.text.trim() : null,
        requiresApproval: _selectedType == 'photo' || _selectedType == 'video',
      );

      final created = await SupabaseService.createTask(task);

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, created);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        margin: const EdgeInsets.all(AppTheme.spacingM),
      ),
    );
  }

  Color _getTaskTypeColor(String type) {
    switch (type) {
      case 'photo':
        return AppTheme.primaryPurple;
      case 'video':
        return AppTheme.error;
      case 'quiz':
        return AppTheme.success;
      case 'qr_code':
        return AppTheme.warning;
      default:
        return AppTheme.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(
              color: _getTaskTypeColor(_selectedType).withValues(alpha: 0.3),
            ),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: AppTheme.spacingL),

                  // Task Type Selector
                  _buildTaskTypeSelector(),
                  const SizedBox(height: AppTheme.spacingL),

                  // Common Fields
                  _buildCommonFields(),
                  const SizedBox(height: AppTheme.spacingL),

                  // Type-specific fields
                  if (_selectedType == 'quiz') ..._buildQuizFields(),
                  if (_selectedType == 'qr_code') ..._buildQRFields(),

                  const SizedBox(height: AppTheme.spacingL),

                  // Save Button
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: const Icon(
            Icons.add_task_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GradientText(
                text: 'Add Task',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                gradient: LinearGradient(
                  colors: [AppTheme.accent, AppTheme.primaryPurple],
                ),
              ),
              Text(
                'Create a new task for this checkpoint',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: const Icon(Icons.close, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildTaskTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'TASK TYPE',
              style: AppTheme.labelSmall.copyWith(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),
        Wrap(
          spacing: AppTheme.spacingS,
          runSpacing: AppTheme.spacingS,
          children: [
            _TaskTypeChip(
              label: 'Photo',
              icon: Icons.photo_camera_rounded,
              color: AppTheme.primaryPurple,
              isSelected: _selectedType == 'photo',
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedType = 'photo');
              },
            ),
            _TaskTypeChip(
              label: 'Video',
              icon: Icons.videocam_rounded,
              color: AppTheme.error,
              isSelected: _selectedType == 'video',
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedType = 'video');
              },
            ),
            _TaskTypeChip(
              label: 'Quiz',
              icon: Icons.quiz_rounded,
              color: AppTheme.success,
              isSelected: _selectedType == 'quiz',
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedType = 'quiz');
              },
            ),
            _TaskTypeChip(
              label: 'QR Code',
              icon: Icons.qr_code_rounded,
              color: AppTheme.warning,
              isSelected: _selectedType == 'qr_code',
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedType = 'qr_code');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommonFields() {
    return Column(
      children: [
        // Task Title
        EliteTextField(
          controller: _titleController,
          label: 'Task Title',
          hint: _selectedType == 'photo'
              ? 'e.g., Take a group selfie'
              : _selectedType == 'quiz'
                  ? 'e.g., History Quiz'
                  : _selectedType == 'qr_code'
                      ? 'e.g., Scan the hidden QR code'
                      : 'e.g., Record a team cheer',
          prefixIcon: Icons.title_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: AppTheme.spacingM),

        // Description
        EliteTextField(
          controller: _descriptionController,
          label: 'Description (optional)',
          hint: 'Provide instructions...',
          prefixIcon: Icons.description_rounded,
          maxLines: 2,
        ),
        const SizedBox(height: AppTheme.spacingM),

        // Points
        EliteTextField(
          controller: _pointsController,
          label: 'Points',
          hint: 'Enter points',
          prefixIcon: Icons.star_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  List<Widget> _buildQuizFields() {
    return [
      Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.success.withValues(alpha: 0.15),
              AppTheme.success.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: const Icon(Icons.quiz_rounded,
                      color: AppTheme.success, size: 20),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Quiz Configuration',
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.success,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Question
            TextFormField(
              controller: _quizQuestionController,
              style: AppTheme.bodyMedium,
              decoration: AppTheme.inputDecoration(
                label: 'Question',
                hint: 'e.g., What year was UPSI founded?',
                prefixIcon: Icons.help_outline_rounded,
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppTheme.spacingM),

            Text(
              'Answer Options (Select the correct one)',
              style: AppTheme.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),

            // Options
            _buildQuizOption(0, _option1Controller, 'Option 1', 'e.g., 1997'),
            _buildQuizOption(1, _option2Controller, 'Option 2', 'e.g., 1998'),
            _buildQuizOption(2, _option3Controller, 'Option 3', 'e.g., 1999'),
            _buildQuizOption(3, _option4Controller, 'Option 4', 'e.g., 2000'),
          ],
        ),
      ),
    ];
  }

  Widget _buildQuizOption(
    int index,
    TextEditingController controller,
    String label,
    String hint,
  ) {
    final isSelected = _correctAnswerIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _correctAnswerIndex = index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.success
                    : AppTheme.backgroundCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.success
                      : AppTheme.textMuted.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: TextFormField(
              controller: controller,
              style: AppTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                labelStyle: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textMuted,
                ),
                hintStyle: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: isSelected
                    ? AppTheme.success.withValues(alpha: 0.1)
                    : AppTheme.backgroundCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: BorderSide(
                    color: isSelected
                        ? AppTheme.success
                        : AppTheme.textMuted.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: BorderSide(
                    color: isSelected
                        ? AppTheme.success
                        : AppTheme.textMuted.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: BorderSide(
                    color: isSelected ? AppTheme.success : AppTheme.accent,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQRFields() {
    return [
      Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.warning.withValues(alpha: 0.15),
              AppTheme.warning.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: const Icon(Icons.qr_code_rounded,
                      color: AppTheme.warning, size: 20),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'QR Code Configuration',
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.warning,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qrValueController,
                    style: AppTheme.bodyMedium,
                    decoration: AppTheme.inputDecoration(
                      label: 'QR Code Text/Value',
                      hint: 'Enter text or URL',
                      prefixIcon: Icons.text_fields_rounded,
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    onChanged: (v) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.warning,
                        AppTheme.warning.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.warning.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _qrValueController.text = _generateRandomQRCode();
                        });
                      },
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS + 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.casino_rounded,
                                color: Colors.black, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'Random',
                              style: AppTheme.labelMedium.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_qrValueController.text.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingM),
              Divider(color: AppTheme.warning.withValues(alpha: 0.3)),
              const SizedBox(height: AppTheme.spacingM),

              Text(
                'QR Code Preview',
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),

              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.warning.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _qrValueController.text,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),

              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                  ),
                  child: Text(
                    'Value: ${_qrValueController.text}',
                    style: AppTheme.labelSmall.copyWith(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),

              const EliteInfoBanner(
                message:
                    'Print this QR code and place it at the checkpoint location',
                icon: Icons.lightbulb_outline_rounded,
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _buildSaveButton() {
    return EliteButton(
      label: 'Save Task',
      icon: Icons.save_rounded,
      onPressed: _isLoading ? null : _saveTask,
      isLoading: _isLoading,
    );
  }
}

class _TaskTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TaskTypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withValues(alpha: 0.7),
                  ],
                )
              : null,
          color: isSelected ? null : AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: isSelected ? color : AppTheme.textMuted.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.textMuted,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
