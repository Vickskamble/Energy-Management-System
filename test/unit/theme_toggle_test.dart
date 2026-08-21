import 'package:ems/core/theme/app_theme.dart';
import 'package:ems/core/widgets/app_shell.dart';
import 'package:ems/presentation/auth_bloc/auth_bloc.dart';
import 'package:ems/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Drives the exact production wiring: MaterialApp owns themeMode, and the
/// toggle callback flips it via setState — identical to
/// `_EmsAppState._toggleTheme` in main.dart. With that, Theme.of(context)
/// under the Navigator updates live, which is what the app relies on.
class _ThemeHarness extends StatefulWidget {
  const _ThemeHarness();

  @override
  State<_ThemeHarness> createState() => _ThemeHarnessState();
}

class _ThemeHarnessState extends State<_ThemeHarness> {
  ThemeMode themeMode = ThemeMode.dark;

  void _toggle() {
    setState(() {
      themeMode =
          themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: _buildShell(),
    );
  }

  Widget _buildShell() {
    return AppShell(
      title: 'Dashboard',
      selectedIndex: 0,
      onItemSelected: (_) {},
      body: const SizedBox(),
      userName: 'demo',
      userEmail: 'demo@powerems.com',
      onLogout: () {},
      onThemeToggle: _toggle,
      isDark: themeMode == ThemeMode.dark,
      notificationCount: 0,
    );
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<ThemeMode> readMode(WidgetTester tester) async {
    await tester.pumpAndSettle();
    return tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
  }

  testWidgets('sidebar toggle flips themeMode dark -> light -> dark',
      (tester) async {
    await tester.pumpWidget(const _ThemeHarness());
    expect(await readMode(tester), ThemeMode.dark);
    // Dark active -> "switch to light" icon is shown.
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    expect(await readMode(tester), ThemeMode.light);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(AppShell))).brightness,
        Brightness.light);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    expect(await readMode(tester), ThemeMode.dark);
  });

  testWidgets(
      'Settings Dark Mode switch flips the theme and tracks it live '
      '(no stale snapshot)', (tester) async {
    ThemeMode mode = ThemeMode.dark;
    late StateSetter setter;
    final authBloc = AuthBloc();
    addTearDown(authBloc.close);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setter = setState;
          return MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: BlocProvider.value(
              value: authBloc,
              child: SettingsScreen(
                onToggleTheme: () => setState(() {
                  mode = mode == ThemeMode.light
                      ? ThemeMode.dark
                      : ThemeMode.light;
                }),
              ),
            ),
          );
        },
      ),
    );
    setter;

    // The Dark Mode switch lives on the Appearance tab (index 1); TabBarView
    // only builds the visible tab, so navigate there first.
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);
    expect(find.text('Dark theme active'), findsOneWidget);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(mode, ThemeMode.light);
    expect(Theme.of(tester.element(switchFinder)).brightness,
        Brightness.light);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
    expect(find.text('Light theme active'), findsOneWidget);
    expect(find.text('Dark theme active'), findsNothing);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(mode, ThemeMode.dark);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);
    expect(find.text('Dark theme active'), findsOneWidget);
  });
}
