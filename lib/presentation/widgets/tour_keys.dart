import 'package:flutter/widgets.dart';

/// GlobalKeys used by the onboarding tour to spotlight UI targets.
///
/// Keys live here so that both the tour engine (`app_tour.dart`) and the
/// pages can share the same key instances without circular imports.
final kTourFilterBarKey = GlobalKey();
final kTourDashboardKpisKey = GlobalKey();
final kTourBillingKpisKey = GlobalKey();
final kTourFabReadingKey = GlobalKey();
final kTourFabMeterKey = GlobalKey();
final kTourEntryKey = GlobalKey();
final kTourAnalysisKey = GlobalKey();
final kTourReportsKey = GlobalKey();
final kTourMetersKey = GlobalKey();
final kTourImportKey = GlobalKey();

final kTourSidebarBillingKey = GlobalKey();
final kTourSidebarSettingsKey = GlobalKey();

/// Sidebar item key for a given sidebar index — `null` when the item is not
/// part of the tour (no highlight requested).
GlobalKey? tourSidebarKey(int sidebarIndex) {
  switch (sidebarIndex) {
    case 5:
      return kTourSidebarSettingsKey;
    case 6:
      return kTourSidebarBillingKey;
    default:
      return null;
  }
}