import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/features/shared/models/participant_model.dart';
import 'waiting_lobby_screen.dart';

class SelfieCaptureScreen extends StatefulWidget {
  final ActivityModel activity;
  final String participantName;

  const SelfieCaptureScreen({
    super.key,
    required this.activity,
    required this.participantName,
  });

  @override
  State<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _capturedImage;
  Uint8List? _imageBytes;
  bool _isUploading = false;

  Future<void> _takePicture() async {
    try {
      // On web, this will open file picker with camera option
      // On mobile, this will directly open camera
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _capturedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing camera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _retake() async {
    setState(() {
      _capturedImage = null;
      _imageBytes = null;
    });
  }

  Future<void> _submitAndJoin() async {
    if (_capturedImage == null || _imageBytes == null) return;

    setState(() => _isUploading = true);

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${widget.participantName}.jpg';
      
      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('selfies')
          .uploadBinary(fileName, _imageBytes!);

      // Get public URL
      final selfieUrl = Supabase.instance.client.storage
          .from('selfies')
          .getPublicUrl(fileName);

      // Create participant record
      final participantData = await Supabase.instance.client
          .from('participants')
          .insert({
            'activity_id': widget.activity.id,
            'name': widget.participantName,
            'selfie_url': selfieUrl,
            'joined_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final participant = ParticipantModel.fromJson(participantData);

      if (mounted) {
        // Navigate to waiting lobby
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingLobbyScreen(
              activity: widget.activity,
              participant: participant,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining activity: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('Take Selfie'),
        backgroundColor: const Color(0xFF0A1628),
      ),
      body: SafeArea(
        child: _capturedImage != null && _imageBytes != null
            ? _buildPreviewScreen()
            : _buildCaptureScreen(),
      ),
    );
  }

  Widget _buildCaptureScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
                border: Border.all(
                  color: const Color(0xFF00D9FF),
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 60,
                color: Color(0xFF00D9FF),
              ),
            ),
            const SizedBox(height: 32),

            // Title
            const Text(
              '📸 Take Your Selfie',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00D9FF),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Name Badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                widget.participantName,
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF00D9FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.face,
                    text: 'Show your face clearly',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.wb_sunny,
                    text: 'Make sure you have good lighting',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.camera,
                    text: 'Browser will ask for camera permission',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Capture Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.camera_alt, size: 24),
                label: const Text(
                  'Open Camera',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewScreen() {
    return Column(
      children: [
        // Preview Image
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                _imageBytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        // Status Message
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Looking good! Confirm to join the activity',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Action Buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Retake Button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _retake,
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Retake',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A2332),
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFF00D9FF),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Confirm Button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _submitAndJoin,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _isUploading ? 'Joining...' : 'Confirm',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D9FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00D9FF), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}
