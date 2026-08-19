import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tour_keys.dart';

/// One spotlight step of the guided tour.
class TourStep {
  const TourStep({
    this.targetKey,
    required this.tabIndex,
    required this.title,
    required this.description,
    this.allowMissing = false,
  });

  /// Widget (GlobalKey) that gets highlighted. `null` → centered text card.
  final GlobalKey? targetKey;

  /// IndexedStack slot the hub must switch to before measuring this target.
  final int tabIndex;

  final String title;
  final String description;

  /// When the target can legitimately be absent (e.g. drawer-only sidebar
  /// items on mobile), the step falls back to a centered card instead of
  /// waiting forever.
  final bool allowMissing;
}

/// The 14-step guided tour for first-time users.
final kAppTourSteps = <TourStep>[
  TourStep(
    targetKey: kTourDashboardKpisKey,
    tabIndex: 0,
    title: 'Your Energy At A Glance',
    description: 'Pehle screen pe apne energy data ke sabse important numbers '
        '— Estimated Bill, Consumption, Max Demand aur Power Factor — ek '
        'nazar me dikh jaate hain.',
  ),
  TourStep(
    targetKey: kTourFilterBarKey,
    tabIndex: 0,
    title: 'Month, Year & Meter Filters',
    description: 'Yahan se Month / Year / Meter / Site chunein. "This Month" '
        'mode se current bill aur "All Years" se poora historical comparison '
        'milta hai.',
  ),
  TourStep(
    targetKey: kTourFabReadingKey,
    tabIndex: 0,
    title: 'Reading Entry — Quick Add',
    description: 'Nayi reading dene ke liye yah button tap karein — meter ke '
        'current kWh / kVAh display values daalein; app consumption khud '
        'calculate karega.',
  ),
  TourStep(
    targetKey: kTourFabMeterKey,
    tabIndex: 0,
    title: 'Add Your First Meter',
    description: '"Add Your Meter" se meter naam, site aur contract demand '
        'add karein. Issi meter ki readings aur bill estimation banegi.',
  ),
  TourStep(
    targetKey: kTourEntryKey,
    tabIndex: 1,
    title: 'Reading Entry Tab',
    description: 'Har meter ki readings yahan daali jaati hain — kWh, kVAh, '
        'PF aur MD ke saath. Bill estimation, trends aur reports sab isi data '
        'pe based hain.',
  ),
  TourStep(
    targetKey: kTourAnalysisKey,
    tabIndex: 2,
    title: 'Analysis & Insights',
    description: 'Trends, month-vs-month comparison, demand breach warnings '
        'aur power-quality anomalies — sab kuch charts me yahan.',
  ),
  TourStep(
    targetKey: kTourReportsKey,
    tabIndex: 3,
    title: 'Reports & Bill Accuracy',
    description: 'Executive summary, bill-accuracy reconciliation aur PDF '
        'export — management-ready reports ek click me.',
  ),
  TourStep(
    targetKey: kTourMetersKey,
    tabIndex: 4,
    title: 'Meter Management',
    description: 'Saare meters ki list, search, edit / delete aur contract '
        'details — ek jagah. Yahan meter add ya update bhi kar sakte hain.',
  ),
  TourStep(
    targetKey: kTourImportKey,
    tabIndex: 5,
    title: 'Excel Import',
    description: 'Pehle se existing readings hain? Excel sample download '
        'karein, data bharein aur "Import Data" se bulk upload karein — '
        'manual entry ki zaroorat nahi.',
  ),
  TourStep(
    targetKey: kTourSidebarBillingKey,
    tabIndex: 0,
    allowMissing: true,
    title: 'Plan & Billing',
    description: 'Sidebar me "Plan & Billing" se subscription plans, payment '
        'history aur invoices manage hote hain — Razorpay ke through.',
  ),
  TourStep(
    targetKey: kTourSidebarSettingsKey,
    tabIndex: 0,
    allowMissing: true,
    title: 'Settings — Sab Kuch Yahan',
    description: 'Dark mode, tariff configuration, backup & restore, '
        'notifications aur "Show App Tour" replay — saare controls Settings '
        'me hain.',
  ),
  TourStep(
    targetKey: kTourBillingKpisKey,
    tabIndex: 0,
    title: 'Bill Health Score',
    description: 'Yeh cards aapki bill-health batate hain — PF check, demand '
        'charge aur opportunities. Inhi se estimated bill pehle hi kaata ja '
        'sakta hai.',
  ),
  TourStep(
    targetKey: kTourFilterBarKey,
    tabIndex: 0,
    title: 'This Month vs All Years',
    description: 'Filter bar me "This Month" select karke current bill '
        'dekhein, ya "All Years" me purane saalon ka comparison. Day mode bhi '
        'yahin hai.',
  ),
  TourStep(
    tabIndex: 0,
    title: 'Tour Complete!',
    description: 'Bas itna hi! Kabhi bhi Settings → System tab → "Help & User '
        'Guide" kholkar guide padhein, ya tour dobara replay karein. '
        'Happy saving!',
  ),
];

/// Help & user-guide content shown from Settings → Help & User Guide.
class HelpSection {
  const HelpSection({
    required this.title,
    required this.icon,
    required this.points,
  });

  final String title;
  final IconData icon;
  final List<String> points;
}

const kHelpSections = <HelpSection>[
  HelpSection(
    title: 'Dashboard',
    icon: Icons.dashboard_outlined,
    points: [
      'Filters: month, year, meter, site — sabse upar.',
      'KPI cards: bill, consumption, demand, PF, health score.',
      '"This Month vs All Years" filter se comparison.',
    ],
  ),
  HelpSection(
    title: 'Reading Entry',
    icon: Icons.edit_note_outlined,
    points: [
      'Meter ke display values daalein (kWh / kVAh).',
      'Consumption automatically calculate hota hai.',
      'Date/time, PF, MD bhi daal sakte hain.',
    ],
  ),
  HelpSection(
    title: 'Analysis',
    icon: Icons.analytics_outlined,
    points: [
      'Trends: demand, monthly consumption, PF.',
      'MD breach prediction — over-download warnings.',
      'Anomaly highlights: unusual readings.',
    ],
  ),
  HelpSection(
    title: 'Reports',
    icon: Icons.description_outlined,
    points: [
      'Executive summary + reading history.',
      'PDF export — logo ke saath ready report.',
      'Bill accuracy: estimate vs actual.',
    ],
  ),
  HelpSection(
    title: 'Meter Management',
    icon: Icons.speed_outlined,
    points: [
      'Add / edit / delete meters.',
      'Contract demand aur multiplying factor yahan set hote hain.',
    ],
  ),
  HelpSection(
    title: 'Excel Import',
    icon: Icons.file_upload_outlined,
    points: [
      'Excel sample download karke bharein.',
      '"Import Data" se column mapping + preview ke saath upload.',
    ],
  ),
  HelpSection(
    title: 'Plan & Billing',
    icon: Icons.workspace_premium_outlined,
    points: [
      'Free plan ka meter limit check karein.',
      'Upgrade + payment history — Razorpay se.',
    ],
  ),
  HelpSection(
    title: 'Settings',
    icon: Icons.settings_outlined,
    points: [
      'Appearance: dark mode.',
      'Billing: tariff category & rates (MERC).',
      'System: backup (encrypted), restore, reset, delete account.',
      'Tour dobara chalaane ke liye "Show App Tour".',
    ],
  ),
];

/// Static channel used by Settings → "Show App Tour" to ask the hub to launch
/// the tour again (see `main_navigation_hub.dart`).
class TourLauncher {
  TourLauncher._();

  static final ValueNotifier<int> _request = ValueNotifier<int>(0);

  /// Listeners receive a bump every time a new tour is requested.
  static ValueListenable<int> get request => _request;

  /// Ask the navigation hub to start the tour.
  static void start() => _request.value++;
}

/// Opens the tour overlay on top of the current navigator stack.
Future<void> showAppTour({
  required BuildContext context,
  required List<TourStep> steps,
  required void Function(int tabIndex) switchTab,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'App tour',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _TourOverlay(steps: steps, switchTab: switchTab),
  );
}

/// Help & user-guide dialog (Settings → System → Help & User Guide).
Future<void> showHelpDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Help & User Guide'),
      content: SizedBox(
        width: 560,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final section in kHelpSections)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      section.icon,
                      size: 22,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          for (final point in section.points)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '• $point',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Support & grievances',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Email: Mrvikas_kamble@rediffmail.com',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay({required this.steps, required this.switchTab});

  final List<TourStep> steps;
  final void Function(int tabIndex) switchTab;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay>
    with WidgetsBindingObserver {
  int _index = 0;
  int _currentTab = 0;
  bool _textOnly = false;
  Rect? _hole;

  TourStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Window resized (web/desktop) — re-measure the current target.
  @override
  void didChangeMetrics() {
    final ctx = _step.targetKey?.currentContext;
    if (ctx != null && ctx.mounted) _measure(ctx);
  }

  Future<void> _resolve() async {
    final step = _step;
    if (step.tabIndex != _currentTab) {
      widget.switchTab(step.tabIndex);
      _currentTab = step.tabIndex;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
    }
    final ctx = step.targetKey?.currentContext;
    var current = ctx;
    var tries = 0;
    while (current == null &&
        step.targetKey != null &&
        !step.allowMissing &&
        tries < 60) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      current = step.targetKey!.currentContext;
      tries++;
    }
    if (!mounted) return;
    if (current == null) {
      // Target legitimately absent (allowMissing, e.g. drawer on mobile).
      setState(() {
        _textOnly = true;
        _hole = null;
      });
      return;
    }
    if (!current.mounted) return;
    await _ensureVisible(current);
    if (!mounted || !current.mounted) return;
    _measure(current);
  }

  Future<void> _ensureVisible(BuildContext ctx) async {
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return;
    final viewport = MediaQuery.sizeOf(context);
    final pos = box.localToGlobal(Offset.zero);
    final rect = pos & box.size;
    final fullyVisible = rect.top >= 0 &&
        rect.bottom <= viewport.height &&
        rect.left >= 0 &&
        rect.right <= viewport.width;
    if (fullyVisible) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  void _measure(BuildContext ctx) {
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !mounted) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _hole = rect;
      _textOnly = false;
    });
  }

  void _stepTo(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.steps.length) return;
    setState(() {
      _index = next;
      _textOnly = false;
      _hole = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  void _close() => Navigator.of(context).pop();

  double _bubbleHeight(TourStep step) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final titleLines = (step.title.length / 28).ceil().clamp(1, 2);
    final descLines = (step.description.length / 48).ceil().clamp(1, 3);
    final base =
        20 + titleLines * 21.0 + 10 + descLines * 19.5 + 44 + 20;
    return (base * scale).clamp(150.0, 380.0).toDouble();
  }

  Widget _buildBubble(Size viewport, TourStep step) {
    final isLast = _index == widget.steps.length - 1;
    final colorScheme = Theme.of(context).colorScheme;
    final w = (viewport.width - 32).clamp(0.0, 420.0);
    final h = _bubbleHeight(step);
    return SizedBox(
      width: w,
      height: h,
      child: Card(
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      step.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_index + 1}/${widget.steps.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Text(
                  step.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  TextButton(
                    onPressed: _close,
                    child: const Text('Skip'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _index == 0 ? null : () => _stepTo(-1),
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Back'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: () => isLast ? _close() : _stepTo(1),
                    icon: Icon(
                      isLast ? Icons.check_rounded : Icons.chevron_right,
                      size: 18,
                    ),
                    label: Text(isLast ? 'Done' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final step = _step;
    final hole = _hole;
    final scrim = Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.84)
        : Colors.black.withValues(alpha: 0.72);

    Widget? bubble;
    if (hole != null && !_textOnly) {
      final bW = (viewport.width - 32).clamp(0.0, 420.0);
      final bH = _bubbleHeight(step);
      const gap = 14.0;
      final below = hole.bottom + gap + bH <= viewport.height - 16;
      final top = below
          ? hole.bottom + gap
          : (viewport.height - bH - 16).clamp(16.0, double.infinity);
      final left = (hole.center.dx - bW / 2).clamp(16.0, viewport.width - bW);
      final arrowColor = Theme.of(context).cardColor;
      bubble = Positioned(
        left: left,
        top: top,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (below)
              CustomPaint(
                size: const Size(24, 10),
                painter: _ArrowPainter(
                  color: arrowColor,
                  direction: _ArrowDirection.up,
                ),
              ),
            _buildBubble(viewport, step),
            if (!below)
              CustomPaint(
                size: const Size(24, 10),
                painter: _ArrowPainter(
                  color: arrowColor,
                  direction: _ArrowDirection.down,
                ),
              ),
          ],
        ),
      );
    } else if (_textOnly) {
      bubble = Center(
        child: SizedBox(
          width: (viewport.width - 40).clamp(0.0, 400.0),
          child: _buildBubble(Size(viewport.width, viewport.height), step),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _SpotlightPainter(hole: hole, color: scrim)),
          ?bubble,
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.color});

  final Rect? hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()..addRect(Offset.zero & size);
    final hole = this.hole;
    if (hole != null) {
      final cut = Path()
        ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(14)));
      canvas.drawPath(
        Path.combine(PathOperation.difference, scrim, cut),
        Paint()..color = color,
      );
    } else {
      canvas.drawPath(scrim, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.color != color;
}

enum _ArrowDirection { up, down }

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.color, required this.direction});

  final Color color;
  final _ArrowDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (direction == _ArrowDirection.up) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.direction != direction;
}