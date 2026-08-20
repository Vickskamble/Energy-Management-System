// Seed script: creates TODMeter + 90 days of TOD (3-shift) readings for
// demo@powerems.com so the app's TOD/time-of-day flows can be demoed.
//
// Pure Dart (no Flutter imports) so it runs with `dart run`.
// Uses the demo user's own JWT — inserts are scoped by RLS to that user.
// Never prints the password or token.
//
// Usage: dart run tool/seed_tod_data.dart
//
// Input columns mirror EnergyLogModel.toJson(); computed columns mirror
// CalculationEngine + EnergyLogModel.create math so stored numbers are
// consistent with what the app itself would write.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

// ---------------------------------------------------------------------------
// Tariff defaults (AppConstants / AppConfig defaults used by the app).
// ---------------------------------------------------------------------------
const kTariffPerUnit = 8.44;
const kDemandChargePerKva = 650.0;
const kFacRatePerUnit = 0.30;
const kWheelingChargePerUnit = 0.81;
const kElectricityDutyPerUnit = 0.275;
const kTaxPercent = 1.25;
const kPfRebateThreshold = 0.95;
const kPfRebatePercent = 1.0;
const kPfSurchargeThreshold = 0.90;
const kPfSurchargePercent = 5.0;

const kMeterName = 'TODMeter';
const kContractDemand = 400.0;
const kMultiplyingFactor = 1.0;
const kDays = 90;
const kShiftTimes = [6, 14, 22]; // IST — Day / Evening / Night (8h each)
const kMeterId = '3c1a8f2e-9d7c-4b5e-a1f0-6d2e8b4a9c01';

double _round(double v, int dp) {
  final f = pow(10, dp).toDouble();
  return (v * f).round() / f;
}

String _uuid4(Random rng) {
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

Map<String, String> _readEnv() {
  final env = <String, String>{};
  for (final raw in File('.env').readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final idx = line.indexOf('=');
    if (idx <= 0) continue;
    env[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
  }
  return env;
}

// ---------------------------------------------------------------------------
// Supabase REST helpers (auth + PostgREST).
// ---------------------------------------------------------------------------
class Api {
  Api(this.url, this.anonKey);
  final String url;
  final String anonKey;
  String? _token;

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('$url$path'));
      req.headers.contentType = ContentType.json;
      req.headers.set('apikey', anonKey);
      if (auth) req.headers.set('Authorization', 'Bearer $_token');
      req.write(jsonEncode(body));
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode >= 300) {
        throw StateError('POST $path -> ${res.statusCode}: $text');
      }
      return text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> login(String email, String password) async {
    final res = await _postJson(
      '/auth/v1/token?grant_type=password',
      {'email': email, 'password': password},
    );
    final token = res['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Login failed — no access token in response.');
    }
    _token = token;
  }

  String get token => _token!;

  Future<int> rowCount(String table) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(
        Uri.parse('$url/rest/v1/$table?select=id&limit=1'),
      );
      req.headers.set('apikey', anonKey);
      req.headers.set('Authorization', 'Bearer $token');
      req.headers.set('Prefer', 'count=exact');
      final res = await req.close();
      await res.drain<void>();
      final cr = res.headers.value('content-range');
      if (cr == null || cr.startsWith('*')) {
        return -1; // count NOT verified
      }
      final parts = cr.split('/');
      return parts.length == 2 ? int.parse(parts[1]) : -1;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> upsertRows(String table, List<Map<String, dynamic>> rows) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse('$url/rest/v1/$table?on_conflict=id'),
      );
      req.headers.contentType = ContentType.json;
      req.headers.set('apikey', anonKey);
      req.headers.set('Authorization', 'Bearer $token');
      req.headers.set('Prefer', 'resolution=merge-duplicates,return=minimal');
      req.write(jsonEncode(rows));
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode >= 300) {
        throw StateError('upsert $table -> ${res.statusCode}: $text');
      }
    } finally {
      client.close(force: true);
    }
  }
}

// ---------------------------------------------------------------------------
// Reading row builder — mirrors EnergyLogModel.create math.
// ---------------------------------------------------------------------------
Map<String, dynamic> _buildReading({
  required String id,
  required String userId,
  required DateTime loggedAtLocal,
  required double shiftKwh,
  required double powerFactor,
  required double mdRecorded,
  required double cumulativeKwh,
  required double cumulativeKvah,
}) {
  final kvah = _round(shiftKwh / powerFactor, 2);
  final rkvarhLag = _round(shiftKwh * tan(acos(powerFactor.clamp(0.05, 0.999))), 2);
  final units = shiftKwh * kMultiplyingFactor;
  final billingDemand = mdRecorded * kMultiplyingFactor; // engine: no ratchet

  final energyCharges = units * kTariffPerUnit;
  final demandCharges = billingDemand * kDemandChargePerKva;
  final facCharges = units * kFacRatePerUnit;
  final wheelingCharges = units * kWheelingChargePerUnit;
  final duty = units * kElectricityDutyPerUnit;
  final taxes = energyCharges * kTaxPercent / 100;
  final pfRebate = powerFactor >= kPfRebateThreshold
      ? (energyCharges + demandCharges) * kPfRebatePercent / 100
      : 0.0;
  final pfSurcharge = powerFactor < kPfSurchargeThreshold
      ? (energyCharges + demandCharges) * kPfSurchargePercent / 100
      : 0.0;
  final netBill = energyCharges +
      demandCharges +
      facCharges +
      wheelingCharges +
      duty +
      taxes -
      pfRebate +
      pfSurcharge;
  final loadFactor =
      (units / 8 / (billingDemand > 0 ? billingDemand : 1)).clamp(0.0, 1.0);
  final avgUnitCost = netBill / (units > 0 ? units : 1);

  return {
    'id': id,
    'meter_name': kMeterName,
    'kwh': _round(shiftKwh, 2),
    'kvah': kvah,
    'current_kwh': _round(cumulativeKwh, 2),
    'current_kvah': _round(cumulativeKvah, 2),
    'rkvarh_lag': _round(rkvarhLag, 2),
    'rkvarh_lead': 0.0,
    'power_factor': _round(powerFactor, 3),
    'md_recorded': _round(mdRecorded, 2),
    'contract_demand': kContractDemand,
    'estimated_bill': _round(netBill, 2),
    'logged_at': loggedAtLocal.toUtc().toIso8601String(),
    'is_synced': true,
    'user_id': userId,
    'energy_charges': _round(energyCharges, 2),
    'demand_charges': _round(demandCharges, 2),
    'fac_charges': _round(facCharges, 2),
    'wheeling_charges': _round(wheelingCharges, 2),
    'electricity_duty': _round(duty, 2),
    'taxes': _round(taxes, 2),
    'pf_rebate': _round(pfRebate, 2),
    'pf_surcharge': _round(pfSurcharge, 2),
    'subsidy': 0.0,
    'net_bill': _round(netBill, 2),
    'billing_demand': _round(billingDemand, 2),
    'load_factor': _round(loadFactor, 4),
    'avg_unit_cost': _round(avgUnitCost, 2),
    'multiplying_factor': kMultiplyingFactor,
  };
}

void main() async {
  final env = _readEnv();
  final url = env['SUPABASE_URL']?.trimRight();
  final anonKey = env['SUPABASE_ANON_KEY'];
  if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
    stderr.writeln('ERROR: SUPABASE_URL / SUPABASE_ANON_KEY missing from .env');
    exit(1);
  }

  const email = 'demo@powerems.com';
  const password = 'demo1234';

  final api = Api(url, anonKey);
  stdout.writeln('[1/4] Logging in as $email ...');
  await api.login(email, password);
  final userId = (await api.rowCount('energy_logs')) >= 0
      ? _userIdFromToken(api.token)
      : '';
  stdout.writeln('      user_id: ${userId.isEmpty ? '(unknown)' : userId}');

  stdout.writeln('[2/4] Existing rows before seed:');
  stdout.writeln(
      '      user_meters : ${await api.rowCount('user_meters')} (verify via Content-Range)');
  stdout.writeln(
      '      energy_logs : ${await api.rowCount('energy_logs')} (verify via Content-Range)');

  // ---------------------------------------------------------------
  // Generate data — deterministic RNG so a rerun is byte-identical.
  // ---------------------------------------------------------------
  final rng = Random(42);
  final now = DateTime.now();
  final endDay = DateTime(now.year, now.month, now.day).subtract(
    const Duration(days: 1),
  );
  final startDay = endDay.subtract(const Duration(days: kDays - 1));

  final meterRow = <String, dynamic>{
    'id': kMeterId,
    'name': kMeterName,
    'site': 'Main Site',
    'contract_demand_kw': kContractDemand,
    'is_active': true,
    'ct_ratio': 1.0,
    'pt_ratio': 1.0,
    'daily_kwh_target': 0.0,
    'user_id': userId,
  };

  final logs = <Map<String, dynamic>>[];
  var cumulativeKwh = 452831.5;
  var cumulativeKvah = 452831.5 * 1.04;

  for (var d = 0; d < kDays; d++) {
    final day = startDay.add(Duration(days: d));
    final dow = day.weekday; // 1=Mon .. 7=Sun
    final weekendFactor = switch (dow) {
      6 => 0.78, // Sat
      7 => 0.52, // Sun
      _ => 1.0,
    };
    final growth = 1 + 0.0015 * d;
    final base = 1050.0 * weekendFactor * growth * (1 + (rng.nextDouble() - 0.5) * 0.14);

    final splits = [0.45, 0.35, 0.20];
    for (var s = 0; s < splits.length; s++) {
      var split = splits[s] * (1 + (rng.nextDouble() - 0.5) * 0.10);
      if (s > 0) {
        // Renormalize so the three splits sum to ~1.
        split = split * (splits[0] / (splits[0] + splits[1] + splits[2]));
      }
      final shiftKwh = max(8.0, base * split);

      // PF: Day best, Evening medium, Night worst (reactive loads).
      final pfRange = switch (s) {
        0 => (0.955, 0.985), // Day
        1 => (0.92, 0.965), // Evening
        _ => (0.87, 0.94), // Night
      };
      final pf = pfRange.$1 + rng.nextDouble() * (pfRange.$2 - pfRange.$1);

      // MD: peak shifts 355-425 (breach alerts > 380), night/day lower.
      final md = switch (s) {
        0 => 330.0 + rng.nextDouble() * 40.0,
        1 => 355.0 + rng.nextDouble() * 70.0,
        _ => 260.0 + rng.nextDouble() * 70.0,
      } * weekendFactor.clamp(0.75, 1.0);

      cumulativeKwh += shiftKwh;
      cumulativeKvah += shiftKwh / pf;

      final loggedAt =
          DateTime(day.year, day.month, day.day, kShiftTimes[s], 0, 0);
      logs.add(
        _buildReading(
          id: _uuid4(rng),
          userId: userId,
          loggedAtLocal: loggedAt,
          shiftKwh: shiftKwh,
          powerFactor: pf,
          mdRecorded: md,
          cumulativeKwh: cumulativeKwh,
          cumulativeKvah: cumulativeKvah,
        ),
      );
    }
  }

  final totalKwh = logs.fold<double>(0, (sum, l) => sum + (l['kwh'] as double));
  stdout.writeln(
      '[3/4] Generated: ${logs.length} readings (${kDays} days x 3 shifts) '
      '= ${_round(totalKwh, 0)} kWh total, meter "$kMeterName" (contract ${kContractDemand} kVA)');
  stdout.writeln('      range: ${startDay.toString().split(' ')[0]} to '
      '${endDay.toString().split(' ')[0]} at 06:00/14:00/22:00 IST');

  // ---------------------------------------------------------------
  // Insert — meter first, then logs in chunks.
  // ---------------------------------------------------------------
  stdout.writeln('[4/4] Inserting ...');
  await api.upsertRows('user_meters', [meterRow]);
  stdout.writeln('      user_meters : 1 row upserted (id $kMeterId)');

  const chunk = 100;
  for (var i = 0; i < logs.length; i += chunk) {
    final batch = logs.sublist(i, min(i + chunk, logs.length));
    await api.upsertRows('energy_logs', batch);
    stdout.writeln('      energy_logs : batch ${i + 1}-${i + batch.length} upserted');
  }

  final afterMeters = await api.rowCount('user_meters');
  final afterLogs = await api.rowCount('energy_logs');
  stdout.writeln('After seed -> user_meters: $afterMeters, energy_logs: $afterLogs');
  stdout.writeln('DONE. Open the app as demo@powerems.com and refresh.');
}

/// Cheap decode of the JWT payload to read the user id (never printed).
String _userIdFromToken(String token) {
  final parts = token.split('.');
  if (parts.length < 2) return '';
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    return (payload['sub'] as String?) ?? '';
  } catch (_) {
    return '';
  }
}
