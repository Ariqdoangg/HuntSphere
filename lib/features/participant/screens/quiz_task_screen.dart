import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizTaskScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final String teamId;

  const QuizTaskScreen({
    super.key,
    required this.task,
    required this.teamId,
  });

  @override
  State<QuizTaskScreen> createState() => _QuizTaskScreenState();
}

class _QuizTaskScreenState extends State<QuizTaskScreen> {
  final TextEditingController _answerController = TextEditingController();
  bool _isSubmitting = false;
  bool _isCorrect = false;
  bool _hasSubmitted = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    
    if (answer.isEmpty) {
      _showError('Please enter an answer');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Check if answer is correct
      final correctAnswer = widget.task['quiz_answer']?.toString().trim().toLowerCase() ?? '';
      final userAnswer = answer.toLowerCase();
      final isCorrect = userAnswer == correctAnswer;

      // Save submission
      await Supabase.instance.client.from('task_submissions').insert({
        'task_id': widget.task['id'],
        'team_id': widget.teamId,
        'participant_id': Supabase.instance.client.auth.currentUser?.id,
        'submission_type': 'quiz',
        'quiz_answer': answer,
        'status': isCorrect ? 'approved' : 'rejected',
        'points_awarded': isCorrect ? widget.task['points'] : 0,
      });

      setState(() {
        _hasSubmitted = true;
        _isCorrect = isCorrect;
      });

      if (isCorrect) {
        _showSuccess('Correct! You earned ${widget.task['points']} points!');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        _showError('Incorrect answer. Try again!');
      }
    } catch (e) {
      _showError('Submission failed: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task['title'] ?? 'Quiz Task'),
        backgroundColor: const Color(0xFF0A1628),
      ),
      backgroundColor: const Color(0xFF0A1628),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Task info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.quiz,
                      color: Colors.purple,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quiz Question',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.stars, color: Colors.amber, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.task['points']} points',
                              style: const TextStyle(
                                color: Color(0xFF00D9FF),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Question
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00D9FF).withValues(alpha: 0.1),
                    Colors.purple.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                widget.task['quiz_question'] ?? widget.task['description'] ?? 'Answer the question',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Answer input
            TextField(
              controller: _answerController,
              enabled: !_isSubmitting && !(_hasSubmitted && _isCorrect),
              decoration: InputDecoration(
                labelText: 'Your Answer',
                hintText: 'Type your answer here...',
                prefixIcon: const Icon(Icons.edit, color: Color(0xFF00D9FF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF00D9FF),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFF1A2332),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const Spacer(),

            // Submit button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting || (_hasSubmitted && _isCorrect)
                    ? null
                    : _submitAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : Text(
                        _hasSubmitted && _isCorrect ? 'Correct! ✓' : 'Submit Answer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
