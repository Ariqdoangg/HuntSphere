import 'package:flutter_test/flutter_test.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';

void main() {
  group('ActivityModel', () {
    group('constructor', () {
      test('creates activity with required fields', () {
        final activity = ActivityModel(
          name: 'Test Hunt',
          joinCode: 'ABC123',
          totalDurationMinutes: 60,
        );

        expect(activity.name, 'Test Hunt');
        expect(activity.joinCode, 'ABC123');
        expect(activity.totalDurationMinutes, 60);
        expect(activity.status, 'setup');
        expect(activity.id, isNull);
        expect(activity.startedAt, isNull);
        expect(activity.endedAt, isNull);
        expect(activity.createdAt, isNotNull);
      });

      test('creates activity with all fields', () {
        final now = DateTime.now();
        final activity = ActivityModel(
          id: 'test-id',
          name: 'Full Activity',
          joinCode: 'XYZ789',
          totalDurationMinutes: 120,
          status: 'active',
          startedAt: now,
          endedAt: now.add(const Duration(hours: 2)),
          createdAt: now,
        );

        expect(activity.id, 'test-id');
        expect(activity.status, 'active');
        expect(activity.startedAt, now);
        expect(activity.endedAt, now.add(const Duration(hours: 2)));
      });
    });

    group('fromJson', () {
      test('parses valid JSON correctly', () {
        final json = {
          'id': 'json-id',
          'name': 'JSON Activity',
          'join_code': 'JSON01',
          'total_duration_minutes': 90,
          'status': 'completed',
          'started_at': '2024-01-15T10:00:00.000Z',
          'ended_at': '2024-01-15T11:30:00.000Z',
          'created_at': '2024-01-15T09:00:00.000Z',
        };

        final activity = ActivityModel.fromJson(json);

        expect(activity.id, 'json-id');
        expect(activity.name, 'JSON Activity');
        expect(activity.joinCode, 'JSON01');
        expect(activity.totalDurationMinutes, 90);
        expect(activity.status, 'completed');
        expect(activity.startedAt, isNotNull);
        expect(activity.endedAt, isNotNull);
      });

      test('handles null optional fields', () {
        final json = {
          'id': 'test-id',
          'name': 'Minimal Activity',
          'join_code': 'MIN001',
          'total_duration_minutes': 30,
          'created_at': '2024-01-15T09:00:00.000Z',
        };

        final activity = ActivityModel.fromJson(json);

        expect(activity.status, 'setup');
        expect(activity.startedAt, isNull);
        expect(activity.endedAt, isNull);
      });
    });

    group('toJson', () {
      test('serializes to JSON correctly', () {
        final activity = ActivityModel(
          id: 'serialize-id',
          name: 'Serialize Test',
          joinCode: 'SER123',
          totalDurationMinutes: 45,
          status: 'active',
        );

        final json = activity.toJson();

        expect(json['id'], 'serialize-id');
        expect(json['name'], 'Serialize Test');
        expect(json['join_code'], 'SER123');
        expect(json['total_duration_minutes'], 45);
        expect(json['status'], 'active');
        expect(json['created_at'], isNotNull);
      });

      test('excludes null id from JSON', () {
        final activity = ActivityModel(
          name: 'No ID Activity',
          joinCode: 'NOID01',
          totalDurationMinutes: 30,
        );

        final json = activity.toJson();

        expect(json.containsKey('id'), false);
      });
    });

    group('copyWith', () {
      test('copies with updated fields', () {
        final original = ActivityModel(
          id: 'original-id',
          name: 'Original Name',
          joinCode: 'ORIG01',
          totalDurationMinutes: 60,
          status: 'setup',
        );

        final copied = original.copyWith(
          name: 'Updated Name',
          status: 'active',
        );

        expect(copied.id, 'original-id');
        expect(copied.name, 'Updated Name');
        expect(copied.joinCode, 'ORIG01');
        expect(copied.totalDurationMinutes, 60);
        expect(copied.status, 'active');
      });

      test('preserves original createdAt', () {
        final createdAt = DateTime(2024, 1, 1);
        final original = ActivityModel(
          name: 'Original',
          joinCode: 'ORIG01',
          totalDurationMinutes: 60,
          createdAt: createdAt,
        );

        final copied = original.copyWith(name: 'Copied');

        expect(copied.createdAt, createdAt);
      });
    });

    group('roundtrip', () {
      test('maintains data integrity through JSON conversion', () {
        final original = ActivityModel(
          id: 'roundtrip-id',
          name: 'Roundtrip Test',
          joinCode: 'ROUND1',
          totalDurationMinutes: 75,
          status: 'active',
          startedAt: DateTime(2024, 1, 15, 10, 0),
        );

        final json = original.toJson();
        final restored = ActivityModel.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.joinCode, original.joinCode);
        expect(restored.totalDurationMinutes, original.totalDurationMinutes);
        expect(restored.status, original.status);
      });
    });
  });
}
