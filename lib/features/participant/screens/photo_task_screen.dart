import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoTaskScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final String teamId;
  final String checkpointName;

  const PhotoTaskScreen({
    super.key,
    required this.task,
    required this.teamId,
    required this.checkpointName,
  });

  @override
  State<PhotoTaskScreen> createState() => _PhotoTaskScreenState();
}

class _PhotoTaskScreenState extends State<PhotoTaskScreen> {
  File? _image;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _image = File(photo.path);
        });
      }
    } catch (e) {
      _showError('Error taking photo: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _image = File(photo.path);
        });
      }
    } catch (e) {
      _showError('Error picking photo: $e');
    }
  }

  Future<void> _submitPhoto() async {
    if (_image == null) {
      _showError('Please take a photo first');
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Upload to Supabase Storage
      final fileName =
          'team_${widget.teamId}_task_${widget.task['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final bytes = await _image!.readAsBytes();
      
      await Supabase.instance.client.storage
          .from('task-photos')
          .uploadBinary(fileName, bytes);

      final photoUrl = Supabase.instance.client.storage
          .from('task-photos')
          .getPublicUrl(fileName);

      // Save submission
      await Supabase.instance.client.from('task_submissions').insert({
        'task_id': widget.task['id'],
        'team_id': widget.teamId,
        'participant_id': Supabase.instance.client.auth.currentUser?.id,
        'submission_type': 'photo',
        'photo_url': photoUrl,
        'status': 'pending',
      });

      if (mounted) {
        Navigator.pop(context);
        _showSuccess('Photo submitted! Waiting for facilitator review.');
      }
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      setState(() => _isUploading = false);
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task['title'] ?? 'Photo Task'),
        backgroundColor: const Color(0xFF0A1628),
      ),
      backgroundColor: const Color(0xFF0A1628),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Task description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF00D9FF)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.task['description'] ?? 'Take a team photo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
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
            const SizedBox(height: 32),

            // Photo preview
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white24,
                    width: 2,
                  ),
                ),
                child: _image == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              color: Colors.white24,
                              size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No photo taken yet',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _image!,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00D9FF),
                      side: const BorderSide(color: Color(0xFF00D9FF)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00D9FF),
                      side: const BorderSide(color: Color(0xFF00D9FF)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Submit button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isUploading || _image == null ? null : _submitPhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Text(
                        'Submit Photo',
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
    );
  }
}
