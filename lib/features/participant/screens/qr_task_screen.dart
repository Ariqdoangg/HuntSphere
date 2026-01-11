import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QRTaskScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final String teamId;

  const QRTaskScreen({
    super.key,
    required this.task,
    required this.teamId,
  });

  @override
  State<QRTaskScreen> createState() => _QRTaskScreenState();
}

class _QRTaskScreenState extends State<QRTaskScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onQRScanned(String qrCode) async {
    if (_isProcessing || _hasScanned) return;

    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    try {
      // Submit QR code
      await Supabase.instance.client.from('task_submissions').insert({
        'task_id': widget.task['id'],
        'team_id': widget.teamId,
        'participant_id': Supabase.instance.client.auth.currentUser?.id,
        'submission_type': 'qr',
        'qr_code': qrCode,
        'status': 'approved', // Auto-approve QR codes
        'points_awarded': widget.task['points'],
      });

      if (mounted) {
        _showSuccess('QR Code scanned! You earned ${widget.task['points']} points!');
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Submission failed: $e');
      setState(() {
        _hasScanned = false;
      });
    } finally {
      setState(() => _isProcessing = false);
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
        title: Text(widget.task['title'] ?? 'QR Task'),
        backgroundColor: const Color(0xFF0A1628),
      ),
      backgroundColor: const Color(0xFF0A1628),
      body: Column(
        children: [
          // Task info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF1A2332),
            child: Column(
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.green,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.task['description'] ?? 'Scan the QR code at this location',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stars, color: Colors.amber, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.task['points']} points',
                      style: const TextStyle(
                        color: Color(0xFF00D9FF),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scanner
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && !_hasScanned) {
                      final String? code = barcodes.first.rawValue;
                      if (code != null) {
                        _onQRScanned(code);
                      }
                    }
                  },
                ),
                
                // Scan frame overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _hasScanned ? Colors.green : const Color(0xFF00D9FF),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Instructions
                if (!_hasScanned)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Position the QR code within the frame',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // Processing indicator
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF00D9FF),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Processing...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Success overlay
                if (_hasScanned && !_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 80,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'QR Code Scanned!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF1A2332),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: _controller.toggleTorch,
                  icon: const Icon(Icons.flash_on),
                  color: Colors.white,
                  iconSize: 32,
                ),
                IconButton(
                  onPressed: _controller.switchCamera,
                  icon: const Icon(Icons.flip_camera_ios),
                  color: Colors.white,
                  iconSize: 32,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
