import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/services/connectivity_service.dart';
import 'package:huntsphere/services/auth_service.dart';
import 'package:huntsphere/services/activity_service.dart';
import 'package:huntsphere/services/team_service.dart';
import 'package:huntsphere/services/realtime_service.dart';
import 'package:huntsphere/services/cache_service.dart';
import 'package:huntsphere/services/notification_service.dart';
import 'package:huntsphere/services/report_service.dart';

/// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Connectivity service provider (singleton)
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Cache service provider
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  return AuthService(client, cache);
});

/// Activity service provider
final activityServiceProvider = Provider<ActivityService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  return ActivityService(client, cache);
});

/// Team service provider
final teamServiceProvider = Provider<TeamService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  return TeamService(client, cache);
});

/// Realtime service provider
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return RealtimeService(client);
});

/// Current user stream provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
    data: (state) => state.session?.user,
  );
});

/// Connectivity state provider
final connectivityStateProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

/// Is online provider (synchronous access)
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityStateProvider);
  return connectivity.whenOrNull(data: (isOnline) => isOnline) ??
         ref.read(connectivityServiceProvider).isOnline;
});

/// Notification service provider (singleton)
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Report service provider
final reportServiceProvider = Provider<ReportService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ReportService(client);
});
