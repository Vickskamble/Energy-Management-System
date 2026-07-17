import 'package:flutter/foundation.dart';
import '../core/database/database_helper.dart';
import '../models/site.dart';
import '../models/panel.dart';
import '../models/meter.dart';
import '../models/reading.dart';
import '../models/analysis_result.dart';
import '../services/ems_engine.dart';
import '../services/sync_service.dart';

class EmsProvider extends ChangeNotifier {
  final EmsEngine _engine;
  final SyncService _syncService;
  final DatabaseHelper _db = DatabaseHelper();

  List<Site> _sites = [];
  List<Panel> _panels = [];
  List<Meter> _meters = [];
  List<Reading> _readings = [];
  List<AnalysisResult> _analysisResults = [];
  Site? _selectedSite;
  Panel? _selectedPanel;
  Meter? _selectedMeter;
  Map<String, dynamic>? _siteDashboard;
  bool _loading = false;
  String? _error;

  EmsProvider(this._engine, this._syncService);

  // Getters
  List<Site> get sites => _sites;
  List<Panel> get panels => _panels;
  List<Meter> get meters => _meters;
  List<Reading> get readings => _readings;
  List<AnalysisResult> get analysisResults => _analysisResults;
  Site? get selectedSite => _selectedSite;
  Panel? get selectedPanel => _selectedPanel;
  Meter? get selectedMeter => _selectedMeter;
  Map<String, dynamic>? get siteDashboard => _siteDashboard;
  bool get loading => _loading;
  String? get error => _error;
  SyncService get syncService => _syncService;

  // Site operations
  Future<void> loadSites() async {
    _loading = true;
    notifyListeners();
    try {
      _sites = await _engine.getAllSites();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<Site?> createSite(String name, {String? location, double? contractDemandKva}) async {
    try {
      final site = await _engine.createSite(name, location: location, contractDemandKva: contractDemandKva);
      await loadSites();
      return site;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> selectSite(Site site) async {
    _selectedSite = site;
    _selectedPanel = null;
    _selectedMeter = null;
    _panels = [];
    _meters = [];
    _readings = [];
    notifyListeners();
    await loadPanels(site.id);
    await loadSiteDashboard(site.id);
  }

  // Panel operations
  Future<void> loadPanels(String siteId) async {
    _panels = await _engine.getPanels(siteId);
    notifyListeners();
  }

  Future<Panel?> createPanel(String siteId, String name, {String? panelType}) async {
    try {
      final panel = await _engine.createPanel(siteId, name, panelType: panelType);
      await loadPanels(siteId);
      return panel;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> selectPanel(Panel panel) async {
    _selectedPanel = panel;
    _selectedMeter = null;
    _meters = [];
    _readings = [];
    notifyListeners();
    await loadMeters(panel.id);
  }

  // Meter operations
  Future<void> loadMeters(String panelId) async {
    _meters = await _engine.getMeters(panelId);
    notifyListeners();
  }

  Future<Meter?> createMeter(String panelId, String meterNumber,
      {String? meterType, double? ctRatio, double? ptRatio}) async {
    try {
      final meter = await _engine.createMeter(panelId, meterNumber,
          meterType: meterType, ctRatio: ctRatio, ptRatio: ptRatio);
      await loadMeters(panelId);
      return meter;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> selectMeter(Meter meter) async {
    _selectedMeter = meter;
    notifyListeners();
    await loadReadings(meter.id);
  }

  // Reading operations
  Future<void> loadReadings(String meterId) async {
    _readings = await _engine.getReadings(meterId, limit: 90);
    notifyListeners();
  }

  Future<Reading?> addReading({
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
    try {
      final reading = await _engine.addReading(
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
      await loadReadings(meterId);
      await loadAnalysis(meterId: meterId);
      return reading;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Analysis operations
  Future<void> loadAnalysis({String? siteId, String? meterId}) async {
    _analysisResults = await _engine.getAnalysisResults(
      siteId: siteId ?? _selectedSite?.id,
      limit: 50,
    );
    notifyListeners();
  }

  Future<void> runFullAnalysis(String siteId) async {
    _loading = true;
    notifyListeners();
    try {
      await _engine.runFullSiteAnalysis(siteId);
      await loadAnalysis(siteId: siteId);
      await loadSiteDashboard(siteId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  // Dashboard
  Future<void> loadSiteDashboard(String siteId) async {
    _siteDashboard = await _engine.getSiteDashboard(siteId);
    notifyListeners();
  }

  // Sync
  Future<bool> syncNow() async {
    return await _syncService.syncAll();
  }

  // Reads a reading by the meter & date to check for duplicates
  Future<bool> hasReadingOnDate(String meterId, DateTime date) async {
    final existing = await _db.getReadings(meterId);
    final dateStr = date.toIso8601String().substring(0, 10);
    return existing.any((r) =>
        r.readingDate.toIso8601String().substring(0, 10) == dateStr);
  }
}
