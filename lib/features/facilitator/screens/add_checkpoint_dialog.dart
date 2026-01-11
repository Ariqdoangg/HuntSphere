import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:huntsphere/features/shared/models/checkpoint_model.dart';
import 'package:huntsphere/services/supabase_service.dart';

class AddCheckpointDialog extends StatefulWidget {
  final String activityId;
  final int sequenceOrder;

  const AddCheckpointDialog({
    super.key,
    required this.activityId,
    required this.sequenceOrder,
  });

  @override
  State<AddCheckpointDialog> createState() => _AddCheckpointDialogState();
}

class _AddCheckpointDialogState extends State<AddCheckpointDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '20');
  final _pointsController = TextEditingController(text: '50');
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _saveCheckpoint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final checkpoint = CheckpointModel(
        activityId: widget.activityId,
        name: _nameController.text.trim(),
        latitude: double.parse(_latController.text),
        longitude: double.parse(_lngController.text),
        radiusMeters: int.parse(_radiusController.text),
        arrivalPoints: int.parse(_pointsController.text),
        sequenceOrder: widget.sequenceOrder,
      );

      final created = await SupabaseService.createCheckpoint(checkpoint);

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
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_location,
                        color: Color(0xFF00D9FF), size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Add Checkpoint',
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

                // Checkpoint Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Checkpoint Name',
                    hintText: 'e.g., Main Library',
                    prefixIcon:
                        const Icon(Icons.label, color: Color(0xFF00D9FF)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF00D9FF), width: 2),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Latitude
                TextFormField(
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    hintText: 'e.g., 3.6891',
                    prefixIcon:
                        const Icon(Icons.my_location, color: Color(0xFF00D9FF)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF00D9FF), width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final lat = double.tryParse(v);
                    if (lat == null) return 'Invalid number';
                    if (lat < -90 || lat > 90) return 'Must be -90 to 90';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Longitude
                TextFormField(
                  controller: _lngController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    hintText: 'e.g., 101.5088',
                    prefixIcon:
                        const Icon(Icons.place, color: Color(0xFF00D9FF)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF00D9FF), width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final lng = double.tryParse(v);
                    if (lng == null) return 'Invalid number';
                    if (lng < -180 || lng > 180) return 'Must be -180 to 180';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Radius & Points Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _radiusController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: 'Radius (m)',
                          prefixIcon: const Icon(Icons.circle_outlined,
                              color: Color(0xFF00D9FF)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF00D9FF), width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final r = int.tryParse(v);
                          if (r == null || r < 5 || r > 100) return '5-100';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pointsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: 'Points',
                          prefixIcon:
                              const Icon(Icons.star, color: Colors.amber),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF00D9FF), width: 2),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveCheckpoint,
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text(
                            'Save Checkpoint',
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
}
