import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:huntsphere/features/shared/models/checkpoint_model.dart';
import 'package:huntsphere/services/supabase_service.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'package:huntsphere/core/utils/error_handler.dart';
import '../widgets/map_location_picker.dart';

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
  String? _selectedAddress;

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    // Get current radius for preview
    final radius = double.tryParse(_radiusController.text) ?? 20;

    // Get existing coordinates if any
    final existingLat = double.tryParse(_latController.text);
    final existingLng = double.tryParse(_lngController.text);

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPicker(
          initialLatitude: existingLat,
          initialLongitude: existingLng,
          radiusMeters: radius,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latController.text = result['latitude'].toStringAsFixed(6);
        _lngController.text = result['longitude'].toStringAsFixed(6);
        _selectedAddress = result['address'];
      });
    }
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
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _latController.text.isNotEmpty && _lngController.text.isNotEmpty;

    return Dialog(
      backgroundColor: AppTheme.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(AppTheme.spacingL),
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: const Icon(
                        Icons.add_location_alt,
                        color: AppTheme.primaryBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Checkpoint',
                            style: AppTheme.headingSmall,
                          ),
                          Text(
                            'Checkpoint #${widget.sequenceOrder}',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: AppTheme.textMuted,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingL),

                // Checkpoint Name
                EliteTextField(
                  controller: _nameController,
                  label: 'Checkpoint Name',
                  hint: 'e.g., Main Library',
                  prefixIcon: Icons.label_outline,
                  validator: (v) => v == null || v.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Location Picker Button
                InkWell(
                  onTap: _openMapPicker,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundInput,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border.all(
                        color: hasLocation
                            ? AppTheme.success.withValues(alpha: 0.5)
                            : AppTheme.backgroundElevated.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          ),
                          child: const Icon(
                            Icons.map,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasLocation ? 'Location Selected' : 'Select Location on Map',
                                style: AppTheme.bodyLarge.copyWith(
                                  fontWeight: hasLocation ? FontWeight.w600 : FontWeight.normal,
                                  color: hasLocation ? AppTheme.success : AppTheme.textPrimary,
                                ),
                              ),
                              if (hasLocation) ...[
                                const SizedBox(height: 4),
                                if (_selectedAddress != null)
                                  Text(
                                    _selectedAddress!,
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                Text(
                                  '${_latController.text}, ${_lngController.text}',
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.textMuted,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ] else
                                Text(
                                  'Tap to open map and pick a location',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          hasLocation ? Icons.edit_location_alt : Icons.arrow_forward_ios,
                          color: hasLocation ? AppTheme.success : AppTheme.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),

                // Or enter manually text
                Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.textMuted.withValues(alpha: 0.3))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
                      child: Text(
                        'or enter coordinates manually',
                        style: AppTheme.caption.copyWith(color: AppTheme.textMuted),
                      ),
                    ),
                    Expanded(child: Divider(color: AppTheme.textMuted.withValues(alpha: 0.3))),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),

                // Manual Lat/Lng inputs (collapsible or always visible)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        style: AppTheme.bodyMedium,
                        decoration: AppTheme.inputDecoration(
                          label: 'Latitude',
                          hint: '3.6891',
                          prefixIcon: Icons.north,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final lat = double.tryParse(v);
                          if (lat == null) return 'Invalid';
                          if (lat < -90 || lat > 90) return '-90 to 90';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        style: AppTheme.bodyMedium,
                        decoration: AppTheme.inputDecoration(
                          label: 'Longitude',
                          hint: '101.5088',
                          prefixIcon: Icons.east,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final lng = double.tryParse(v);
                          if (lng == null) return 'Invalid';
                          if (lng < -180 || lng > 180) return '-180 to 180';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),

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
                        style: AppTheme.bodyMedium,
                        decoration: AppTheme.inputDecoration(
                          label: 'Radius (m)',
                          hint: '20',
                          prefixIcon: Icons.circle_outlined,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final r = int.tryParse(v);
                          if (r == null || r < 5 || r > 100) return '5-100m';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: TextFormField(
                        controller: _pointsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: AppTheme.bodyMedium,
                        decoration: InputDecoration(
                          labelText: 'Points',
                          hintText: '50',
                          prefixIcon: const Icon(Icons.star, color: Colors.amber),
                          labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
                          hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textDisabled),
                          filled: true,
                          fillColor: AppTheme.backgroundInput,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM,
                            vertical: AppTheme.spacingM,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            borderSide: BorderSide(
                              color: AppTheme.backgroundElevated.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            borderSide: const BorderSide(
                              color: Colors.amber,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingL),

                // Save Button
                EliteButton(
                  label: 'Save Checkpoint',
                  icon: Icons.check,
                  onPressed: _isLoading ? null : _saveCheckpoint,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
