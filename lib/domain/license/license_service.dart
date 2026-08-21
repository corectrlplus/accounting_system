import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class LicenseService {
  static const String _serverUrl = 'https://accounting-system-5iuv.onrender.com';
  static const String _prefsKeyLicense = 'license_key';
  static const String _prefsKeyDeviceId = 'device_id';
  static const String _prefsKeyPlan = 'license_plan';
  static const String _prefsKeyValid = 'license_valid';

  static HttpClient _createClient() {
    final client = HttpClient();
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return client;
  }

  static Future<String> _post(String path, Map<String, dynamic> body) async {
    final client = _createClient();
    try {
      final uri = Uri.parse('$_serverUrl$path');
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode(body));
      final response = await request.close().timeout(const Duration(seconds: 120));
      final responseBody = await response.transform(utf8.decoder).join();
      return responseBody;
    } finally {
      client.close();
    }
  }

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_prefsKeyDeviceId);
    if (deviceId != null) return deviceId;

    final hostname = Platform.localHostname;
    final os = Platform.operatingSystem;
    final raw = '$hostname:$os:accounting_system';
    final bytes = utf8.encode(raw);
    deviceId = sha256.convert(bytes).toString().substring(0, 32).toUpperCase();

    await prefs.setString(_prefsKeyDeviceId, deviceId);
    return deviceId;
  }

  static Future<LicenseResult> activate(String licenseKey) async {
    try {
      final deviceId = await getDeviceId();
      final responseBody = await _post('/api/activate', {
        'license_key': licenseKey,
        'device_id': deviceId,
      });

      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (data['valid'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKeyLicense, licenseKey.toUpperCase().trim());
        await prefs.setString(_prefsKeyPlan, data['plan'] ?? '');
        await prefs.setBool(_prefsKeyValid, true);

        return LicenseResult(
          valid: true,
          plan: data['plan'] ?? '',
          expiresAt: data['expires_at'] ?? '',
          message: 'تم التفعيل بنجاح',
        );
      } else {
        return LicenseResult(
          valid: false,
          message: data['error'] ?? 'فشل التفعيل',
        );
      }
    } catch (e) {
      return LicenseResult(
        valid: false,
        message: 'خطأ في الاتصال بالسيرفر: $e',
      );
    }
  }

  static Future<LicenseResult> verify() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final licenseKey = prefs.getString(_prefsKeyLicense);
      if (licenseKey == null || licenseKey.isEmpty) {
        return LicenseResult(valid: false, message: 'لم يتم التفعيل');
      }

      final deviceId = await getDeviceId();
      final responseBody = await _post('/api/verify', {
        'license_key': licenseKey,
        'device_id': deviceId,
      });

      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (data['valid'] == true) {
        await prefs.setString(_prefsKeyPlan, data['plan'] ?? '');
        await prefs.setBool(_prefsKeyValid, true);
        return LicenseResult(
          valid: true,
          plan: data['plan'] ?? '',
          expiresAt: data['expires_at'] ?? '',
          daysRemaining: data['days_remaining'] ?? 0,
          message: 'اشتراك نشط',
        );
      } else {
        await prefs.setBool(_prefsKeyValid, false);
        return LicenseResult(
          valid: false,
          message: data['error'] ?? 'اشتراك غير صالح',
          plan: data['plan'] ?? '',
        );
      }
    } catch (e) {
      return _verifyOffline();
    }
  }

  static Future<LicenseResult> _verifyOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final isValid = prefs.getBool(_prefsKeyValid) ?? false;
    final licenseKey = prefs.getString(_prefsKeyLicense);
    final plan = prefs.getString(_prefsKeyPlan) ?? '';

    if (!isValid || licenseKey == null) {
      return LicenseResult(valid: false, message: 'لم يتم التفعيل');
    }

    return LicenseResult(
      valid: true,
      plan: plan,
      message: 'وضع غير متصل - التحقق لاحقاً',
    );
  }

  static Future<bool> hasLicense() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_prefsKeyLicense) ?? '').isNotEmpty;
  }

  static Future<void> clearLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyLicense);
    await prefs.remove(_prefsKeyPlan);
    await prefs.setBool(_prefsKeyValid, false);
  }
}

class LicenseResult {
  final bool valid;
  final String plan;
  final String expiresAt;
  final int daysRemaining;
  final String message;

  const LicenseResult({
    required this.valid,
    this.plan = '',
    this.expiresAt = '',
    this.daysRemaining = 0,
    required this.message,
  });
}
