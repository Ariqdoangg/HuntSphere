import 'package:flutter_test/flutter_test.dart';
import 'package:huntsphere/features/shared/models/checkpoint_model.dart';

void main() {
  group('CheckpointModel', () {
    group('constructor', () {
      test('creates checkpoint with required fields', () {
        final checkpoint = CheckpointModel(
          activityId: 'activity-123',
          name: 'Start Point',
          latitude: 3.1390,
          longitude: 101.6869,
          sequenceOrder: 1,
        );

        expect(checkpoint.activityId, 'activity-123');
        expect(checkpoint.name, 'Start Point');
        expect(checkpoint.latitude, 3.1390);
        expect(checkpoint.longitude, 101.6869);
        expect(checkpoint.sequenceOrder, 1);
        expect(checkpoint.radiusMeters, 20); // default
        expect(checkpoint.arrivalPoints, 50); // default
        expect(checkpoint.id, isNull);
        expect(checkpoint.createdAt, isNotNull);
      });

      test('creates checkpoint with custom radius and points', () {
        final checkpoint = CheckpointModel(
          activityId: 'activity-123',
          name: 'Custom Point',
          latitude: 3.1390,
          longitude: 101.6869,
          sequenceOrder: 1,
          radiusMeters: 50,
          arrivalPoints: 100,
        );

        expect(checkpoint.radiusMeters, 50);
        expect(checkpoint.arrivalPoints, 100);
      });
    });

    group('fromJson', () {
      test('parses valid JSON correctly', () {
        final json = {
          'id': 'checkpoint-id',
          'activity_id': 'activity-123',
          'name': 'Library',
          'latitude': 3.1390,
          'longitude': 101.6869,
          'radius_meters': 30,
          'arrival_points': 75,
          'sequence_order': 2,
          'created_at': '2024-01-15T10:00:00.000Z',
        };

        final checkpoint = CheckpointModel.fromJson(json);

        expect(checkpoint.id, 'checkpoint-id');
        expect(checkpoint.activityId, 'activity-123');
        expect(checkpoint.name, 'Library');
        expect(checkpoint.latitude, 3.1390);
        expect(checkpoint.longitude, 101.6869);
        expect(checkpoint.radiusMeters, 30);
        expect(checkpoint.arrivalPoints, 75);
        expect(checkpoint.sequenceOrder, 2);
      });

      test('uses default values for missing optional fields', () {
        final json = {
          'id': 'test-id',
          'activity_id': 'activity-123',
          'name': 'Minimal Point',
          'latitude': 3.0,
          'longitude': 101.0,
          'sequence_order': 1,
          'created_at': '2024-01-15T10:00:00.000Z',
        };

        final checkpoint = CheckpointModel.fromJson(json);

        expect(checkpoint.radiusMeters, 20);
        expect(checkpoint.arrivalPoints, 50);
      });

      test('handles integer coordinates', () {
        final json = {
          'id': 'test-id',
          'activity_id': 'activity-123',
          'name': 'Int Coords',
          'latitude': 3,
          'longitude': 101,
          'sequence_order': 1,
          'created_at': '2024-01-15T10:00:00.000Z',
        };

        final checkpoint = CheckpointModel.fromJson(json);

        expect(checkpoint.latitude, 3.0);
        expect(checkpoint.longitude, 101.0);
      });
    });

    group('toJson', () {
      test('serializes to JSON correctly', () {
        final checkpoint = CheckpointModel(
          id: 'serialize-id',
          activityId: 'activity-123',
          name: 'Serialize Test',
          latitude: 3.1390,
          longitude: 101.6869,
          sequenceOrder: 1,
          radiusMeters: 25,
          arrivalPoints: 60,
        );

        final json = checkpoint.toJson();

        expect(json['id'], 'serialize-id');
        expect(json['activity_id'], 'activity-123');
        expect(json['name'], 'Serialize Test');
        expect(json['latitude'], 3.1390);
        expect(json['longitude'], 101.6869);
        expect(json['radius_meters'], 25);
        expect(json['arrival_points'], 60);
        expect(json['sequence_order'], 1);
        expect(json['created_at'], isNotNull);
      });

      test('excludes null id from JSON', () {
        final checkpoint = CheckpointModel(
          activityId: 'activity-123',
          name: 'No ID',
          latitude: 3.0,
          longitude: 101.0,
          sequenceOrder: 1,
        );

        final json = checkpoint.toJson();

        expect(json.containsKey('id'), false);
      });
    });

    group('copyWith', () {
      test('copies with updated fields', () {
        final original = CheckpointModel(
          id: 'original-id',
          activityId: 'activity-123',
          name: 'Original',
          latitude: 3.0,
          longitude: 101.0,
          sequenceOrder: 1,
          radiusMeters: 20,
          arrivalPoints: 50,
        );

        final copied = original.copyWith(
          name: 'Updated',
          radiusMeters: 40,
          sequenceOrder: 2,
        );

        expect(copied.id, 'original-id');
        expect(copied.activityId, 'activity-123');
        expect(copied.name, 'Updated');
        expect(copied.latitude, 3.0);
        expect(copied.longitude, 101.0);
        expect(copied.radiusMeters, 40);
        expect(copied.arrivalPoints, 50);
        expect(copied.sequenceOrder, 2);
      });

      test('can update coordinates', () {
        final original = CheckpointModel(
          activityId: 'activity-123',
          name: 'Move Me',
          latitude: 3.0,
          longitude: 101.0,
          sequenceOrder: 1,
        );

        final moved = original.copyWith(
          latitude: 4.0,
          longitude: 102.0,
        );

        expect(moved.latitude, 4.0);
        expect(moved.longitude, 102.0);
      });
    });

    group('coordinate validation', () {
      test('accepts valid latitude values', () {
        final checkpoint = CheckpointModel(
          activityId: 'activity-123',
          name: 'Valid Lat',
          latitude: -90.0,
          longitude: 0.0,
          sequenceOrder: 1,
        );
        expect(checkpoint.latitude, -90.0);

        final checkpoint2 = CheckpointModel(
          activityId: 'activity-123',
          name: 'Valid Lat',
          latitude: 90.0,
          longitude: 0.0,
          sequenceOrder: 1,
        );
        expect(checkpoint2.latitude, 90.0);
      });

      test('accepts valid longitude values', () {
        final checkpoint = CheckpointModel(
          activityId: 'activity-123',
          name: 'Valid Long',
          latitude: 0.0,
          longitude: -180.0,
          sequenceOrder: 1,
        );
        expect(checkpoint.longitude, -180.0);

        final checkpoint2 = CheckpointModel(
          activityId: 'activity-123',
          name: 'Valid Long',
          latitude: 0.0,
          longitude: 180.0,
          sequenceOrder: 1,
        );
        expect(checkpoint2.longitude, 180.0);
      });
    });

    group('roundtrip', () {
      test('maintains data integrity through JSON conversion', () {
        final original = CheckpointModel(
          id: 'roundtrip-id',
          activityId: 'activity-123',
          name: 'Roundtrip Test',
          latitude: 3.1390,
          longitude: 101.6869,
          sequenceOrder: 5,
          radiusMeters: 35,
          arrivalPoints: 80,
        );

        final json = original.toJson();
        final restored = CheckpointModel.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.activityId, original.activityId);
        expect(restored.name, original.name);
        expect(restored.latitude, original.latitude);
        expect(restored.longitude, original.longitude);
        expect(restored.sequenceOrder, original.sequenceOrder);
        expect(restored.radiusMeters, original.radiusMeters);
        expect(restored.arrivalPoints, original.arrivalPoints);
      });
    });
  });
}
