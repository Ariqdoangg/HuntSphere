import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'photo_viewer_screen.dart';

class PhotoGalleryScreen extends StatefulWidget {
  final String activityId;
  final String activityName;

  const PhotoGalleryScreen({
    super.key,
    required this.activityId,
    required this.activityName,
  });

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = true;
  String _filter = 'all'; // 'all', 'by_checkpoint', 'by_team'

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Query all approved photo submissions for this activity
      final response = await supabase
          .from('task_submissions')
          .select('''
            id,
            photo_url,
            submitted_at,
            teams!inner(id, team_name, emoji, activity_id),
            tasks!inner(id, title, checkpoint_id),
            checkpoints!tasks(id, name, sequence_order)
          ''')
          .eq('submission_type', 'photo')
          .eq('status', 'approved')
          .eq('teams.activity_id', widget.activityId);

      setState(() {
        _photos = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading photos: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text('${widget.activityName} - Photo Gallery'),
        backgroundColor: AppTheme.backgroundElevated,
        actions: [
          // Filter options (future enhancement)
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Photos')),
              const PopupMenuItem(value: 'by_checkpoint', child: Text('By Checkpoint')),
              const PopupMenuItem(value: 'by_team', child: Text('By Team')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No photos yet', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    final photo = _photos[index];
                    return _buildPhotoCard(photo);
                  },
                ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo) {
    final team = photo['teams'] as Map<String, dynamic>;
    final checkpoints = photo['checkpoints'] as List<dynamic>;
    final checkpoint = checkpoints.isNotEmpty ? checkpoints[0] as Map<String, dynamic> : {};

    return GestureDetector(
      onTap: () => _openPhotoViewer(photo),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: AppTheme.backgroundCard,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo
            CachedNetworkImage(
              imageUrl: photo['photo_url'],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade800,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey.shade800,
                child: const Icon(Icons.broken_image, color: Colors.white54),
              ),
            ),

            // Team label overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${team['emoji'] ?? '👥'} ${team['team_name'] ?? 'Team'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (checkpoint.isNotEmpty)
                      Text(
                        checkpoint['name'] ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPhotoViewer(Map<String, dynamic> photo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(photo: photo),
      ),
    );
  }
}
