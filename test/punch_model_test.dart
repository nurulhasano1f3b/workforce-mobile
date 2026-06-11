import 'package:flutter_test/flutter_test.dart';
import 'package:workforce_app/models/punch.dart';

void main() {
  group('PunchType', () {
    test('fromServerValue round-trips all four types', () {
      for (final t in PunchType.values) {
        expect(PunchType.fromServerValue(t.serverValue), t);
      }
    });

    test('fromServerValue throws on unknown value', () {
      expect(() => PunchType.fromServerValue('nope'), throwsArgumentError);
    });
  });

  group('kValidNext — mirrors timecard/index.js VALID_NEXT', () {
    test('none → only in', () {
      expect(kValidNext['none'], ['in']);
    });
    test('in → unpaid_in or out', () {
      expect(kValidNext['in'], ['unpaid_in', 'out']);
    });
    test('unpaid_in → only unpaid_out', () {
      expect(kValidNext['unpaid_in'], ['unpaid_out']);
    });
    test('unpaid_out → unpaid_in or out', () {
      expect(kValidNext['unpaid_out'], ['unpaid_in', 'out']);
    });
    test('out → only in', () {
      expect(kValidNext['out'], ['in']);
    });
  });

  group('primaryNextPunch', () {
    test('returns clockIn when not clocked in', () {
      expect(primaryNextPunch('none'), PunchType.clockIn);
      expect(primaryNextPunch('out'), PunchType.clockIn);
    });
    test('returns clockOut when clocked in', () {
      expect(primaryNextPunch('in'), PunchType.clockOut);
    });
    test('returns breakEnd when on break', () {
      expect(primaryNextPunch('unpaid_in'), PunchType.breakEnd);
    });
    test('returns clockOut after break ended', () {
      expect(primaryNextPunch('unpaid_out'), PunchType.clockOut);
    });
  });

  group('hasSecondaryAction', () {
    test('true only when clocked in (lastType == in)', () {
      expect(hasSecondaryAction('in'), isTrue);
    });
    test('false for all other states', () {
      for (final t in ['none', 'out', 'unpaid_in', 'unpaid_out']) {
        expect(hasSecondaryAction(t), isFalse, reason: 'failed for $t');
      }
    });
  });

  group('Punch.fromSqlite / toSqliteInsert round-trip', () {
    test('pending punch survives SQLite round-trip', () {
      final now = DateTime.now();
      final original = Punch(
        localId: 42,
        type: PunchType.clockIn,
        deviceTs: now,
        pendingSync: true,
        isOffline: false,
      );
      final row = original.toSqliteInsert()
        ..['id'] = 42
        ..['pending_sync'] = 1
        ..['is_offline'] = 0;

      final restored = Punch.fromSqlite(row);
      expect(restored.localId, 42);
      expect(restored.type, PunchType.clockIn);
      expect(restored.deviceTs.toIso8601String(), now.toIso8601String());
      expect(restored.pendingSync, isTrue);
      expect(restored.isOffline, isFalse);
      expect(restored.serverId, isNull);
    });

    test('confirmed punch with flags round-trips', () {
      final now = DateTime.now();
      final row = {
        'id': 7,
        'type': 'in',
        'device_ts': now.toIso8601String(),
        'server_id': 99,
        'server_ts': now.toIso8601String(),
        'effective_ts': now.toIso8601String(),
        'flags': '{"irregular":"unexpected after \'out\'"}',
        'pending_sync': 0,
        'is_offline': 0,
      };
      final punch = Punch.fromSqlite(row);
      expect(punch.isIrregular, isTrue);
      expect(punch.serverId, 99);
      expect(punch.pendingSync, isFalse);
    });
  });

  group('Punch.fromServerResponse', () {
    test('maps 201 JSON fields correctly', () {
      final now = DateTime.now();
      final json = {
        'id': 55,
        'server_ts': now.toIso8601String(),
        'effective_ts': now.toIso8601String(),
        'flags': <String, dynamic>{},
      };
      final punch = Punch.fromServerResponse(
        localId: 3,
        type: PunchType.clockIn,
        deviceTs: now,
        json: json,
        isOffline: false,
      );
      expect(punch.serverId, 55);
      expect(punch.pendingSync, isFalse);
      expect(punch.isIrregular, isFalse);
      expect(punch.type, PunchType.clockIn);
    });
  });

  group('Punch.displayTs', () {
    test('returns deviceTs when effectiveTs is null (pending)', () {
      final now = DateTime.now();
      final p = Punch(localId: 1, type: PunchType.clockIn, deviceTs: now);
      expect(p.displayTs, now);
    });

    test('returns effectiveTs when set (confirmed)', () {
      final device = DateTime.now();
      final effective = device.add(const Duration(seconds: 10));
      final p = Punch(
        localId: 1,
        type: PunchType.clockIn,
        deviceTs: device,
        effectiveTs: effective,
      );
      expect(p.displayTs, effective);
    });
  });
}
