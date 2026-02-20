import 'package:flutter_test/flutter_test.dart';
import 'package:huntsphere/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('validateEmail', () {
      test('returns error for null value', () {
        expect(Validators.validateEmail(null), 'Email is required');
      });

      test('returns error for empty string', () {
        expect(Validators.validateEmail(''), 'Email is required');
        expect(Validators.validateEmail('   '), 'Email is required');
      });

      test('returns error for invalid email formats', () {
        expect(
          Validators.validateEmail('notanemail'),
          'Please enter a valid email address',
        );
        expect(
          Validators.validateEmail('@example.com'),
          'Please enter a valid email address',
        );
        expect(
          Validators.validateEmail('user@'),
          'Please enter a valid email address',
        );
        expect(
          Validators.validateEmail('user@.com'),
          'Please enter a valid email address',
        );
      });

      test('returns null for valid email formats', () {
        expect(Validators.validateEmail('user@example.com'), isNull);
        expect(Validators.validateEmail('user.name@example.com'), isNull);
        expect(Validators.validateEmail('user+tag@example.co.uk'), isNull);
        expect(Validators.validateEmail('user123@test.org'), isNull);
      });
    });

    group('validatePassword', () {
      test('returns error for null value', () {
        expect(Validators.validatePassword(null), 'Password is required');
      });

      test('returns error for empty string', () {
        expect(Validators.validatePassword(''), 'Password is required');
      });

      test('returns error for password shorter than minimum length', () {
        expect(
          Validators.validatePassword('12345'),
          'Password must be at least 6 characters',
        );
        expect(
          Validators.validatePassword('abc', minLength: 5),
          'Password must be at least 5 characters',
        );
      });

      test('returns null for valid passwords', () {
        expect(Validators.validatePassword('123456'), isNull);
        expect(Validators.validatePassword('password123'), isNull);
        expect(Validators.validatePassword('abcde', minLength: 5), isNull);
      });
    });

    group('validatePasswordConfirm', () {
      test('returns error for null value', () {
        expect(
          Validators.validatePasswordConfirm(null, 'password'),
          'Please confirm your password',
        );
      });

      test('returns error for empty string', () {
        expect(
          Validators.validatePasswordConfirm('', 'password'),
          'Please confirm your password',
        );
      });

      test('returns error when passwords do not match', () {
        expect(
          Validators.validatePasswordConfirm('password1', 'password2'),
          'Passwords do not match',
        );
      });

      test('returns null when passwords match', () {
        expect(
          Validators.validatePasswordConfirm('password123', 'password123'),
          isNull,
        );
      });
    });

    group('validateName', () {
      test('returns error for null value', () {
        expect(Validators.validateName(null), 'Name is required');
      });

      test('returns error for empty string', () {
        expect(Validators.validateName(''), 'Name is required');
        expect(Validators.validateName('   '), 'Name is required');
      });

      test('returns error for name shorter than minimum', () {
        expect(
          Validators.validateName('A'),
          'Name must be at least 2 characters',
        );
      });

      test('returns error for name with invalid characters', () {
        expect(
          Validators.validateName('Name@123'),
          'Name contains invalid characters',
        );
        expect(
          Validators.validateName('Name!'),
          'Name contains invalid characters',
        );
      });

      test('returns null for valid names', () {
        expect(Validators.validateName('John'), isNull);
        expect(Validators.validateName('John Doe'), isNull);
        expect(Validators.validateName("O'Brien"), isNull);
        expect(Validators.validateName('Mary-Jane'), isNull);
        expect(Validators.validateName('Team 1'), isNull);
      });

      test('uses custom field name in error message', () {
        expect(
          Validators.validateName(null, fieldName: 'Activity Name'),
          'Activity Name is required',
        );
      });
    });

    group('validateJoinCode', () {
      test('returns error for null value', () {
        expect(Validators.validateJoinCode(null), 'Join code is required');
      });

      test('returns error for empty string', () {
        expect(Validators.validateJoinCode(''), 'Join code is required');
      });

      test('returns error for codes not exactly 6 characters', () {
        expect(
          Validators.validateJoinCode('ABC12'),
          'Join code must be exactly 6 characters',
        );
        expect(
          Validators.validateJoinCode('ABC1234'),
          'Join code must be exactly 6 characters',
        );
      });

      test('returns error for codes with invalid characters', () {
        expect(
          Validators.validateJoinCode('ABC12!'),
          'Join code must contain only letters and numbers',
        );
        expect(
          Validators.validateJoinCode('ABC 12'),
          'Join code must contain only letters and numbers',
        );
      });

      test('returns null for valid join codes', () {
        expect(Validators.validateJoinCode('ABC123'), isNull);
        expect(Validators.validateJoinCode('abc123'), isNull);
        expect(Validators.validateJoinCode('123456'), isNull);
        expect(Validators.validateJoinCode('ABCDEF'), isNull);
      });
    });

    group('validateDuration', () {
      test('returns error for null value', () {
        expect(Validators.validateDuration(null), 'Duration is required');
      });

      test('returns error for empty string', () {
        expect(Validators.validateDuration(''), 'Duration is required');
      });

      test('returns error for non-numeric input', () {
        expect(
          Validators.validateDuration('abc'),
          'Please enter a valid number',
        );
        expect(
          Validators.validateDuration('12.5'),
          'Please enter a valid number',
        );
      });

      test('returns error for duration below minimum', () {
        expect(
          Validators.validateDuration('3'),
          'Duration must be at least 5 minutes',
        );
        expect(
          Validators.validateDuration('9', minMinutes: 10),
          'Duration must be at least 10 minutes',
        );
      });

      test('returns error for duration above maximum', () {
        expect(
          Validators.validateDuration('500'),
          'Duration cannot exceed 480 minutes',
        );
        expect(
          Validators.validateDuration('70', maxMinutes: 60),
          'Duration cannot exceed 60 minutes',
        );
      });

      test('returns null for valid durations', () {
        expect(Validators.validateDuration('30'), isNull);
        expect(Validators.validateDuration('60'), isNull);
        expect(Validators.validateDuration('480'), isNull);
      });
    });

    group('validateLatitude', () {
      test('returns error for null value', () {
        expect(Validators.validateLatitude(null), 'Latitude is required');
      });

      test('returns error for out of range values', () {
        expect(
          Validators.validateLatitude(-91.0),
          'Latitude must be between -90 and 90',
        );
        expect(
          Validators.validateLatitude(91.0),
          'Latitude must be between -90 and 90',
        );
      });

      test('returns null for valid latitudes', () {
        expect(Validators.validateLatitude(0.0), isNull);
        expect(Validators.validateLatitude(-90.0), isNull);
        expect(Validators.validateLatitude(90.0), isNull);
        expect(Validators.validateLatitude(3.1390), isNull);
      });
    });

    group('validateLongitude', () {
      test('returns error for null value', () {
        expect(Validators.validateLongitude(null), 'Longitude is required');
      });

      test('returns error for out of range values', () {
        expect(
          Validators.validateLongitude(-181.0),
          'Longitude must be between -180 and 180',
        );
        expect(
          Validators.validateLongitude(181.0),
          'Longitude must be between -180 and 180',
        );
      });

      test('returns null for valid longitudes', () {
        expect(Validators.validateLongitude(0.0), isNull);
        expect(Validators.validateLongitude(-180.0), isNull);
        expect(Validators.validateLongitude(180.0), isNull);
        expect(Validators.validateLongitude(101.6869), isNull);
      });
    });

    group('validateRadius', () {
      test('returns error for null value', () {
        expect(Validators.validateRadius(null), 'Radius is required');
      });

      test('returns error for non-numeric input', () {
        expect(
          Validators.validateRadius('abc'),
          'Please enter a valid number',
        );
      });

      test('returns error for radius below minimum', () {
        expect(
          Validators.validateRadius('3'),
          'Radius must be at least 5.0 meters',
        );
      });

      test('returns error for radius above maximum', () {
        expect(
          Validators.validateRadius('600'),
          'Radius cannot exceed 500.0 meters',
        );
      });

      test('returns null for valid radius', () {
        expect(Validators.validateRadius('20'), isNull);
        expect(Validators.validateRadius('50.5'), isNull);
        expect(Validators.validateRadius('500'), isNull);
      });
    });

    group('validatePoints', () {
      test('returns error for null value', () {
        expect(Validators.validatePoints(null), 'Points value is required');
      });

      test('returns error for non-numeric input', () {
        expect(
          Validators.validatePoints('abc'),
          'Please enter a valid number',
        );
      });

      test('returns error for points below minimum', () {
        expect(
          Validators.validatePoints('-5'),
          'Points must be at least 0',
        );
      });

      test('returns error for points above maximum', () {
        expect(
          Validators.validatePoints('1500'),
          'Points cannot exceed 1000',
        );
      });

      test('returns null for valid points', () {
        expect(Validators.validatePoints('0'), isNull);
        expect(Validators.validatePoints('100'), isNull);
        expect(Validators.validatePoints('1000'), isNull);
      });
    });

    group('validateRequired', () {
      test('returns error for null value', () {
        expect(Validators.validateRequired(null), 'Field is required');
      });

      test('returns error for empty string', () {
        expect(Validators.validateRequired(''), 'Field is required');
        expect(Validators.validateRequired('   '), 'Field is required');
      });

      test('returns null for non-empty value', () {
        expect(Validators.validateRequired('value'), isNull);
      });

      test('uses custom field name', () {
        expect(
          Validators.validateRequired(null, fieldName: 'Title'),
          'Title is required',
        );
      });
    });

    group('validateTextInput', () {
      test('returns error when required and empty', () {
        expect(
          Validators.validateTextInput(null, fieldName: 'Answer'),
          'Answer is required',
        );
        expect(
          Validators.validateTextInput('', fieldName: 'Answer'),
          'Answer is required',
        );
      });

      test('returns null when not required and empty', () {
        expect(
          Validators.validateTextInput(null, required: false),
          isNull,
        );
        expect(
          Validators.validateTextInput('', required: false),
          isNull,
        );
      });

      test('validates minimum length', () {
        expect(
          Validators.validateTextInput('ab', fieldName: 'Input', minLength: 3),
          'Input must be at least 3 characters',
        );
      });

      test('validates maximum length', () {
        expect(
          Validators.validateTextInput('abcdef', fieldName: 'Input', maxLength: 5),
          'Input must be less than 5 characters',
        );
      });

      test('returns null for valid input', () {
        expect(
          Validators.validateTextInput('valid input', minLength: 3, maxLength: 20),
          isNull,
        );
      });
    });
  });
}
