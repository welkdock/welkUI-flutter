import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:welkui_flutter/src/widgets/welk_date_input.dart';
import 'package:welkui_flutter/src/widgets/welk_date_picker.dart';
import 'package:welkui_flutter/src/widgets/welk_picker_internal.dart';
import 'package:welkui_flutter/src/widgets/welk_time_picker.dart';

Widget host(
  Widget child, {
  double width = 400,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  bool reducedMotion = false,
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 900),
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reducedMotion,
      ),
      child: Directionality(
        textDirection: direction,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    ),
  ),
);

Finder action(String label) => find.byWidgetPredicate(
  (widget) => widget is PickerButton && widget.label == label,
);

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'calendar action is compact and inside the field in $direction',
      (tester) async {
        await tester.pumpWidget(
          host(
            WelkDateInput(
              label: 'Date',
              value: DateTime(2026, 10, 22),
              onChanged: (_) {},
            ),
            direction: direction,
          ),
        );
        final button = action('Open calendar');
        expect(tester.getSize(button), const Size(48, 48));
        final surface = find.descendant(
          of: button,
          matching: find.byType(PickerSurface),
        );
        expect(tester.getSize(surface), const Size(36, 36));
        final fieldSurface = find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(PickerSurface),
            )
            .first;
        final fieldRect = tester.getRect(fieldSurface);
        final buttonRect = tester.getRect(button);
        expect(buttonRect.left, greaterThan(fieldRect.left));
        expect(buttonRect.right, lessThan(fieldRect.right));
        expect(buttonRect.top, greaterThanOrEqualTo(fieldRect.top));
        expect(buttonRect.bottom, lessThanOrEqualTo(fieldRect.bottom));
        expect(
          find.descendant(of: fieldSurface, matching: button),
          findsOneWidget,
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(PickerCalendar), findsOneWidget);
      },
    );
  }

  testWidgets('removing date input owner removes its popup and barrier', (
    tester,
  ) async {
    var visible = true;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return visible
                ? WelkDateInput(
                    label: 'Date',
                    value: DateTime(2026, 10, 24),
                    onChanged: (_) => fail('Disposed input emitted a value.'),
                  )
                : const Text('Replacement');
          },
        ),
      ),
    );
    final baselineBarriers = find.byType(ModalBarrier).evaluate().length;
    await tester.tap(action('Open calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(PickerCalendar), findsOneWidget);
    expect(
      find.byType(ModalBarrier).evaluate().length,
      greaterThan(baselineBarriers),
    );
    update(() => visible = false);
    await tester.pumpAndSettle();
    expect(find.text('Replacement'), findsOneWidget);
    expect(find.byType(PickerCalendar), findsNothing);
    expect(find.byType(ModalBarrier).evaluate().length, baselineBarriers);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner cleanup never pops an unrelated route above its popup', (
    tester,
  ) async {
    var visible = true;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return visible
                ? WelkDateInput(
                    label: 'Date',
                    value: DateTime(2026, 10, 24),
                    onChanged: (_) {},
                  )
                : const Text('Replacement');
          },
        ),
      ),
    );
    final baselineBarriers = find.byType(ModalBarrier).evaluate().length;
    await tester.tap(action('Open calendar'));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Unrelated route')),
      ),
    );
    await tester.pumpAndSettle();
    update(() => visible = false);
    await tester.pumpAndSettle();
    expect(find.text('Unrelated route'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Replacement'), findsOneWidget);
    expect(find.byType(PickerCalendar), findsNothing);
    expect(find.byType(ModalBarrier).evaluate().length, baselineBarriers);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'full month exposes weekend dates without scrolling and respects range',
    (tester) async {
      DateTime? selected = DateTime(2026, 10, 22);
      var calls = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => WelkDatePicker(
              label: 'Adventure date',
              value: selected,
              minDate: DateTime(2026, 10, 10),
              maxDate: DateTime(2026, 10, 24),
              onChanged: (value) {
                calls++;
                setState(() => selected = value);
              },
            ),
          ),
          width: 360,
        ),
      );
      await tester.pump();
      expect(find.byType(RawScrollbar), findsNothing);
      final saturday = find.byKey(const ValueKey('date-2026-10-24'));
      expect(saturday.hitTestable(), findsOneWidget);
      await tester.tap(saturday);
      await tester.pump();
      expect(selected, DateTime(2026, 10, 24));
      expect(calls, 1);
      final unavailable = find.byKey(const ValueKey('date-2026-10-31'));
      expect(tester.widget<PickerButton>(unavailable).onPressed, isNull);
      await tester.tap(unavailable);
      await tester.pump();
      expect(calls, 1);
    },
  );

  testWidgets('initial Saturday selection is visible in LTR and RTL', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        host(
          WelkDatePicker(
            key: ValueKey(direction),
            label: 'Adventure date',
            value: DateTime(2026, 10, 24),
            onChanged: (_) {},
          ),
          width: 320,
          direction: direction,
        ),
      );
      await tester.pump();
      expect(find.byType(RawScrollbar), findsNothing);
      expect(
        find.byKey(const ValueKey('date-2026-10-24')).hitTestable(),
        findsOneWidget,
      );
      final viewport = tester.getRect(find.byType(PickerCalendar));
      final selectedRect = tester.getRect(
        find.byKey(const ValueKey('date-2026-10-24')),
      );
      expect(selectedRect.left, greaterThanOrEqualTo(viewport.left));
      expect(selectedRect.right, lessThanOrEqualTo(viewport.right));
      expect(tester.takeException(), isNull);
    }
  });

  for (final width in [240.0, 320.0, 360.0, 600.0]) {
    for (final direction in TextDirection.values) {
      for (final popup in [false, true]) {
        testWidgets(
          'full Monday-Sunday month at $width, $direction, popup=$popup',
          (tester) async {
            tester.view.physicalSize = Size(width, 1400);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            DateTime? selected;
            await tester.pumpWidget(
              host(
                StatefulBuilder(
                  builder: (context, setState) {
                    void select(DateTime? value) =>
                        setState(() => selected = value);
                    // March 2026 requires six Monday-first rows.
                    return popup
                        ? WelkDateInput(
                            label: 'Date',
                            value: selected,
                            initialDisplayDate: DateTime(2026, 3),
                            onChanged: select,
                          )
                        : WelkDatePicker(
                            label: 'Date',
                            value: selected,
                            initialDisplayDate: DateTime(2026, 3),
                            onChanged: select,
                          );
                  },
                ),
                width: width,
                textScale: 2,
                direction: direction,
              ),
            );
            if (popup) {
              await tester.tap(action('Open calendar'));
            }
            await tester.pumpAndSettle();
            final calendar = find.byType(PickerCalendar);
            final bounds = tester.getRect(calendar);
            expect(tester.takeException(), isNull);
            expect(
              find.descendant(of: calendar, matching: find.byType(Scrollable)),
              findsNothing,
            );
            for (final label in [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ]) {
              final rect = tester.getRect(find.text(label));
              expect(rect.left, greaterThanOrEqualTo(bounds.left - 0.01));
              expect(rect.right, lessThanOrEqualTo(bounds.right + 0.01));
            }
            final monday = tester.getCenter(find.text('Mon')).dx;
            final sunday = tester.getCenter(find.text('Sun')).dx;
            expect(
              monday,
              direction == TextDirection.ltr
                  ? lessThan(sunday)
                  : greaterThan(sunday),
            );
            for (var day = 1; day <= 31; day++) {
              final cell = find.byKey(
                ValueKey('date-2026-03-${day.toString().padLeft(2, '0')}'),
              );
              final rect = tester.getRect(cell);
              expect(rect.left, greaterThanOrEqualTo(bounds.left - 0.01));
              expect(rect.right, lessThanOrEqualTo(bounds.right + 0.01));
              expect(cell.hitTestable(), findsOneWidget);
            }
            final firstSunday = tester.getCenter(
              find.byKey(const ValueKey('date-2026-03-01')),
            );
            expect(firstSunday.dx, closeTo(sunday, 0.01));
            await tester.tap(find.byKey(const ValueKey('date-2026-03-29')));
            await tester.pumpAndSettle();
            expect(selected, DateTime(2026, 3, 29));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('Home and End follow Monday-first calendar weeks', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        WelkDatePicker(
          label: 'Date',
          value: DateTime(2026, 10, 22),
          onChanged: (_) {},
        ),
      ),
    );
    final thursday = find.byKey(const ValueKey('date-2026-10-22'));
    tester.widget<PickerButton>(thursday).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(
      tester
          .widget<PickerButton>(find.byKey(const ValueKey('date-2026-10-19')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(
      tester
          .widget<PickerButton>(find.byKey(const ValueKey('date-2026-10-25')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('calendar has no scrollbar when all columns fit', (tester) async {
    await tester.pumpWidget(
      host(
        PickerCalendar(value: DateTime(2026, 10, 24), onChanged: (_) {}),
        width: 500,
      ),
    );
    await tester.pump();
    expect(find.byType(RawScrollbar), findsNothing);
    expect(
      find.byKey(const ValueKey('date-2026-10-24')).hitTestable(),
      findsOneWidget,
    );
  });

  for (final popup in [false, true]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        '${popup ? 'popup' : 'inline'} calendar jumps to 2001 in $direction',
        (tester) async {
          DateTime? selected = DateTime(2026, 10, 22);
          var changes = 0;
          await tester.pumpWidget(
            host(
              StatefulBuilder(
                builder: (context, setState) {
                  void select(DateTime? date) => setState(() {
                    selected = date;
                    changes++;
                  });
                  return popup
                      ? WelkDateInput(
                          label: 'Date',
                          value: selected,
                          onChanged: select,
                        )
                      : WelkDatePicker(
                          label: 'Date',
                          value: selected,
                          onChanged: select,
                        );
                },
              ),
              width: 320,
              textScale: 2,
              direction: direction,
            ),
          );
          if (popup) {
            await tester.tap(action('Open calendar'));
            await tester.pumpAndSettle();
          }
          await tester.tap(action('Choose month and year'));
          await tester.pumpAndSettle();
          final years = find.descendant(
            of: find.byKey(const ValueKey('calendar-years')),
            matching: find.byType(Scrollable),
          );
          expect(find.byKey(const ValueKey('year-2026')), findsOneWidget);
          final year = find.byKey(const ValueKey('year-2001'));
          await tester.scrollUntilVisible(year, -180, scrollable: years);
          await tester.pumpAndSettle();
          await tester.tap(year);
          await tester.pumpAndSettle();
          final month = find.byKey(const ValueKey('month-2001-2'));
          await tester.ensureVisible(month);
          await tester.tap(month);
          await tester.pumpAndSettle();
          expect(find.text('February 2001'), findsOneWidget);
          expect(selected, DateTime(2026, 10, 22));
          expect(changes, 0);
          final day = find.byKey(const ValueKey('date-2001-02-14'));
          await tester.ensureVisible(day);
          await tester.tap(day);
          await tester.pumpAndSettle();
          expect(selected, DateTime(2001, 2, 14));
          expect(changes, 1);
          if (popup) expect(find.byType(PickerCalendar), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('year and month selection respect date bounds', (tester) async {
    await tester.pumpWidget(
      host(
        WelkDatePicker(
          label: 'Date',
          value: DateTime(2002, 10, 22),
          minDate: DateTime(2001, 6, 15),
          maxDate: DateTime(2003, 2, 3),
          onChanged: (_) {},
        ),
      ),
    );
    await tester.tap(action('Choose month and year'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('year-2000')), findsNothing);
    expect(find.byKey(const ValueKey('year-2004')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('year-2001')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PickerButton>(find.byKey(const ValueKey('month-2001-5')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('month-2001-6')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PickerButton>(find.byKey(const ValueKey('date-2001-06-14')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<PickerButton>(find.byKey(const ValueKey('date-2001-06-15')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(action('Choose month and year'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('year-2003')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PickerButton>(find.byKey(const ValueKey('month-2003-3')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('month-2003-2')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PickerButton>(find.byKey(const ValueKey('date-2003-02-04')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('disabled calendar cannot open year and month selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(WelkDatePicker(label: 'Date', value: DateTime(2026, 10, 22))),
    );
    expect(
      tester.widget<PickerButton>(action('Choose month and year')).onPressed,
      isNull,
    );
  });

  testWidgets('calendar resets selectors when controlled bounds change', (
    tester,
  ) async {
    late StateSetter update;
    DateTime? minDate;
    var changes = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return WelkDatePicker(
              label: 'Date',
              value: null,
              initialDisplayDate: DateTime(2026, 10),
              minDate: minDate,
              onChanged: (_) => changes++,
            );
          },
        ),
      ),
    );
    for (final year in [2027, 2028]) {
      await tester.tap(action('Choose month and year'));
      await tester.pumpAndSettle();
      if (year == 2028) {
        await tester.tap(find.byKey(const ValueKey('year-2027')));
        await tester.pumpAndSettle();
      }
      update(() => minDate = DateTime(year, 6, 15));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-years')), findsNothing);
      expect(find.text('June $year'), findsOneWidget);
      expect(action('Choose month and year'), findsOneWidget);
    }
    await tester.tap(action('Choose month and year'));
    await tester.pumpAndSettle();
    await tester.tap(action('Show calendar'));
    await tester.pumpAndSettle();
    expect(find.text('June 2028'), findsOneWidget);
    expect(changes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker actions do not add invisible keyboard traversal stops', (
    tester,
  ) async {
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(
      host(
        Row(
          children: [
            PickerButton(
              label: 'First',
              focusNode: first,
              onPressed: () {},
              child: const Text('First'),
            ),
            PickerButton(
              label: 'Second',
              focusNode: second,
              onPressed: () {},
              child: const Text('Second'),
            ),
          ],
        ),
      ),
    );
    first.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(second.hasPrimaryFocus, isTrue);
  });

  test('WelkTime preserves seconds, equality and TimeOfDay conversion', () {
    const time = WelkTime(hour: 23, minute: 59, second: 58);
    expect(time.format(), '23:59');
    expect(time.format(showSeconds: true), '23:59:58');
    expect(time.copyWith(minute: 0).second, 58);
    expect(WelkTime.fromTimeOfDay(time.toTimeOfDay(), second: 58), time);
  });

  testWidgets('empty date controls use an explicit deterministic month', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        WelkDatePicker(
          label: 'Empty date',
          value: null,
          initialDisplayDate: DateTime(2026, 10, 24),
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('October 2026'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await tester.pumpWidget(
      host(
        WelkDateInput(
          label: 'Empty date',
          value: null,
          initialDisplayDate: DateTime(2026, 10, 24),
          onChanged: (_) {},
        ),
      ),
    );
    await tester.tap(action('Open calendar'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    await tester.tap(action('Close calendar'));
    await tester.pumpAndSettle();
  });

  testWidgets('date edit validates dates, leap years, range and clearing', (
    tester,
  ) async {
    DateTime? selected = DateTime(2024, 2, 20);
    var calls = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => WelkDatePicker(
            label: 'Date',
            value: selected,
            minDate: DateTime(2024, 2, 10),
            maxDate: DateTime(2024, 2, 29),
            onChanged: (value) {
              calls++;
              setState(() => selected = value);
            },
          ),
        ),
      ),
    );
    final field = find.byType(TextField);
    for (final invalid in ['2024-02-30', '2023-02-29', '2024-2-12']) {
      await tester.enterText(field, invalid);
      await tester.pump();
      expect(
        find.text('Enter a valid date in YYYY-MM-DD format.'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((e) => e.data)
            .join('|'),
      );
    }
    await tester.enterText(field, '2024-02-09');
    await tester.pump();
    expect(find.text('Choose a date on or after 2024-02-10.'), findsOneWidget);
    await tester.enterText(field, '2024-03-01');
    await tester.pump();
    expect(find.text('Choose a date on or before 2024-02-29.'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(field, '2024-02-29');
    await tester.pump();
    expect(selected, DateTime(2024, 2, 29));
    await tester.enterText(field, '');
    await tester.pump();
    expect(selected, isNull);
    expect(calls, 2);
  });

  testWidgets('date selection respects range and navigation limits', (
    tester,
  ) async {
    DateTime? selected = DateTime(2026, 10, 22);
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => WelkDatePicker(
            label: 'Date',
            value: selected,
            minDate: DateTime(2026, 10, 10),
            maxDate: DateTime(2026, 11, 3),
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      ),
    );
    expect(
      tester.widget<PickerButton>(action('Previous month')).onPressed,
      isNull,
    );
    final unavailable = find.byKey(const ValueKey('date-2026-10-09'));
    expect(tester.widget<PickerButton>(unavailable).onPressed, isNull);
    final day = find.byKey(const ValueKey('date-2026-10-20'));
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pump();
    expect(selected, DateTime(2026, 10, 20));
    await tester.tap(action('Next month'));
    await tester.pump();
    expect(find.text('November 2026'), findsOneWidget);
    expect(tester.widget<PickerButton>(action('Next month')).onPressed, isNull);
    expect(
      tester
          .widget<PickerButton>(find.byKey(const ValueKey('date-2026-11-04')))
          .onPressed,
      isNull,
    );
    await tester.tap(action('Previous month'));
    await tester.pump();
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('calendar keyboard crosses month and obeys bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        WelkDatePicker(
          label: 'Date',
          value: DateTime(2026, 10, 31),
          maxDate: DateTime(2026, 11, 2),
          onChanged: (_) {},
        ),
      ),
    );
    final day = tester.widget<PickerButton>(
      find.byKey(const ValueKey('date-2026-10-31')),
    );
    day.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('November 2026'), findsOneWidget);
    final next = tester.widget<PickerButton>(
      find.byKey(const ValueKey('date-2026-11-01')),
    );
    expect(next.focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      tester
          .widget<PickerButton>(find.byKey(const ValueKey('date-2026-11-02')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('controlled parent update replaces invalid draft and month', (
    tester,
  ) async {
    DateTime? date = DateTime(2026, 10, 22);
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return WelkDatePicker(
              label: 'Date',
              value: date,
              onChanged: (_) {},
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'bad');
    update(() => date = DateTime(2027, 1, 1));
    await tester.pump();
    expect(find.text('2027-01-01'), findsOneWidget);
    expect(find.text('January 2027'), findsOneWidget);
    expect(find.text('Enter a valid date in YYYY-MM-DD format.'), findsNothing);
  });

  testWidgets('date input opens custom popup, selects and restores focus', (
    tester,
  ) async {
    DateTime? date = DateTime(2026, 10, 22);
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => WelkDateInput(
            label: 'Date',
            value: date,
            onChanged: (value) => setState(() => date = value),
          ),
        ),
      ),
    );
    expect(find.byType(PickerCalendar), findsNothing);
    await tester.tap(action('Open calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(PickerCalendar), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    final day = find.byKey(const ValueKey('date-2026-10-20'));
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pumpAndSettle();
    expect(date, DateTime(2026, 10, 20));
    expect(find.byType(PickerCalendar), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.tap(action('Open calendar'));
    await tester.pumpAndSettle();
    await tester.tap(action('Close calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(PickerCalendar), findsNothing);
  });

  testWidgets('required and custom validation do not emit invalid values', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        WelkDateInput(
          label: 'Weekday',
          value: null,
          isRequired: true,
          validator: (date) =>
              date?.weekday == DateTime.saturday ? 'No Saturdays.' : null,
          onChanged: (_) => calls++,
        ),
      ),
    );
    expect(find.text('Choose a date.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '2026-10-24');
    await tester.pump();
    expect(
      find.text('No Saturdays.'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((e) => e.data)
          .join('|'),
    );
    expect(calls, 0);
  });

  testWidgets('invalid date range is rejected', (tester) async {
    await tester.pumpWidget(
      host(
        WelkDateInput(
          label: 'Date',
          value: null,
          minDate: DateTime(2026, 11),
          maxDate: DateTime(2026, 10),
          onChanged: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isArgumentError);
  });

  testWidgets('time edits validate format, ranges and real seconds', (
    tester,
  ) async {
    WelkTime? time = const WelkTime(hour: 14, minute: 30, second: 15);
    var calls = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => WelkTimePicker(
            label: 'Time',
            value: time,
            showSeconds: true,
            onChanged: (value) {
              calls++;
              setState(() => time = value);
            },
          ),
        ),
      ),
    );
    for (final invalid in ['24:00:00', '12:60:00', '12:00:60', '2:03:04']) {
      await tester.enterText(find.byType(TextField), invalid);
      await tester.pump();
      expect(
        find.text('Enter a valid time in HH:mm:ss format (24-hour).'),
        findsOneWidget,
      );
    }
    expect(calls, 0);
    await tester.enterText(find.byType(TextField), '23:59:58');
    await tester.pump();
    expect(time, const WelkTime(hour: 23, minute: 59, second: 58));
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(time, isNull);
    expect(calls, 2);
  });

  testWidgets('time columns select and scroll without losing other parts', (
    tester,
  ) async {
    WelkTime? time = const WelkTime(hour: 14, minute: 30, second: 15);
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => WelkTimePicker(
            label: 'Time',
            value: time,
            showSeconds: true,
            onChanged: (value) => setState(() => time = value),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('Seconds-16')));
    await tester.pump();
    expect(time, const WelkTime(hour: 14, minute: 30, second: 16));
    await tester.tap(find.byKey(const ValueKey('Hours-15')));
    await tester.pump();
    expect(time, const WelkTime(hour: 15, minute: 30, second: 16));
    await tester.drag(
      find.byKey(const ValueKey('time-Minutes')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    final options = find.byWidgetPredicate(
      (widget) => widget is PickerButton && widget.label.startsWith('Minutes '),
    );
    expect(options, findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden seconds survive editing and controlled mode changes', (
    tester,
  ) async {
    WelkTime? time = const WelkTime(hour: 14, minute: 30, second: 17);
    var seconds = false;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return WelkTimePicker(
              label: 'Time',
              value: time,
              showSeconds: seconds,
              onChanged: (value) => setState(() => time = value),
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '16:45');
    await tester.pump();
    expect(time, const WelkTime(hour: 16, minute: 45, second: 17));
    update(() => seconds = true);
    await tester.pump();
    expect(find.text('16:45:17'), findsOneWidget);
    expect(find.text('Seconds'), findsOneWidget);
  });

  testWidgets('time keyboard and adjustable semantics work', (tester) async {
    WelkTime? time = const WelkTime(hour: 23, minute: 59);
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => WelkTimePicker(
            label: 'Time',
            value: time,
            onChanged: (value) => setState(() => time = value),
          ),
        ),
      ),
    );
    final column = find
        .ancestor(
          of: find.byKey(const ValueKey('time-Hours')),
          matching: find.byType(Focus),
        )
        .first;
    final focus = tester.widget<Focus>(column);
    Focus.of(tester.element(find.byKey(const ValueKey('time-Hours'))))
        .requestFocus();
    expect(focus.onKeyEvent, isNotNull);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(time?.hour, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(time?.hour, 23);
  });

  testWidgets('null callbacks disable every picker action and editor', (
    tester,
  ) async {
    for (final widget in [
      WelkDatePicker(label: 'Date', value: DateTime(2026, 10, 22)),
      WelkDateInput(label: 'Date', value: DateTime(2026, 10, 22)),
      const WelkTimePicker(
        label: 'Time',
        value: WelkTime(hour: 14, minute: 30),
        showSeconds: true,
      ),
    ]) {
      await tester.pumpWidget(host(widget));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      for (final button in tester.widgetList<PickerButton>(
        find.byType(PickerButton),
      )) {
        expect(button.onPressed, isNull);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('time required and custom validation suppress callbacks', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        WelkTimePicker(
          label: 'Office hours',
          value: null,
          isRequired: true,
          validator: (time) =>
              time != null && time.hour < 9 ? 'Choose 09:00 or later.' : null,
          onChanged: (_) => calls++,
        ),
      ),
    );
    expect(find.text('Choose a time.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '08:59');
    await tester.pump();
    expect(find.text('Choose 09:00 or later.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('Choose a time.'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(find.byType(TextField), '09:00');
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('popup retains RTL, text scale and updates parent date bounds', (
    tester,
  ) async {
    var min = DateTime(2026, 10, 10);
    var max = DateTime(2026, 10, 28);
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return WelkDateInput(
              label: 'Date',
              value: DateTime(2026, 10, 22),
              minDate: min,
              maxDate: max,
              onChanged: (_) {},
            );
          },
        ),
        direction: TextDirection.rtl,
        textScale: 1.5,
        reducedMotion: true,
      ),
    );
    await tester.tap(action('Open calendar'));
    await tester.pumpAndSettle();
    final calendarContext = tester.element(find.byType(PickerCalendar));
    expect(Directionality.of(calendarContext), TextDirection.rtl);
    expect(MediaQuery.textScalerOf(calendarContext).scale(16), 24);
    expect(MediaQuery.disableAnimationsOf(calendarContext), isTrue);
    expect(tester.widget<PickerButton>(action('Next month')).onPressed, isNull);
    update(() {
      min = DateTime(2026, 11, 1);
      max = DateTime(2026, 12, 1);
    });
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(
      tester.widget<PickerButton>(action('Next month')).onPressed,
      isNotNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(PickerCalendar), findsNothing);
  });

  testWidgets('RTL calendar keyboard follows visual direction', (tester) async {
    await tester.pumpWidget(
      host(
        WelkDatePicker(
          label: 'Date',
          value: DateTime(2026, 10, 20),
          onChanged: (_) {},
        ),
        direction: TextDirection.rtl,
      ),
    );
    tester
        .widget<PickerButton>(find.byKey(const ValueKey('date-2026-10-20')))
        .focusNode!
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(
      tester
          .widget<PickerButton>(find.byKey(const ValueKey('date-2026-10-21')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('RTL narrow large text reduced-motion layouts do not overflow', (
    tester,
  ) async {
    for (final widget in [
      WelkDatePicker(
        label: 'A long adventure date label',
        value: DateTime(2026, 10, 22),
        onChanged: (_) {},
      ),
      WelkDateInput(
        label: 'A long adventure date label',
        value: DateTime(2026, 10, 22),
        onChanged: (_) {},
      ),
      WelkTimePicker(
        label: 'A long adventure time label',
        value: const WelkTime(hour: 14, minute: 30, second: 15),
        showSeconds: true,
        onChanged: (_) {},
      ),
    ]) {
      await tester.pumpWidget(
        host(
          widget,
          width: 240,
          textScale: 2,
          direction: TextDirection.rtl,
          reducedMotion: true,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (widget is WelkDateInput) {
        await tester.ensureVisible(action('Open calendar'));
        await tester.tap(action('Open calendar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(action('Close calendar'));
        await tester.tap(action('Close calendar'));
        await tester.pumpAndSettle();
      }
    }
  });
}
