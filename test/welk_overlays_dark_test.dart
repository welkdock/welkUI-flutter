import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:welkui_flutter/src/painting/welk_shape_border.dart';
import 'package:welkui_flutter/src/theme/welk_theme.dart';
import 'package:welkui_flutter/src/widgets/welk_date_input.dart';
import 'package:welkui_flutter/src/widgets/welk_date_picker.dart';
import 'package:welkui_flutter/src/widgets/welk_dialog.dart';
import 'package:welkui_flutter/src/widgets/welk_drawer.dart';
import 'package:welkui_flutter/src/widgets/welk_picker_internal.dart';
import 'package:welkui_flutter/src/widgets/welk_snack_bar.dart';
import 'package:welkui_flutter/src/widgets/welk_time_picker.dart';
import 'package:welkui_flutter/src/widgets/welk_tooltip.dart';

const tokens = WelkThemeData();
const dark = WelkColors(tokens, isDark: true);
const light = WelkColors(tokens, isDark: false);

Widget host(Widget child, {bool? preference, bool flutterDark = true}) =>
    MaterialApp(
      home: WelkTheme(
        data: tokens.copyWith(darkMode: preference),
        child: Theme(
          data: flutterDark ? ThemeData.dark() : ThemeData.light(),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );

void expectSurface(WidgetTester tester, Finder root, WelkColors colors) {
  final containers = tester.widgetList<Container>(
    find.descendant(of: root, matching: find.byType(Container)),
  );
  final surfaces = containers
      .map((container) => container.decoration)
      .whereType<ShapeDecoration>()
      .where((decoration) => decoration.color == colors.paper);
  expect(surfaces, isNotEmpty);
  final shape = surfaces.first.shape;
  if (shape is WelkShapeBorder) {
    expect(shape.strokeColor, colors.outline);
  }
  final shadows = tester
      .widgetList<CustomPaint>(
        find.descendant(of: root, matching: find.byType(CustomPaint)),
      )
      .map((paint) => paint.painter)
      .whereType<WelkHardShadowPainter>();
  expect(shadows.any((painter) => painter.color == colors.shadow), isTrue);
}

void main() {
  testWidgets('dialog text has no inherited underline by default', (
    tester,
  ) async {
    late BuildContext launcher;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            launcher = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final closed = showWelkDialog<void>(
      context: launcher,
      builder: (context) => const DefaultTextStyle(
        style: TextStyle(decoration: TextDecoration.underline),
        child: WelkDialog(
          title: Text('Dialog title'),
          child: Text('Dialog body'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['Dialog title', 'Dialog body', 'Okay']) {
      final richText = tester.widget<RichText>(
        find.descendant(of: find.text(text), matching: find.byType(RichText)),
      );
      expect(richText.text.style?.decoration, TextDecoration.none);
    }
    Navigator.of(tester.element(find.byType(WelkDialog))).pop();
    await tester.pumpAndSettle();
    await closed;
  });

  for (final snack in [false, true]) {
    for (final override in <bool?>[null, false, true]) {
      testWidgets(
        '${snack ? 'snackbar' : 'dialog'} follows live root preference with override $override',
        (tester) async {
          late BuildContext launcher;
          late StateSetter update;
          var isDark = false;
          await tester.pumpWidget(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return WelkTheme(
                  data: tokens.copyWith(darkMode: isDark),
                  child: MaterialApp(
                    home: Scaffold(
                      body: Builder(
                        builder: (context) {
                          launcher = context;
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          );
          WelkSnackBarController? controller;
          Future<void>? closed;
          if (snack) {
            controller = showWelkSnackBar(
              context: launcher,
              overRideDarkMode: override,
              message: const Text('Live notice'),
            );
          } else {
            closed = showWelkDialog<void>(
              context: launcher,
              overRideDarkMode: override,
              builder: (_) => const WelkDialog(title: Text('Live dialog')),
            );
          }
          await tester.pumpAndSettle();
          final root = find.byType(snack ? WelkSnackBar : WelkDialog);
          void check(bool darkMode) {
            final expected = darkMode ? dark : light;
            if (!snack) {
              expectSurface(tester, root, expected);
            }
            final shadows = tester
                .widgetList<CustomPaint>(
                  find.descendant(of: root, matching: find.byType(CustomPaint)),
                )
                .map((paint) => paint.painter)
                .whereType<WelkHardShadowPainter>();
            expect(
              shadows.any((paint) => paint.color == expected.shadow),
              isTrue,
            );
            final decorations = tester
                .widgetList<Container>(
                  find.descendant(of: root, matching: find.byType(Container)),
                )
                .map((container) => container.decoration);
            expect(
              decorations.any(
                (decoration) => snack
                    ? decoration is ShapeDecoration &&
                          decoration.color == expected.accent
                    : decoration is BoxDecoration &&
                          decoration.color == expected.accent,
              ),
              isTrue,
            );
          }

          check(override ?? false);
          update(() => isDark = true);
          await tester.pumpAndSettle();
          check(override ?? true);
          update(() => isDark = false);
          await tester.pumpAndSettle();
          check(override ?? false);
          if (snack) {
            controller!.close();
            await tester.pumpAndSettle();
            await controller.closed;
          } else {
            Navigator.of(tester.element(root)).pop();
            await tester.pumpAndSettle();
            await closed;
          }
        },
      );
    }
  }

  testWidgets('dialog captures local Flutter brightness and builder scope', (
    tester,
  ) async {
    late BuildContext launcher;
    bool? builderDark;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            launcher = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final closed = showWelkDialog<void>(
      context: launcher,
      builder: (context) {
        builderDark = WelkTheme.of(context).resolveColors(context).isDark;
        return const WelkDialog(title: Text('Dark dialog'));
      },
    );
    await tester.pumpAndSettle();
    expect(builderDark, isTrue);
    expectSurface(tester, find.byType(WelkDialog), dark);
    final header = tester.widget<Text>(find.text('Dark dialog'));
    expect(
      DefaultTextStyle.of(tester.element(find.byWidget(header))).style.color,
      dark.onFill(dark.accent),
    );
    Navigator.of(tester.element(find.byType(WelkDialog))).pop();
    await tester.pumpAndSettle();
    await closed;
  });

  testWidgets('drawer captures launch override outside its builder', (
    tester,
  ) async {
    late BuildContext launcher;
    bool? builderDark;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            launcher = context;
            return const SizedBox();
          },
        ),
        flutterDark: false,
      ),
    );
    final closed = showWelkDrawer<void>(
      context: launcher,
      overRideDarkMode: true,
      builder: (context) {
        builderDark = WelkTheme.of(context).resolveColors(context).isDark;
        return const WelkDrawer(title: Text('Drawer'), child: Text('Content'));
      },
    );
    await tester.pumpAndSettle();
    expect(builderDark, isTrue);
    expectSurface(tester, find.byType(WelkDrawer), dark);
    Navigator.of(tester.element(find.byType(WelkDrawer))).pop();
    await tester.pumpAndSettle();
    await closed;
  });

  testWidgets(
    'widget override wins over route override and global preference',
    (tester) async {
      late BuildContext launcher;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              launcher = context;
              return const SizedBox();
            },
          ),
          preference: true,
        ),
      );
      final closed = showWelkDialog<void>(
        context: launcher,
        overRideDarkMode: true,
        builder: (_) => const WelkDialog(
          title: Text('Light dialog'),
          overRideDarkMode: false,
        ),
      );
      await tester.pumpAndSettle();
      expectSurface(tester, find.byType(WelkDialog), light);
      Navigator.of(tester.element(find.byType(WelkDialog))).pop();
      await tester.pumpAndSettle();
      await closed;
    },
  );

  for (final override in <bool?>[null, false, true]) {
    testWidgets('date popup preserves local override $override', (
      tester,
    ) async {
      final expected = override == false ? light : dark;
      await tester.pumpWidget(
        host(
          WelkDateInput(
            label: 'Date',
            value: DateTime(2026, 10, 22),
            onChanged: (_) {},
            overRideDarkMode: override,
          ),
        ),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is PickerButton && widget.label == 'Open calendar',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PickerCalendar), findsOneWidget);
      final popup = find
          .ancestor(
            of: find.byType(PickerCalendar),
            matching: find.byType(PickerSurface),
          )
          .first;
      expectSurface(tester, popup, expected);
      Navigator.of(tester.element(find.byType(PickerCalendar))).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('inline date and time surfaces support independent overrides', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SingleChildScrollView(
          child: Column(
            children: [
              WelkDatePicker(
                label: 'Date',
                value: DateTime(2026, 10, 22),
                onChanged: (_) {},
                overRideDarkMode: false,
              ),
              WelkTimePicker(
                label: 'Time',
                value: const WelkTime(hour: 12, minute: 30),
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    expectSurface(tester, find.byType(WelkDatePicker), light);
    expectSurface(tester, find.byType(WelkTimePicker), dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('snack overlay captures local brightness and tints fills once', (
    tester,
  ) async {
    late BuildContext launcher;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            launcher = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final controller = showWelkSnackBar(
      context: launcher,
      message: const Text('Notice'),
      variant: WelkSnackBarVariant.warning,
    );
    await tester.pumpAndSettle();
    final root = find.byType(WelkSnackBar);
    final decorations = tester
        .widgetList<Container>(
          find.descendant(of: root, matching: find.byType(Container)),
        )
        .map((container) => container.decoration)
        .whereType<ShapeDecoration>();
    final surface = decorations.firstWhere(
      (decoration) => decoration.color == dark.warning,
    );
    expect((surface.shape as WelkShapeBorder).strokeColor, dark.outline);
    expect(
      DefaultTextStyle.of(tester.element(find.text('Notice'))).style.color,
      dark.onFill(dark.warning),
    );
    controller.close();
    await tester.pumpAndSettle();
    await controller.closed;
  });

  testWidgets(
    'time override wins over global light and validation is readable',
    (tester) async {
      await tester.pumpWidget(
        host(
          WelkTimePicker(
            label: 'Required time',
            value: null,
            isRequired: true,
            onChanged: (_) {},
            overRideDarkMode: true,
          ),
          preference: false,
        ),
      );
      expectSurface(tester, find.byType(WelkTimePicker), dark);
      expect(
        tester.widget<Text>(find.text('Choose a time.')).style!.color,
        dark.onFill(dark.error),
      );
      expect(
        tester.widget<Text>(find.text('HH:mm · 24-hour')).style!.color,
        dark.ink,
      );
    },
  );

  for (final override in <bool?>[null, false, true]) {
    testWidgets('tooltip captures resolved palette $override', (tester) async {
      await tester.pumpWidget(
        host(
          WelkTooltip(
            content: 'Tooltip content',
            overRideDarkMode: override,
            child: const Text('Target'),
          ),
        ),
      );
      await tester.longPress(find.text('Target'));
      await tester.pumpAndSettle();
      final text = find.text('Tooltip content');
      expect(text, findsOneWidget);
      final expected = override == false ? light : dark;
      expect(tester.widget<Text>(text).style!.color, expected.ink);
      final surfaces = tester.widgetList<Container>(
        find.ancestor(of: text, matching: find.byType(Container)),
      );
      expect(
        surfaces.any(
          (container) =>
              container.decoration is ShapeDecoration &&
              (container.decoration! as ShapeDecoration).color ==
                  expected.paper,
        ),
        isTrue,
      );
      Tooltip.dismissAllToolTips();
      await tester.pumpAndSettle();
    });
  }
}
