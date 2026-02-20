import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:huntsphere/core/theme/app_theme.dart';

class PhotoViewerScreen extends StatelessWidget {
  final Map<String, dynamic> photo;

  const PhotoViewerScreen({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    final team = photo['teams'] as Map<String, dynamic>;
    final checkpoints = photo['checkpoints'] as List<dynamic>;
    final checkpoint = checkpoints.isNotEmpty ? checkpoints[0] as Map<String, dynamic> : {};
    final task = photo['tasks'] as Map<String, dynamic>;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('${team['emoji'] ?? '👥'} ${team['team_name'] ?? 'Team'}'),
      ),
      body: Column(
        children: [
          // Full-screen photo with zoom
          Expanded(
            child: PhotoView(
              imageProvider: CachedNetworkImageProvider(photo['photo_url']),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          ),

          // Photo metadata
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.backgroundElevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (checkpoint.isNotEmpty)
                  Text(
                    checkpoint['name'] ?? 'Checkpoint',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  task['title'] ?? 'Photo Task',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  'Submitted: ${_formatTimestamp(photo['submitted_at'])}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    final dt = DateTime.parse(timestamp);
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
