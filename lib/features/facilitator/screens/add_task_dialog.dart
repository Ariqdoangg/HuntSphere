import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _AddTaskDialogState extends State<AddTaskDialog> {
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

  @override
  void dispose() {
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
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all 4 quiz options')),
        );
        return;
      }
    }

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
        quizQuestion: _selectedType == 'quiz' ? _quizQuestionController.text.trim() : null,
        quizOptions: quizOptions,
        quizCorrectAnswer: correctAnswer,
        qrCodeValue: _selectedType == 'qr_code' ? _qrValueController.text.trim() : null,
        requiresApproval: _selectedType == 'photo' || _selectedType == 'video',
      );

      final created = await SupabaseService.createTask(task);
      
      if (mounted) {
        Navigator.pop(context, created);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A1628),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.add_task, color: Color(0xFF00D9FF), size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Add Task',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Task Type Selector
                const Text(
                  'Task Type',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TaskTypeChip(
                      label: 'Photo',
                      icon: Icons.photo_camera,
                      color: Colors.purple,
                      isSelected: _selectedType == 'photo',
                      onTap: () => setState(() => _selectedType = 'photo'),
                    ),
                    _TaskTypeChip(
                      label: 'Video',
                      icon: Icons.videocam,
                      color: Colors.red,
                      isSelected: _selectedType == 'video',
                      onTap: () => setState(() => _selectedType = 'video'),
                    ),
                    _TaskTypeChip(
                      label: 'Quiz',
                      icon: Icons.quiz,
                      color: Colors.green,
                      isSelected: _selectedType == 'quiz',
                      onTap: () => setState(() => _selectedType = 'quiz'),
                    ),
                    _TaskTypeChip(
                      label: 'QR Code',
                      icon: Icons.qr_code,
                      color: Colors.orange,
                      isSelected: _selectedType == 'qr_code',
                      onTap: () => setState(() => _selectedType = 'qr_code'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Common Fields
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    hintText: _selectedType == 'photo' 
                        ? 'e.g., Take a group selfie'
                        : _selectedType == 'quiz'
                        ? 'e.g., History Quiz'
                        : _selectedType == 'qr_code'
                        ? 'e.g., Scan the hidden QR code'
                        : 'e.g., Record a team cheer',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Provide instructions...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _pointsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Points',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.star, color: Colors.amber),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Type-specific fields
                if (_selectedType == 'quiz') ..._buildQuizFields(),
                if (_selectedType == 'qr_code') ..._buildQRFields(),

                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D9FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text(
                            'Save Task',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQuizFields() {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.quiz, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Quiz Configuration',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Question
            TextFormField(
              controller: _quizQuestionController,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'e.g., What year was UPSI founded?',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFF1A2332),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Answer Options (Select the correct one)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            
            // Option 1
            Row(
              children: [
                Radio<int>(
                  value: 0,
                  groupValue: _correctAnswerIndex,
                  onChanged: (v) => setState(() => _correctAnswerIndex = v!),
                  activeColor: Colors.green,
                ),
                Expanded(
                  child: TextFormField(
                    controller: _option1Controller,
                    decoration: InputDecoration(
                      labelText: 'Option 1',
                      hintText: 'e.g., 1997',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: _correctAnswerIndex == 0 
                          ? Colors.green.withValues(alpha: 0.1)
                          : const Color(0xFF1A2332),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Option 2
            Row(
              children: [
                Radio<int>(
                  value: 1,
                  groupValue: _correctAnswerIndex,
                  onChanged: (v) => setState(() => _correctAnswerIndex = v!),
                  activeColor: Colors.green,
                ),
                Expanded(
                  child: TextFormField(
                    controller: _option2Controller,
                    decoration: InputDecoration(
                      labelText: 'Option 2',
                      hintText: 'e.g., 1998',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: _correctAnswerIndex == 1 
                          ? Colors.green.withValues(alpha: 0.1)
                          : const Color(0xFF1A2332),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Option 3
            Row(
              children: [
                Radio<int>(
                  value: 2,
                  groupValue: _correctAnswerIndex,
                  onChanged: (v) => setState(() => _correctAnswerIndex = v!),
                  activeColor: Colors.green,
                ),
                Expanded(
                  child: TextFormField(
                    controller: _option3Controller,
                    decoration: InputDecoration(
                      labelText: 'Option 3',
                      hintText: 'e.g., 1999',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: _correctAnswerIndex == 2 
                          ? Colors.green.withValues(alpha: 0.1)
                          : const Color(0xFF1A2332),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Option 4
            Row(
              children: [
                Radio<int>(
                  value: 3,
                  groupValue: _correctAnswerIndex,
                  onChanged: (v) => setState(() => _correctAnswerIndex = v!),
                  activeColor: Colors.green,
                ),
                Expanded(
                  child: TextFormField(
                    controller: _option4Controller,
                    decoration: InputDecoration(
                      labelText: 'Option 4',
                      hintText: 'e.g., 2000',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: _correctAnswerIndex == 3 
                          ? Colors.green.withValues(alpha: 0.1)
                          : const Color(0xFF1A2332),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildQRFields() {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'QR Code Configuration',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qrValueController,
                    decoration: const InputDecoration(
                      labelText: 'QR Code Text/Value',
                      hintText: 'Enter text or URL',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFF1A2332),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _qrValueController.text = _generateRandomQRCode();
                    });
                  },
                  icon: const Icon(Icons.casino),
                  label: const Text('Random'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_qrValueController.text.isNotEmpty) ...[
              const Divider(color: Colors.orange),
              const SizedBox(height: 12),
              const Text(
                'QR Code Preview',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: _qrValueController.text,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Value: ${_qrValueController.text}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '💡 Tip: Print this QR code and place it at the checkpoint location',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    ];
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.3) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
