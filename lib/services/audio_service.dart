import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final Map<String, AudioPlayer> _players = {};
  bool _soundEnabled = true;

  // Preload all sound effects during app init
  Future<void> initialize() async {
    try {
      // Preload sounds into memory
      _players['checkpoint_complete'] = AudioPlayer();
      await _players['checkpoint_complete']!
          .setAsset('assets/sounds/checkpoint_complete.mp3');

      _players['activity_start'] = AudioPlayer();
      await _players['activity_start']!
          .setAsset('assets/sounds/activity_start.mp3');

      _players['activity_end'] = AudioPlayer();
      await _players['activity_end']!
          .setAsset('assets/sounds/activity_end.mp3');

      _players['photo_approved'] = AudioPlayer();
      await _players['photo_approved']!
          .setAsset('assets/sounds/photo_approved.mp3');

      _players['photo_rejected'] = AudioPlayer();
      await _players['photo_rejected']!
          .setAsset('assets/sounds/photo_rejected.mp3');

      print('✅ AudioService initialized with ${_players.length} sounds');
    } catch (e) {
      print('❌ AudioService initialization failed: $e');
    }
  }

  // Play a specific sound effect
  Future<void> play(String soundKey) async {
    if (!_soundEnabled) return;

    final player = _players[soundKey];
    if (player == null) {
      print('⚠️ Sound not found: $soundKey');
      return;
    }

    try {
      // Reset to beginning if already playing
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      print('❌ Error playing sound $soundKey: $e');
    }
  }

  // Enable/disable sounds (for settings)
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  bool get isSoundEnabled => _soundEnabled;

  // Cleanup
  Future<void> dispose() async {
    for (var player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}
