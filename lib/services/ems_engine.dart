import 'dart:math';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/site.dart';
import '../models/panel.dart';
import '../models/meter.dart';
import '../models/reading.dart';
import '../models/analysis_result.dart';
import '../models/contract_demand.dart';
import 'ai_service.dart';

class EmsEngine {
  final DatabaseHelper _db = DatabaseHelper();
  final AiService _aiService;
  final Uuid _uuid = const Uuid();

  EmsEngine(this._aiService);

  // ---- Site CRUD ----
  Future<Site> createSite(String name, {String? location, double? contractDemandKva}) async {
    final site = Site(
      id: _uuid.v4(),
      name: name,
      location: location,
      contractDemandKva: contractDemandKva,
    );
    await _db.insertSite(site);

    if (contractDemandKva != null) {
      await _db.insertContractDemand(ContractDemand(
        id: _uuid.v4(),
        siteId: site.id,
        contractDemandKva: contractDemandKva,
        effectiveFrom: DateTime.now(),
      ));
    }

    return site;
  }

  Future<List<Site>> getAllSites() => _db.getSites();
  Future<Site?> getSite(String id) => _db.getSite(id);
  Future<void> updateSite(Site site) => _db.updateSite(site);
  Future<void> deleteSite(String id) => _db.deleteSite(id);

  // ---- Panel CRUD ----
  Future<Panel> createPanel(String siteId, String name, {String? panelType}) async {
    final panel = Panel(
      id: _uuid.v4(),
      siteId: siteId,
      name: name,
      panelType: panelType,
    );
    await _db.insertPanel(panel);
    return panel;
  }

  Future<List<Panel>> getPanels(String siteId) => _db.getPanels(siteId);
  Future<void> updatePanel(Panel panel) => _db.updatePanel(panel);
  Future<void> deletePanel(String id) => _db.deletePanel(id);

  // ---- Meter CRUD ----
  Future<Meter> createMeter(
    String panelId,
    String meterNumber, {
    String? meterType,
    double? ctRatio,
    double? ptRatio,
  }) async {
    final meter = Meter(
      id: _uuid.v4(),
      panelId: panelId,
      meterNumber: meterNumber,
      meterType: meterType,
      ctRatio: ctRatio,
      ptRatio: ptRatio,
    );
    await _db.insertMeter(meter);
    return meter;
  }

  Future<List<Meter>> getMeters(String panelId) => _db.getMeters(panelId);
  Future<void> updateMeter(Meter meter) => _db.updateMeter(meter);
  Future<void> deleteMeter(String id) => _db.deleteMeter(id);

  // ---- Reading CRUD ----
  Future<Reading> addReading({
    required String meterId,
    required DateTime readingDate,
    double? kwhImport,
    double? kwhExport,
    double? kvahImport,
    double? kvahExport,
    double? kwDemand,
    double? kvaDemand,
    double? voltageLNAvg,
    double? currentAvg,
    double? powerFactor,
    double? frequency,
    double? thd,
  }) async {
    final reading = Reading(
      id: _uuid.v4(),
      meterId: meterId,
      readingDate: readingDate,
      kwhImport: kwhImport,
      kwhExport: kwhExport,
      kvahImport: kvahImport,
      kvahExport: kvahExport,
      kwDemand: kwDemand,
      kvaDemand: kvaDemand,
      voltageLNAvg: voltageLNAvg,
      currentAvg: currentAvg,
      powerFactor: powerFactor,
      frequency: frequency,
      thd: thd,
    );
    await _db.insertReading(reading);

    // Trigger analysis for this meter
    final meter = await _db.getMeter(meterId);
    if (meter != null) {
      final panel = await _db.getPanel(meter.panelId);
      if (panel != null) {
        final site = await _db.getSite(panel.siteId);
        if (site != null) {
          await _analyzeMeterReadings(
            meterId: meterId,
            site: site,
            panel: panel,
            meter: meter,
          );
        }
      }
    }

    return reading;
  }

  Future<List<Reading>> getReadings(String meterId,
          {DateTime? from, DateTime? to, int? limit}) =>
      _db.getReadings(meterId, from: from, to: to, limit: limit);

  Future<Reading?> getLatestReading(String meterId) =>
      _db.getLatestReading(meterId);

  // ---- AI Analysis ----
  Future<List<AnalysisResult>> _analyzeMeterReadings({
    required String meterId,
    required Site site,
    required Panel panel,
    required Meter meter,
  }) async {
    final readings = await _db.getReadings(meterId, limit: 60);

    if (readings.length < 2) return [];

    final contractDemand = await _db.getActiveContractDemand(site.id);

    final results = await _aiService.analyzeReadings(
      readings: readings,
      siteName: site.name,
      panelName: panel.name,
      meterNumber: meter.meterNumber,
      contractDemandKva: contractDemand?.contractDemandKva,
    );

    for (final result in results) {
      final enriched = AnalysisResult(
        id: _uuid.v4(),
        siteId: site.id,
        panelId: panel.id,
        meterId: meterId,
        readingId: readings.first.id,
        type: result.type,
        severity: result.severity,
        title: result.title,
        description: result.description,
        recommendation: result.recommendation,
        metrics: result.metrics,
      );
      await _db.insertAnalysisResult(enriched);
    }

    return results;
  }

  Future<List<AnalysisResult>> runFullSiteAnalysis(String siteId) async {
    final results = <AnalysisResult>[];
    final panels = await _db.getPanels(siteId);
    final site = await _db.getSite(siteId);
    if (site == null) return [];

    for (final panel in panels) {
      final meters = await _db.getMeters(panel.id);
      for (final meter in meters) {
        final readings = await _db.getReadings(meter.id, limit: 60);
        if (readings.length >= 2) {
          final aiResults = await _aiService.analyzeReadings(
            readings: readings,
            siteName: site.name,
            panelName: panel.name,
            meterNumber: meter.meterNumber,
            contractDemandKva: site.contractDemandKva,
          );
          for (final r in aiResults) {
            final enriched = AnalysisResult(
              id: _uuid.v4(),
              siteId: siteId,
              panelId: panel.id,
              meterId: meter.id,
              readingId: readings.first.id,
              type: r.type,
              severity: r.severity,
              title: r.title,
              description: r.description,
              recommendation: r.recommendation,
              metrics: r.metrics,
            );
            await _db.insertAnalysisResult(enriched);
            results.add(enriched);
          }
        }
      }
    }

    // Run local rule-based analysis as well
    results.addAll(await _runLocalRuleAnalysis(siteId));
    return results;
  }

  Future<List<AnalysisResult>> _runLocalRuleAnalysis(String siteId) async {
    final localResults = <AnalysisResult>[];
    final panels = await _db.getPanels(siteId);

    for (final panel in panels) {
      final meters = await _db.getMeters(panel.id);
      for (final meter in meters) {
        final readings = await _db.getReadings(meter.id, limit: 60);
        if (readings.length < 2) continue;

        final latest = readings.first;
        final prev = readings.length > 1 ? readings[1] : null;

        // Rule 1: Power Factor check
        if (latest.powerFactor != null && latest.powerFactor! < 0.85) {
          localResults.add(AnalysisResult(
            id: _uuid.v4(),
            siteId: siteId,
            panelId: panel.id,
            meterId: meter.id,
            type: AnalysisType.powerFactorIssue,
            severity: latest.powerFactor! < 0.7
                ? Severity.critical
                : Severity.high,
            title: 'Low Power Factor Detected',
            description:
                'Power Factor is ${latest.powerFactor!.toStringAsFixed(2)} at meter ${meter.meterNumber}. Target is > 0.85.',
            recommendation:
                latest.powerFactor! < 0.7
                    ? 'Immediate capacitor bank installation required. Consider APFC panel.'
                    : 'Check capacitor bank operation. Consider adding capacitors.',
            metrics: {'power_factor': latest.powerFactor},
          ));
        }

        // Rule 2: High Demand vs Contract Demand
        if (latest.kwDemand != null && siteId.isNotEmpty) {
          final contract = await _db.getActiveContractDemand(siteId);
          if (contract != null &&
              latest.kwDemand! > contract.contractDemandKva * 0.8) {
            final pct =
                (latest.kwDemand! / contract.contractDemandKva * 100)
                    .toStringAsFixed(1);
            localResults.add(AnalysisResult(
              id: _uuid.v4(),
              siteId: siteId,
              panelId: panel.id,
              meterId: meter.id,
              type: AnalysisType.contractDemandExceeded,
              severity: latest.kwDemand! >= contract.contractDemandKva
                  ? Severity.critical
                  : Severity.high,
              title: 'Contract Demand Approaching Limit',
              description:
                  'Current demand ${latest.kwDemand!.toStringAsFixed(1)} kW is $pct% of contract demand ${contract.contractDemandKva} kVA.',
              recommendation:
                  'Implement load shedding. Shift non-essential loads to off-peak hours.',
              metrics: {
                'current_demand_kw': latest.kwDemand,
                'contract_demand_kva': contract.contractDemandKva,
                'usage_percent': double.parse(pct),
              },
            ));
          }
        }

        // Rule 3: Voltage check (LT: 360-440V)
        if (latest.voltageLNAvg != null) {
          if (latest.voltageLNAvg! < 360 || latest.voltageLNAvg! > 440) {
            localResults.add(AnalysisResult(
              id: _uuid.v4(),
              siteId: siteId,
              panelId: panel.id,
              meterId: meter.id,
              type: AnalysisType.voltageIssue,
              severity: latest.voltageLNAvg! < 340 || latest.voltageLNAvg! > 460
                  ? Severity.critical
                  : Severity.high,
              title: 'Voltage Outside Normal Range',
              description:
                  'Voltage is ${latest.voltageLNAvg!.toStringAsFixed(1)} V (normal: 360-440V).',
              recommendation: latest.voltageLNAvg! < 360
                  ? 'Check for loose connections, transformer tap settings, or upstream supply issues.'
                  : 'Check for overvoltage from utility or capacitor bank malfunction.',
              metrics: {'voltage': latest.voltageLNAvg},
            ));
          }
        }

        // Rule 4: THD check
        if (latest.thd != null && latest.thd! > 8) {
          localResults.add(AnalysisResult(
            id: _uuid.v4(),
            siteId: siteId,
            panelId: panel.id,
            meterId: meter.id,
            type: AnalysisType.harmonicIssue,
            severity: latest.thd! > 15 ? Severity.critical : Severity.high,
            title: 'High Harmonic Distortion',
            description:
                'THD is ${latest.thd!.toStringAsFixed(1)}% (acceptable: < 8%).',
            recommendation:
                'Install harmonic filters. Check for non-linear loads like VFDs, UPS systems.',
            metrics: {'thd': latest.thd},
          ));
        }

        // Rule 5: Sudden spike / anomaly
        if (prev != null &&
            latest.kwhImport != null &&
            prev.kwhImport != null &&
            prev.kwhImport! > 0) {
          final change =
              ((latest.kwhImport! - prev.kwhImport!) / prev.kwhImport! * 100)
                  .abs();
          if (change > 50) {
            localResults.add(AnalysisResult(
              id: _uuid.v4(),
              siteId: siteId,
              panelId: panel.id,
              meterId: meter.id,
              type: AnalysisType.anomaly,
              severity: Severity.high,
              title: 'Sudden Consumption Change',
              description:
                  'Energy consumption changed by ${change.toStringAsFixed(0)}% compared to previous reading.',
              recommendation:
                  'Investigate for equipment changes, new loads, or meter reading errors.',
              metrics: {
                'change_percent': change,
                'previous_kwh': prev.kwhImport,
                'current_kwh': latest.kwhImport,
              },
            ));
          }
        }

        // Rule 6: High load assessment
        if (latest.currentAvg != null && latest.voltageLNAvg != null) {
          final apparentPower =
              latest.voltageLNAvg! * latest.currentAvg! * sqrt(3) / 1000;
          if (apparentPower > 100) {
            localResults.add(AnalysisResult(
              id: _uuid.v4(),
              siteId: siteId,
              panelId: panel.id,
              meterId: meter.id,
              type: AnalysisType.highLoad,
              severity: apparentPower > 500 ? Severity.critical : Severity.high,
              title: 'High Load on Meter ${meter.meterNumber}',
              description:
                  'Apparent power is ${apparentPower.toStringAsFixed(0)} kVA with current ${latest.currentAvg!.toStringAsFixed(0)} A.',
              recommendation:
                  'Consider load balancing or upgrading panel capacity.',
              metrics: {
                'apparent_power_kva': apparentPower,
                'current_a': latest.currentAvg,
              },
            ));
          }
        }
      }
    }

    for (final r in localResults) {
      await _db.insertAnalysisResult(r);
    }
    return localResults;
  }

  Future<List<AnalysisResult>> getAnalysisResults({String? siteId, int? limit}) =>
      _db.getAnalysisResults(siteId: siteId, limit: limit);

  // ---- Dashboard Aggregations ----
  Future<Map<String, dynamic>> getSiteDashboard(String siteId) async {
    final site = await _db.getSite(siteId);
    if (site == null) return {};

    final panels = await _db.getPanels(siteId);
    int totalMeters = 0;
    int totalReadings = 0;
    double totalKwh = 0;
    double maxDemandKw = 0;
    double avgPf = 0;
    int pfCount = 0;

    for (final panel in panels) {
      final meters = await _db.getMeters(panel.id);
      totalMeters += meters.length;
      for (final meter in meters) {
        final readings = await _db.getReadings(meter.id, limit: 60);
        totalReadings += readings.length;
        for (final r in readings) {
          totalKwh += r.kwhImport ?? 0;
          if ((r.kwDemand ?? 0) > maxDemandKw) maxDemandKw = r.kwDemand!;
          if (r.powerFactor != null) {
            avgPf += r.powerFactor!;
            pfCount++;
          }
        }
      }
    }

    final recentAnalyses =
        await _db.getAnalysisResults(siteId: siteId, limit: 20);
    final criticalIssues = recentAnalyses
        .where((a) => a.severity == Severity.critical || a.severity == Severity.high)
        .toList();

    return {
      'site': site,
      'total_panels': panels.length,
      'total_meters': totalMeters,
      'total_readings': totalReadings,
      'total_kwh': totalKwh,
      'max_demand_kw': maxDemandKw,
      'avg_power_factor': pfCount > 0 ? avgPf / pfCount : 0,
      'critical_issues': criticalIssues.length,
      'recent_analyses': recentAnalyses,
    };
  }
}
