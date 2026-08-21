import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

late Database db;
final _rng = Random.secure();

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;

  db = sqlite3.open('licenses.db');
  _initDatabase();

  final router = Router()
    ..get('/', _adminDashboardHandler)
    ..get('/api/health', _healthHandler)
    ..post('/api/activate', _activateHandler)
    ..post('/api/verify', _verifyHandler)
    ..post('/api/renew', _renewHandler)
    ..post('/api/admin/generate', _generateCodeHandler)
    ..get('/api/admin/licenses', _listLicensesHandler);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('License server running on http://${server.address.host}:${server.port}');
}

void _initDatabase() {
  db.execute('''
    CREATE TABLE IF NOT EXISTS licenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      license_key TEXT UNIQUE NOT NULL,
      plan TEXT NOT NULL DEFAULT 'monthly',
      device_id TEXT,
      activated_at INTEGER,
      expires_at INTEGER,
      is_active INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL,
      created_by TEXT DEFAULT 'admin'
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS activation_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      license_key TEXT NOT NULL,
      device_id TEXT NOT NULL,
      action TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      ip_address TEXT
    )
  ''');

  print('Database initialized');
}

Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        });
      }
      final response = await innerHandler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
      });
    };
  };
}

bool _checkAdminAuth(Request request) {
  final auth = request.headers['Authorization'];
  return auth == 'Bearer ADMIN_SECRET_KEY_CHANGE_ME';
}

Response _healthHandler(Request request) {
  return Response.ok(jsonEncode({'status': 'ok', 'version': '1.0.0'}),
      headers: {'Content-Type': 'application/json'});
}

Response _adminDashboardHandler(Request request) {
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  final html = File('$scriptDir/dashboard.html').readAsStringSync();
  return Response.ok(html, headers: {'Content-Type': 'text/html; charset=utf-8'});
}

Future<Response> _generateCodeHandler(Request request) async {
  if (!_checkAdminAuth(request)) {
    return Response.forbidden(jsonEncode({'error': 'Unauthorized'}),
        headers: {'Content-Type': 'application/json'});
  }

  final body = jsonDecode(await request.readAsString());
  final count = body['count'] as int? ?? 1;
  final plan = body['plan'] as String? ?? 'monthly';

  final codes = <Map<String, dynamic>>[];
  final now = DateTime.now().millisecondsSinceEpoch;

  for (int i = 0; i < count; i++) {
    final key = _generateLicenseKey();
    db.execute(
      'INSERT INTO licenses (license_key, plan, created_at) VALUES (?, ?, ?)',
      [key, plan, now],
    );
    codes.add({
      'license_key': key,
      'plan': plan,
    });
  }

  return Response.ok(
    jsonEncode({'codes': codes}),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> _activateHandler(Request request) async {
  final body = jsonDecode(await request.readAsString());
  final licenseKey = (body['license_key'] as String? ?? '').toUpperCase().trim();
  final deviceId = body['device_id'] as String? ?? '';

  if (licenseKey.isEmpty || deviceId.isEmpty) {
    return Response.badRequest(
      body: jsonEncode({'error': 'license_key and device_id are required'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final now = DateTime.now().millisecondsSinceEpoch;

  final results = db.select(
    'SELECT * FROM licenses WHERE license_key = ?',
    [licenseKey],
  );

  if (results.isEmpty) {
    _logAction(licenseKey, deviceId, 'activate_failed', request);
    return Response.ok(
      jsonEncode({'error': 'Invalid license key', 'valid': false}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final license = results.first;

  if (license['device_id'] != null &&
      (license['device_id'] as String).isNotEmpty &&
      license['device_id'] != deviceId &&
      license['is_active'] == 1) {
    _logAction(licenseKey, deviceId, 'activate_rejected_diff_device', request);
    return Response.ok(
      jsonEncode({
        'error': 'This key is activated on another device.',
        'valid': false,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final durationDays = license['plan'] == 'yearly' ? 365 : 30;
  final expiresAt = now + (durationDays * 24 * 60 * 60 * 1000);

  db.execute(
    'UPDATE licenses SET device_id = ?, activated_at = ?, expires_at = ?, is_active = 1 WHERE license_key = ?',
    [deviceId, now, expiresAt, licenseKey],
  );

  _logAction(licenseKey, deviceId, 'activated', request);

  return Response.ok(
    jsonEncode({
      'valid': true,
      'license_key': licenseKey,
      'plan': license['plan'],
      'activated_at': DateTime.fromMillisecondsSinceEpoch(now).toIso8601String(),
      'expires_at': DateTime.fromMillisecondsSinceEpoch(expiresAt).toIso8601String(),
      'duration_days': durationDays,
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> _verifyHandler(Request request) async {
  final body = jsonDecode(await request.readAsString());
  final licenseKey = (body['license_key'] as String? ?? '').toUpperCase().trim();
  final deviceId = body['device_id'] as String? ?? '';

  if (licenseKey.isEmpty) {
    return Response.ok(
      jsonEncode({'valid': false, 'error': 'license_key required'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final results = db.select(
    'SELECT * FROM licenses WHERE license_key = ?',
    [licenseKey],
  );

  if (results.isEmpty) {
    return Response.ok(
      jsonEncode({'valid': false, 'error': 'Key not found'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final license = results.first;

  if (license['is_active'] != 1) {
    return Response.ok(
      jsonEncode({'valid': false, 'error': 'Key not activated'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  if (license['device_id'] != deviceId) {
    return Response.ok(
      jsonEncode({'valid': false, 'error': 'Activated on another device'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final expiresAt = license['expires_at'] as int;
  final now = DateTime.now().millisecondsSinceEpoch;

  if (now > expiresAt) {
    final daysExpired = ((now - expiresAt) / (24 * 60 * 60 * 1000)).floor();
    return Response.ok(
      jsonEncode({
        'valid': false,
        'error': 'Subscription expired',
        'expired_days': daysExpired,
        'plan': license['plan'],
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final daysRemaining = ((expiresAt - now) / (24 * 60 * 60 * 1000)).floor();

  return Response.ok(
    jsonEncode({
      'valid': true,
      'license_key': licenseKey,
      'plan': license['plan'],
      'expires_at': DateTime.fromMillisecondsSinceEpoch(expiresAt).toIso8601String(),
      'days_remaining': daysRemaining,
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> _renewHandler(Request request) async {
  if (!_checkAdminAuth(request)) {
    return Response.forbidden(jsonEncode({'error': 'Unauthorized'}),
        headers: {'Content-Type': 'application/json'});
  }

  final body = jsonDecode(await request.readAsString());
  final licenseKey = (body['license_key'] as String? ?? '').toUpperCase().trim();
  final plan = body['plan'] as String? ?? 'monthly';

  final results = db.select(
    'SELECT * FROM licenses WHERE license_key = ?',
    [licenseKey],
  );

  if (results.isEmpty) {
    return Response.ok(
      jsonEncode({'error': 'Key not found'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final license = results.first;
  final durationDays = plan == 'yearly' ? 365 : 30;

  final now = DateTime.now().millisecondsSinceEpoch;
  final currentExpiry = (license['expires_at'] as int?) ?? now;
  final baseTime = currentExpiry > now ? currentExpiry : now;
  final newExpiry = baseTime + (durationDays * 24 * 60 * 60 * 1000);

  db.execute(
    'UPDATE licenses SET plan = ?, expires_at = ?, is_active = 1 WHERE license_key = ?',
    [plan, newExpiry, licenseKey],
  );

  return Response.ok(
    jsonEncode({
      'valid': true,
      'license_key': licenseKey,
      'plan': plan,
      'expires_at': DateTime.fromMillisecondsSinceEpoch(newExpiry).toIso8601String(),
      'duration_days': durationDays,
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> _listLicensesHandler(Request request) async {
  if (!_checkAdminAuth(request)) {
    return Response.forbidden(jsonEncode({'error': 'Unauthorized'}),
        headers: {'Content-Type': 'application/json'});
  }

  final results = db.select(
    'SELECT id, license_key, plan, device_id, activated_at, expires_at, is_active, created_at FROM licenses ORDER BY created_at DESC',
  );

  final now = DateTime.now().millisecondsSinceEpoch;
  final licenses = results.map((row) {
    final expiresAt = row['expires_at'] as int?;
    final isExpired = expiresAt != null && now > expiresAt;
    return {
      'id': row['id'],
      'license_key': row['license_key'],
      'plan': row['plan'],
      'device_id': row['device_id'] ?? 'Not activated',
      'is_active': row['is_active'] == 1 && !isExpired,
      'is_expired': isExpired,
      'created_at': row['created_at'],
      'activated_at': row['activated_at'],
      'expires_at': row['expires_at'],
    };
  }).toList();

  return Response.ok(
    jsonEncode({'licenses': licenses, 'total': licenses.length}),
    headers: {'Content-Type': 'application/json'},
  );
}

String _generateLicenseKey() {
  final random = List.generate(16, (_) => _randomChar());
  final segments = [
    random.sublist(0, 4).join(),
    random.sublist(4, 8).join(),
    random.sublist(8, 12).join(),
    random.sublist(12, 16).join(),
  ];
  return segments.join('-');
}

String _randomChar() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return chars[_rng.nextInt(chars.length)];
}

void _logAction(String key, String deviceId, String action, Request request) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final ip = request.headers['X-Forwarded-For'] ?? 'unknown';
  db.execute(
    'INSERT INTO activation_log (license_key, device_id, action, timestamp, ip_address) VALUES (?, ?, ?, ?, ?)',
    [key, deviceId, action, now, ip],
  );
}
