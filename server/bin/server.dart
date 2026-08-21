import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';

late PostgreSQLConnection db;
final _rng = Random.secure();

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final dbUrl = Platform.environment['DATABASE_URL'] ?? '';

  if (dbUrl.isEmpty) {
    print('ERROR: DATABASE_URL not set');
    exit(1);
  }

  final parsed = _parseDatabaseUrl(dbUrl);
  print('DB connection: host=${parsed.host} port=${parsed.port} db=${parsed.database} user=${parsed.username}');

  db = PostgreSQLConnection(
    parsed.host,
    parsed.port,
    parsed.database,
    username: parsed.username,
    password: parsed.password,
    useSSL: true,
    allowClearTextPassword: true,
  );

  for (int attempt = 1; attempt <= 10; attempt++) {
    try {
      await db.open();
      print('Database connected successfully on attempt $attempt');
      break;
    } catch (e) {
      print('Connection attempt $attempt failed: $e');
      if (attempt == 10) {
        print('ERROR: Could not connect to database after 10 attempts');
        exit(1);
      }
      await Future.delayed(Duration(seconds: 5 * attempt));
    }
  }

  await _initDatabase();

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

class _DbInfo {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  _DbInfo(this.host, this.port, this.database, this.username, this.password);
}

_DbInfo _parseDatabaseUrl(String url) {
  // Remove postgres:// or postgresql:// prefix
  var clean = url.replaceFirst(RegExp(r'^postgres(ql)?://'), '');

  // Find the last @ to split userInfo from hostInfo
  // Passwords may contain @ so we must split on the LAST @
  final lastAt = clean.lastIndexOf('@');
  if (lastAt < 0) {
    throw Exception('Invalid DATABASE_URL: no @ found');
  }

  final userInfo = clean.substring(0, lastAt);
  var hostPortDb = clean.substring(lastAt + 1);

  // Split host:port from /dbname?params
  var host = '';
  var port = 5432;
  var database = 'license_server';

  final slashIdx = hostPortDb.indexOf('/');
  final hostPort = slashIdx > 0 ? hostPortDb.substring(0, slashIdx) : hostPortDb;
  var pathPart = slashIdx > 0 ? hostPortDb.substring(slashIdx + 1) : '';

  // Parse host:port
  final colonIdx = hostPort.lastIndexOf(':');
  if (colonIdx > 0) {
    host = hostPort.substring(0, colonIdx);
    final portStr = hostPort.substring(colonIdx + 1);
    port = int.tryParse(portStr) ?? 5432;
  } else {
    host = hostPort;
    port = 5432;
  }

  // Parse database name (strip query params)
  if (pathPart.isNotEmpty) {
    final qIdx = pathPart.indexOf('?');
    database = qIdx > 0 ? pathPart.substring(0, qIdx) : pathPart;
  }

  // Parse username:password
  var username = '';
  var password = '';
  if (userInfo.isNotEmpty) {
    final colonIdx = userInfo.indexOf(':');
    if (colonIdx > 0) {
      username = Uri.decodeComponent(userInfo.substring(0, colonIdx));
      password = Uri.decodeComponent(userInfo.substring(colonIdx + 1));
    } else {
      username = Uri.decodeComponent(userInfo);
    }
  }

  return _DbInfo(host, port, database, username, password);
}

Future<void> _initDatabase() async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS licenses (
      id SERIAL PRIMARY KEY,
      license_key TEXT UNIQUE NOT NULL,
      plan TEXT NOT NULL DEFAULT 'monthly',
      company_name TEXT DEFAULT '',
      device_id TEXT,
      activated_at BIGINT,
      expires_at BIGINT,
      is_active INTEGER DEFAULT 0,
      created_at BIGINT NOT NULL,
      created_by TEXT DEFAULT 'admin'
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS activation_log (
      id SERIAL PRIMARY KEY,
      license_key TEXT NOT NULL,
      device_id TEXT NOT NULL,
      action TEXT NOT NULL,
      timestamp BIGINT NOT NULL,
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
  return Response.ok(jsonEncode({'status': 'ok', 'version': '2.0.0'}),
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
  final companyName = body['company_name'] as String? ?? '';

  final codes = <Map<String, dynamic>>[];
  final now = DateTime.now().millisecondsSinceEpoch;

  for (int i = 0; i < count; i++) {
    final key = _generateLicenseKey();
    await db.execute(
      'INSERT INTO licenses (license_key, plan, company_name, created_at) VALUES (@key, @plan, @company, @now)',
      substitutionValues: {'key': key, 'plan': plan, 'company': companyName, 'now': now},
    );
    codes.add({
      'license_key': key,
      'plan': plan,
      'company_name': companyName,
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
  final companyName = body['company_name'] as String? ?? '';

  print('Activate request: key=$licenseKey device=$deviceId company=$companyName');

  if (licenseKey.isEmpty || deviceId.isEmpty) {
    return Response.badRequest(
      body: jsonEncode({'error': 'license_key and device_id are required'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final now = DateTime.now().millisecondsSinceEpoch;

  final results = await db.mappedResultsQuery(
    'SELECT * FROM licenses WHERE license_key = @key',
    substitutionValues: {'key': licenseKey},
  );

  if (results.isEmpty) {
    print('Key not found in DB: $licenseKey');
    _logAction(licenseKey, deviceId, 'activate_failed', request);
    return Response.ok(
      jsonEncode({'error': 'Invalid license key', 'valid': false}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final license = results.first['licenses']!;

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

  final storedCompanyName = companyName.isNotEmpty ? companyName : (license['company_name'] as String? ?? '');

  await db.execute(
    'UPDATE licenses SET device_id = @did, activated_at = @at, expires_at = @exp, company_name = @company, is_active = 1 WHERE license_key = @key',
    substitutionValues: {'did': deviceId, 'at': now, 'exp': expiresAt, 'company': storedCompanyName, 'key': licenseKey},
  );

  _logAction(licenseKey, deviceId, 'activated', request);

  return Response.ok(
    jsonEncode({
      'valid': true,
      'license_key': licenseKey,
      'plan': license['plan'],
      'company_name': storedCompanyName,
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

  print('Verify request: key=$licenseKey device=$deviceId');

  if (licenseKey.isEmpty) {
    return Response.ok(
      jsonEncode({'valid': false, 'error': 'license_key required'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final results = await db.mappedResultsQuery(
    'SELECT * FROM licenses WHERE license_key = @key',
    substitutionValues: {'key': licenseKey},
  );

  if (results.isEmpty) {
    print('Verify: key not found: $licenseKey');
    return Response.ok(
      jsonEncode({'valid': false, 'error': 'Key not found'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final license = results.first['licenses']!;

  if (license['is_active'] != 1) {
    return Response.ok(
      jsonEncode({'valid': false, 'error': 'Key not activated'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  if (license['device_id'] != deviceId) {
    print('Verify: device mismatch. DB device=${license['device_id']} request device=$deviceId');
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
      'company_name': license['company_name'] ?? '',
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

  final results = await db.mappedResultsQuery(
    'SELECT * FROM licenses WHERE license_key = @key',
    substitutionValues: {'key': licenseKey},
  );

  if (results.isEmpty) {
    return Response.ok(
      jsonEncode({'error': 'Key not found'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final license = results.first['licenses']!;
  final durationDays = plan == 'yearly' ? 365 : 30;

  final now = DateTime.now().millisecondsSinceEpoch;
  final currentExpiry = (license['expires_at'] as int?) ?? now;
  final baseTime = currentExpiry > now ? currentExpiry : now;
  final newExpiry = baseTime + (durationDays * 24 * 60 * 60 * 1000);

  await db.execute(
    'UPDATE licenses SET plan = @plan, expires_at = @exp, is_active = 1 WHERE license_key = @key',
    substitutionValues: {'plan': plan, 'exp': newExpiry, 'key': licenseKey},
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

  final results = await db.mappedResultsQuery(
    'SELECT id, license_key, plan, company_name, device_id, activated_at, expires_at, is_active, created_at FROM licenses ORDER BY created_at DESC',
  );

  final now = DateTime.now().millisecondsSinceEpoch;
  final licenses = results.map((row) {
    final l = row['licenses']!;
    final expiresAt = l['expires_at'] as int?;
    final isExpired = expiresAt != null && now > expiresAt;
    return {
      'id': l['id'],
      'license_key': l['license_key'],
      'plan': l['plan'],
      'company_name': l['company_name'] ?? '',
      'device_id': l['device_id'] ?? 'Not activated',
      'is_active': l['is_active'] == 1 && !isExpired,
      'is_expired': isExpired,
      'created_at': l['created_at'],
      'activated_at': l['activated_at'],
      'expires_at': l['expires_at'],
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

void _logAction(String key, String deviceId, String action, Request request) async {
  try {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ip = request.headers['X-Forwarded-For'] ?? 'unknown';
    await db.execute(
      'INSERT INTO activation_log (license_key, device_id, action, timestamp, ip_address) VALUES (@key, @did, @action, @ts, @ip)',
      substitutionValues: {'key': key, 'did': deviceId, 'action': action, 'ts': now, 'ip': ip},
    );
  } catch (e) {
    print('Warning: failed to log action: $e');
  }
}
