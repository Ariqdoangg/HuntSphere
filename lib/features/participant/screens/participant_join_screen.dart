import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'selfie_capture_screen.dart';

class ParticipantJoinScreen extends StatefulWidget {
  const ParticipantJoinScreen({super.key});

  @override
  State<ParticipantJoinScreen> createState() => _ParticipantJoinScreenState();
}

class _ParticipantJoinScreenState extends State<ParticipantJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _joinActivity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final joinCode = _codeController.text.trim().toUpperCase();
      
      // Find activity by join code
      final activityData = await Supabase.instance.client
          .from('activities')
          .select()
          .eq('join_code', joinCode)
          .single();
      
      final activity = ActivityModel.fromJson(activityData);

      // Check activity status
      if (activity.status != 'setup' && activity.status != 'lobby') {
        throw Exception('This activity has already started or finished');
      }

      // Navigate to selfie capture
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelfieCaptureScreen(
              activity: activity,
              participantName: _nameController.text.trim(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('single')
                ? 'Invalid join code. Please check and try again.'
                : e.toString()),
            backgroundColor: Colors.red,
          ),
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    const Icon(
                      Icons.location_city,
                      size: 80,
                      color: Color(0xFF00D9FF),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '🎯 HuntSphere',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00D9FF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Join the Adventure',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Name Input
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Your Name',
                        hintText: 'e.g., Ahmad',
                        prefixIcon: const Icon(Icons.person, color: Color(0xFF00D9FF)),
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
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Join Code Input
                    TextFormField(
                      controller: _codeController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                        UpperCaseTextFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Join Code',
                        hintText: 'ABC123',
                        counterText: '',
                        prefixIcon: const Icon(Icons.key, color: Color(0xFF00D9FF)),
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter join code';
                        }
                        if (value.length != 6) {
                          return 'Join code must be 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF00D9FF), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Get the join code from your facilitator',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Join Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _joinActivity,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D9FF),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Text(
                                'Join Activity',
                                style: TextStyle(
                                  fontSize: 18,
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
        ),
      ),
    );
  }
}

// Helper to convert text to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
