import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/export_service.dart';
import '../../core/utils/excel_import_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_section.dart';
import '../../data/models/energy_log_model.dart';
import '../../data/models/meter_model.dart';
import '../../data/repositories/energy_repository.dart';
import '../../data/repositories/meter_repository.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';

/// Bulk Excel import moved into the main navigation (client asked: import +
/// sample format should be visible from the menu, not hidden in Reports).
class ExcelImportPage extends StatefulWidget {
  const ExcelImportPage({super.key});

  @override
  State<ExcelImportPage> createState() => _ExcelImportPageState();
}

class _ExcelImportPageState extends State<ExcelImportPage> {
  Future<void> _downloadTemplate() async {
    try {
      final bytes = await ExcelImportService.generateSampleTemplate();
      await ExportService().exportSampleTemplate(bytes);
    } catch (e) {
      AppLogger.e('Template download failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate the template. Please try again.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _pickAndImportExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    var sourceFile = '';
    final drafts = <ExcelReadingDraft>[];
    try {
      // Read the first file's headers to let the user confirm the column
      // mapping (auto-detection is prefilled). This fits every client file
      // format, e.g. kVA demand recorded under "Contract KVA".
      ExcelColumnMap? columnMap;
      if (result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null) {
          final headers = await ExcelImportService.readHeaders(bytes);
          final detected = ExcelImportService.detectMapping(headers);
          if (mounted) {
            columnMap = await showDialog<ExcelColumnMap>(
              context: context,
              barrierDismissible: false,
              builder: (_) => ExcelColumnMappingDialog(
                headers: headers,
                initial: detected,
              ),
            );
          }
        }
      }
      if (columnMap == null) return;

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        sourceFile = file.name;
        drafts.addAll(
          await ExcelImportService.extractReadings(
            bytes,
            columnMap: columnMap,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Excel import failed', e);
      if (mounted) {
        final message = e is FormatException
            ? e.message
            : 'Import failed. Check the file and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    if (drafts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No readings found in the selected Excel file(s)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ExcelImportPreviewDialog(
        drafts: drafts,
        sourceFile: sourceFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppSectionHeader(
          title: 'Excel Import',
          subtitle: 'Bulk upload meter readings from an Excel file',
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 18,
                color: AppColors.info,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "EXCEL SAMPLE FORMAT — your data is imported in this Excel "
                  "format. Download the 'Excel Sample', enter your meter "
                  "readings in it, then upload via 'Import Data'. Keep the "
                  "columns the same.",
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3 Easy Steps',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                const _StepRow(
                  number: '1',
                  icon: Icons.download_outlined,
                  text: "Download 'Excel Sample' — fill in your readings "
                      'in this format.',
                ),
                const SizedBox(height: 10),
                const _StepRow(
                  number: '2',
                  icon: Icons.edit_note_rounded,
                  text: 'Enter your meter readings in the Excel sheet '
                      '(kWh, kVAh, MD, PF, etc.).',
                ),
                const SizedBox(height: 10),
                const _StepRow(
                  number: '3',
                  icon: Icons.file_upload_outlined,
                  text: "Tap 'Import Data' — select the file, confirm the "
                      'column mapping, review the preview and click Import.',
                ),
                const SizedBox(height: 20),
                if (isNarrow)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: 'Import Data',
                          icon: Icons.file_upload_outlined,
                          onPressed: _pickAndImportExcel,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: AppButtonOutline(
                          label: 'Excel Sample',
                          icon: Icons.download_outlined,
                          onPressed: _downloadTemplate,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Import Data',
                          icon: Icons.file_upload_outlined,
                          onPressed: _pickAndImportExcel,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButtonOutline(
                          label: 'Excel Sample',
                          icon: Icons.download_outlined,
                          onPressed: _downloadTemplate,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final IconData icon;
  final String text;

  const _StepRow({
    required this.number,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: AppColors.dim(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.dim(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Confirm column mapping — auto-detection is prefilled, user can adjust.
class ExcelColumnMappingDialog extends StatefulWidget {
  final List<String> headers;
  final ExcelColumnMap initial;

  const ExcelColumnMappingDialog({
    super.key,
    required this.headers,
    required this.initial,
  });

  @override
  State<ExcelColumnMappingDialog> createState() => _ExcelColumnMappingDialogState();
}

class _ExcelColumnMappingDialogState extends State<ExcelColumnMappingDialog> {
  late final ExcelColumnMap _map = widget.initial;

  String _colName(int index) {
    var n = index;
    var label = '';
    while (n >= 0) {
      label = String.fromCharCode(65 + (n % 26)) + label;
      n = n ~/ 26 - 1;
    }
    return label;
  }

  Widget _fieldDropdown({
    required String label,
    required int? value,
    required void Function(int?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        items: [
          const DropdownMenuItem<int>(value: -1, child: Text('— Auto —')),
          for (var i = 0; i < widget.headers.length; i++)
            if (widget.headers[i].trim().isNotEmpty)
              DropdownMenuItem<int>(
                value: i,
                child: Text(
                  '${_colName(i)}: ${widget.headers[i].trim()}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Column Mapping'),
      content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Auto-detection is prefilled. Adjust if your client file '
                'uses different column names (e.g. kVA demand under '
                '"Contract KVA").',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              _fieldDropdown(
                label: 'Reading Date',
                value: _map.date,
                onChanged: (v) => setState(() => _map.date = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'kWh (consumed or cumulative)',
                value: _map.kwh,
                onChanged: (v) => setState(() => _map.kwh = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'kVAh',
                value: _map.kvah,
                onChanged: (v) => setState(() => _map.kvah = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'Max Demand kVA',
                value: _map.md,
                onChanged: (v) => setState(() => _map.md = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'rkVARh Lag',
                value: _map.lag,
                onChanged: (v) => setState(() => _map.lag = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'rkVARh Lead',
                value: _map.lead,
                onChanged: (v) => setState(() => _map.lead = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'Power Factor (as-is)',
                value: _map.pf,
                onChanged: (v) => setState(() => _map.pf = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'Meter Name',
                value: _map.meter,
                onChanged: (v) =>
                    setState(() => _map.meter = v == -1 ? null : v),
              ),
            ],
          ),
        ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_map),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

/// Preview + edit screen for readings parsed from an Excel file.
/// Nothing is saved until the user confirms (manual edit mandatory).
class ExcelImportPreviewDialog extends StatefulWidget {
  const ExcelImportPreviewDialog({
    super.key,
    required this.drafts,
    required this.sourceFile,
  });

  final List<ExcelReadingDraft> drafts;
  final String sourceFile;

  @override
  State<ExcelImportPreviewDialog> createState() => _ExcelImportPreviewDialogState();
}

class _ExcelImportPreviewDialogState extends State<ExcelImportPreviewDialog> {
  List<MeterModel> _meters = [];
  bool _saving = false;

  late final List<ExcelDraftEditor> _editors =
      widget.drafts.map((d) => ExcelDraftEditor(d)).toList();

  @override
  void initState() {
    super.initState();
    _loadMeters();
  }

  @override
  void dispose() {
    for (final e in _editors) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMeters() async {
    final meters = await context.read<MeterRepository>().getAllMeters();
    if (!mounted) return;
    setState(() {
      _meters = meters;
      for (final e in _editors) {
        if (meters.isEmpty) break;
        final known = meters.any((m) => m.name == e.meterName);
        if (e.meterName.isEmpty || !known) {
          e.meterName = meters.first.name;
        }
      }
    });
  }

  MeterModel? _meterByName(String name) {
    for (final m in _meters) {
      if (m.name == name) return m;
    }
    return null;
  }

  Future<void> _pickDate(ExcelDraftEditor editor) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: editor.loggedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        editor.dateCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _import() async {
    setState(() => _saving = true);
    final models = <EnergyLogModel>[];
    for (final e in _editors) {
      if (!e.valid) continue;
      final meter = _meterByName(e.meterName);
      models.add(
        EnergyLogModel.create(
          meterName: e.meterName,
          kwh: e.kwh,
          kvah: e.kvah,
          currentKwh: e.currentKwh,
          currentKvah: e.currentKvah,
          rkvarhLag: e.lag,
          rkvarhLead: e.lead,
          powerFactor: e.powerFactor,
          mdRecorded: e.md,
          contractDemand:
              meter?.contractDemandKw ?? AppConstants.defaultContractDemandKva,
          loggedAt: e.loggedAt,
          multiplyingFactor:
              meter?.multiplyingFactor ?? AppConstants.multiplyingFactor,
        ),
      );
    }

    if (models.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid reading found — fill in kWh and MD'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final count = await context
          .read<EnergyRepository>()
          .bulkSaveReadings(models);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count reading(s) imported successfully'),
          backgroundColor: Colors.green,
        ),
      );
      context.read<EnergyBloc>().add(const LoadInitialDashboardData());
    } catch (e) {
      AppLogger.e('Bulk import save failed', e);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is FormatException
                ? e.message
                : 'Import failed. Check the file and try again.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _editors.where((e) => e.valid).length;
    return AlertDialog(
      title: const Text('Import Readings'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width < 600
            ? double.maxFinite
            : 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.drafts.length} reading(s) found — ${widget.sourceFile}. '
              'Verify the values, then import.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.dim(context),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _editors.length,
                itemBuilder: (context, i) => _buildDraftCard(_editors[i], i),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Import $validCount Reading(s)',
          icon: Icons.check_circle_outline,
          onPressed: _saving || validCount == 0 ? null : _import,
          loading: _saving,
        ),
      ],
    );
  }

  Widget _buildDraftCard(ExcelDraftEditor e, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  e.draft.sourceLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dim(context),
                  ),
                ),
                const Spacer(),
                if (!e.valid)
                  const Text(
                    'Incomplete',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('meter-$index-${e.meterName}'),
              initialValue: _meters.any((m) => m.name == e.meterName)
                  ? e.meterName
                  : null,
              hint: const Text('Select Meter'),
              decoration: const InputDecoration(
                labelText: 'Meter',
                isDense: true,
                prefixIcon: Icon(Icons.speed_rounded, size: 20),
              ),
              items: _meters
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.name,
                      child: Text(m.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => e.meterName = v);
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: e.dateCtrl,
              label: 'Reading Date',
              prefixIcon: Icons.event,
              suffixIcon: Icons.calendar_month,
              onSuffixTap: () => _pickDate(e),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: e.kwhCtrl,
                    label: 'Consumed (kWh)',
                    prefixIcon: Icons.bolt,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: e.kvahCtrl,
                    label: 'Consumed kVAh',
                    prefixIcon: Icons.electrical_services,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: e.currentKwhCtrl,
                    label: 'Actual Reading kWh',
                    hint: 'Optional — meter display value',
                    prefixIcon: Icons.speed,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: e.currentKvahCtrl,
                    label: 'Actual Reading kVAh',
                    hint: 'Optional',
                    prefixIcon: Icons.speed,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (MediaQuery.of(context).size.width < 600)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: e.mdCtrl,
                          label: 'MD Recorded (kVA)',
                          prefixIcon: Icons.trending_up,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: e.pfCtrl,
                          label: 'Power Factor',
                          prefixIcon: Icons.percent,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: e.lagCtrl,
                          label: 'rkVARh Lag',
                          prefixIcon: Icons.warning_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: e.leadCtrl,
                          label: 'rkVARh Lead',
                          prefixIcon: Icons.check_circle_outline,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: e.mdCtrl,
                    label: 'MD Recorded (kVA)',
                    prefixIcon: Icons.trending_up,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: e.pfCtrl,
                    label: 'Power Factor',
                    prefixIcon: Icons.percent,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: e.lagCtrl,
                    label: 'rkVARh Lag',
                    prefixIcon: Icons.warning_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: e.leadCtrl,
                    label: 'rkVARh Lead',
                    prefixIcon: Icons.check_circle_outline,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ExcelDraftEditor {
  ExcelDraftEditor(this.draft)
    : meterName = draft.meterName,
      dateCtrl = TextEditingController(
        text: '${draft.loggedAt.day.toString().padLeft(2, '0')}'
            '/${draft.loggedAt.month.toString().padLeft(2, '0')}'
            '/${draft.loggedAt.year}',
      ),
      kwhCtrl = TextEditingController(text: _fmt(draft.kwh)),
      kvahCtrl = TextEditingController(text: _fmt(draft.kvah)),
      currentKwhCtrl = TextEditingController(
        text: draft.currentKwh != null
            ? draft.currentKwh!.toStringAsFixed(2)
            : '',
      ),
      currentKvahCtrl = TextEditingController(
        text: draft.currentKvah != null
            ? draft.currentKvah!.toStringAsFixed(2)
            : '',
      ),
      lagCtrl = TextEditingController(text: _fmt(draft.rkvarhLag)),
      leadCtrl = TextEditingController(text: _fmt(draft.rkvarhLead)),
      mdCtrl = TextEditingController(text: _fmt(draft.mdRecorded)),
      pfCtrl = TextEditingController(
        text: draft.powerFactor != null
            ? draft.powerFactor!.toStringAsFixed(3)
            : '',
      );

  final ExcelReadingDraft draft;
  String meterName = '';
  final TextEditingController dateCtrl;
  final TextEditingController kwhCtrl;
  final TextEditingController kvahCtrl;
  final TextEditingController currentKwhCtrl;
  final TextEditingController currentKvahCtrl;
  final TextEditingController lagCtrl;
  final TextEditingController leadCtrl;
  final TextEditingController mdCtrl;
  final TextEditingController pfCtrl;

  static String _fmt(double v) => v > 0 ? v.toStringAsFixed(2) : '';

  double get kwh => double.tryParse(kwhCtrl.text.trim()) ?? 0;
  double get kvah => double.tryParse(kvahCtrl.text.trim()) ?? 0;
  double get md => double.tryParse(mdCtrl.text.trim()) ?? 0;
  double get lag => double.tryParse(lagCtrl.text.trim()) ?? 0;
  double get lead => double.tryParse(leadCtrl.text.trim()) ?? 0;

  /// Actual (cumulative) meter reading — blank means "not known" (the system
  /// reconstructs it from the consumption chain on read).
  double? get currentKwh {
    final v = double.tryParse(currentKwhCtrl.text.trim());
    return v == null || v <= 0 ? null : v;
  }

  double? get currentKvah {
    final v = double.tryParse(currentKvahCtrl.text.trim());
    return v == null || v <= 0 ? null : v;
  }

  /// PF as imported from the file (or edited by the user). Null → let the
  /// system calculate from kWh/kVAh.
  double? get powerFactor {
    final v = double.tryParse(pfCtrl.text.trim());
    if (v == null || v <= 0) return null;
    return v > 1 ? v / 100 : v;
  }

  /// Importable when it has consumption or an actual reading, plus MD.
  /// Opening rows (0 consumption, real reading) anchor the reading chain.
  bool get valid => (kwh > 0 || currentKwh != null) && md > 0;

  DateTime get loggedAt {
    final m = RegExp(
      r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$',
    ).firstMatch(dateCtrl.text.trim());
    if (m != null) {
      final day = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      var year = int.parse(m.group(3)!);
      if (year < 100) year += 2000;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.now();
  }

  void dispose() {
    dateCtrl.dispose();
    kwhCtrl.dispose();
    kvahCtrl.dispose();
    currentKwhCtrl.dispose();
    currentKvahCtrl.dispose();
    lagCtrl.dispose();
    leadCtrl.dispose();
    mdCtrl.dispose();
    pfCtrl.dispose();
  }
}
