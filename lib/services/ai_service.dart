import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reading.dart';
import '../models/analysis_result.dart';

class AiService {
  final String _apiKey;
  final String _model;
  final http.Client _client;

  AiService({
    required String apiKey,
    String model = 'gpt-4o-mini',
    http.Client? client,
  })  : _apiKey = apiKey,
        _model = model,
        _client = client ?? http.Client();

  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  Future<List<AnalysisResult>> analyzeReadings({
    required List<Reading> readings,
    required String siteName,
    required String panelName,
    required String meterNumber,
    double? contractDemandKva,
  }) async {
    if (readings.isEmpty) return [];

    final prompt = _buildAnalysisPrompt(
      readings: readings,
      siteName: siteName,
      panelName: panelName,
      meterNumber: meterNumber,
      contractDemandKva: contractDemandKva,
    );

    try {
      final response = await _client.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an energy management expert. Analyze the meter reading data and return a JSON array of analysis findings. Each finding must have: title, description, recommendation, type (one of: highLoad, contractDemandExceeded, powerFactorIssue, voltageIssue, currentUnbalance, harmonicIssue, anomaly, energySaving, general), severity (low/medium/high/critical), and metrics (object with relevant values). Return ONLY valid JSON array.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,
          'max_tokens': 2000,
        }),
      );

      if (response.statusCode != 200) {
        return [
          AnalysisResult(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: AnalysisType.general,
            severity: Severity.medium,
            title: 'AI Analysis Failed',
            description:
                'API returned status ${response.statusCode}: ${response.body}',
          ),
        ];
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = body['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.isEmpty) {
        return [];
      }

      final cleaned = content
          .replaceAll(RegExp(r'^```json\s*'), '')
          .replaceAll(RegExp(r'^```\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();

      final List<dynamic> findings = jsonDecode(cleaned) as List<dynamic>;
      return findings.map((f) {
        final m = f as Map<String, dynamic>;
        return AnalysisResult(
          id: DateTime.now().microsecondsSinceEpoch.toString() +
              findings.indexOf(f).toString(),
          type: AnalysisType.values.firstWhere(
            (e) => e.name == m['type'],
            orElse: () => AnalysisType.general,
          ),
          severity: Severity.values.firstWhere(
            (e) => e.name == m['severity'],
            orElse: () => Severity.medium,
          ),
          title: m['title'] as String? ?? 'Unknown Issue',
          description: m['description'] as String? ?? '',
          recommendation: m['recommendation'] as String?,
          metrics: m['metrics'] as Map<String, dynamic>?,
        );
      }).toList();
    } catch (e) {
      return [
        AnalysisResult(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          type: AnalysisType.general,
          severity: Severity.medium,
          title: 'AI Analysis Error',
          description: 'Failed to analyze readings: $e',
        ),
      ];
    }
  }

  String _buildAnalysisPrompt({
    required List<Reading> readings,
    required String siteName,
    required String panelName,
    required String meterNumber,
    double? contractDemandKva,
  }) {
    final readingsJson = readings
        .map((r) => {
              'date': r.readingDate.toIso8601String().substring(0, 10),
              'kwh_import': r.kwhImport,
              'kwh_export': r.kwhExport,
              'kvah_import': r.kvahImport,
              'kw_demand': r.kwDemand,
              'kva_demand': r.kvaDemand,
              'voltage': r.voltageLNAvg,
              'current': r.currentAvg,
              'power_factor': r.powerFactor,
              'frequency': r.frequency,
              'thd': r.thd,
            })
        .toList();

    return '''
Analyze the following daily meter readings for:
  Site: $siteName
  Panel: $panelName
  Meter: $meterNumber
  ${contractDemandKva != null ? 'Contract Demand: ${contractDemandKva}kVA' : ''}

Readings (${readings.length} entries):
${jsonEncode(readingsJson)}

Identify:
1. High load conditions vs contract demand
2. Power factor issues (below 0.85 is poor, below 0.7 is critical)
3. Voltage fluctuations (normal: 360-440V for LT, check for sags/swells)
4. Current unbalance across phases
5. Harmonic distortion issues (THD > 8% is concerning)
6. Sudden anomalies or abnormal consumption patterns
7. Energy saving opportunities
8. Overall system health assessment

Return findings as JSON array sorted by severity (critical first).
''';
  }

  Future<String> getRecommendation({
    required String issueType,
    required String description,
    required Map<String, dynamic> metrics,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an energy management consultant. Provide a concise, actionable recommendation for the given electrical issue. Be specific with equipment suggestions, settings adjustments, or operational changes. Response should be 2-3 sentences.',
            },
            {
              'role': 'user',
              'content':
                  'Issue type: $issueType\nDescription: $description\nMetrics: ${jsonEncode(metrics)}\n\nWhat is the best corrective action?',
            },
          ],
          'temperature': 0.3,
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['choices']?[0]?['message']?['content'] as String? ??
            'Unable to generate recommendation.';
      }
      return 'Unable to generate recommendation.';
    } catch (e) {
      return 'Recommendation unavailable: $e';
    }
  }

  void dispose() {
    _client.close();
  }
}
