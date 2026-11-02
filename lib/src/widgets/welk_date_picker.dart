import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../painting/welk_shape_border.dart';
import '../theme/welk_theme.dart';
import 'welk_picker_internal.dart';

/// An inline, controlled calendar with an editable YYYY-MM-DD field.
///
/// Shows complete Monday-first weeks without horizontal scrolling. Day cells
/// adapt to available width, retaining at least 48 logical pixels of height.
/// Dates are local civil dates; time and UTC offsets are ignored. Invalid or
/// out-of-range edits remain visible but are not sent to [onChanged].
/// Tap the calendar heading to choose a year, then a month, before picking a day.
/// A null [onChanged] disables editing and selection.
class WelkDatePicker extends StatelessWidget {
  const WelkDatePicker({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.minDate,
    this.maxDate,
    this.initialDisplayDate,
    this.isRequired = false,
    this.validator,
    this.focusNode,
    this.autofocus = false,
    this.overRideDarkMode,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final DateTime? minDate;
  final DateTime? maxDate;

  /// Month initially displayed when [value] is null. Defaults to today.
  final DateTime? initialDisplayDate;
  final bool isRequired;
  final String? Function(DateTime?)? validator;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool? overRideDarkMode;

  @override
  Widget build(BuildContext context) => PickerDateControl(
    overRideDarkMode: overRideDarkMode,
    label: label,
    value: value,
    onChanged: onChanged,
    minDate: minDate,
    maxDate: maxDate,
    initialDisplayDate: initialDisplayDate,
    isRequired: isRequired,
    validator: validator,
    focusNode: focusNode,
    autofocus: autofocus,
  );
}

/// Shared implementation of the inline and popup date controls.
class PickerDateControl extends StatefulWidget {
  const PickerDateControl({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.minDate,
    this.maxDate,
    this.initialDisplayDate,
    this.isRequired = false,
    this.validator,
    this.focusNode,
    this.autofocus = false,
    this.popup = false,
    this.overRideDarkMode,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final DateTime? minDate;
  final DateTime? maxDate;
  final DateTime? initialDisplayDate;
  final bool isRequired;
  final String? Function(DateTime?)? validator;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool popup;
  final bool? overRideDarkMode;

  @override
  State<PickerDateControl> createState() => _PickerDateControlState();
}

class _PickerDateControlState extends State<PickerDateControl> {
  late final TextEditingController _controller;
  late final FocusNode _ownFocus;
  bool _dialogOpen = false;
  StateSetter? _refreshDialog;
  RawDialogRoute<DateTime>? _calendarRoute;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: pickerFormatDate(widget.value));
    _ownFocus = FocusNode();
  }

  @override
  void didUpdateWidget(PickerDateControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (pickerFormatDate(widget.value) != pickerFormatDate(oldWidget.value)) {
      _controller.text = pickerFormatDate(widget.value);
    }
    if (_dialogOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshDialog?.call(() {});
      });
    }
  }

  @override
  void dispose() {
    final route = _calendarRoute;
    _calendarRoute = null;
    _refreshDialog = null;
    if (route != null) {
      // The owner may be removed during a Navigator build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = route.navigator;
        if (navigator != null && navigator.mounted && route.isActive) {
          navigator.removeRoute(route);
        }
      });
    }
    _controller.dispose();
    _ownFocus.dispose();
    super.dispose();
  }

  String? _error(String text) {
    if (text.isEmpty) {
      return widget.isRequired
          ? 'Choose a date.'
          : widget.validator?.call(null);
    }
    final date = pickerParseDate(text);
    if (date == null) return 'Enter a valid date in YYYY-MM-DD format.';
    if (widget.minDate != null &&
        date.isBefore(pickerDateOnly(widget.minDate!))) {
      return 'Choose a date on or after ${pickerFormatDate(widget.minDate)}.';
    }
    if (widget.maxDate != null &&
        date.isAfter(pickerDateOnly(widget.maxDate!))) {
      return 'Choose a date on or before ${pickerFormatDate(widget.maxDate)}.';
    }
    return widget.validator?.call(date);
  }

  void _edit(String text) {
    setState(() {});
    if (_error(text) == null) widget.onChanged?.call(pickerParseDate(text));
  }

  void _select(DateTime date) {
    if (widget.onChanged == null) return;
    setState(() => _controller.text = pickerFormatDate(date));
    if (_error(_controller.text) == null) widget.onChanged?.call(date);
  }

  Future<void> _openCalendar() async {
    if (_dialogOpen || widget.onChanged == null) return;
    _dialogOpen = true;
    (widget.focusNode ?? _ownFocus).unfocus();
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final reducedMotion = welkAnimationsDisabled(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    final route = RawDialogRoute<DateTime>(
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: welkAnimationsDisabled(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        if (!mounted) return const SizedBox.shrink();
        return Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: MediaQuery.of(dialogContext).copyWith(
              textScaler: textScaler,
              disableAnimations: reducedMotion,
            ),
            child: themes.wrap(
              Builder(
                builder: (context) => WelkTheme.scope(
                  context,
                  overRideDarkMode: widget.overRideDarkMode,
                  child: StatefulBuilder(
                    builder: (popupContext, setState) {
                      if (!mounted) return const SizedBox.shrink();
                      _refreshDialog = setState;
                      return SafeArea(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            24,
                            16,
                            24 + MediaQuery.viewInsetsOf(dialogContext).bottom,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 336,
                              child: SingleChildScrollView(
                                child: Semantics(
                                  scopesRoute: true,
                                  namesRoute: true,
                                  label: 'Choose a date',
                                  explicitChildNodes: true,
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: PickerSurface(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            widget.label,
                                            style: pickerTextStyle(popupContext)
                                                .copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          PickerCalendar(
                                            value: widget.value,
                                            minDate: widget.minDate,
                                            maxDate: widget.maxDate,
                                            initialDisplayDate:
                                                widget.initialDisplayDate,
                                            onChanged: widget.onChanged == null
                                                ? null
                                                : (date) => Navigator.of(
                                                    dialogContext,
                                                  ).pop(date),
                                          ),
                                          const SizedBox(height: 8),
                                          PickerButton(
                                            label: 'Close calendar',
                                            onPressed: () =>
                                                Navigator.of(dialogContext)
                                                    .pop(),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    _calendarRoute = route;
    final date = await navigator.push<DateTime>(route);
    if (!mounted) return;
    if (_calendarRoute == route) _calendarRoute = null;
    _dialogOpen = false;
    _refreshDialog = null;
    if (date != null) _select(date);
    (widget.focusNode ?? _ownFocus).requestFocus();
  }

  @override
  Widget build(BuildContext context) => WelkTheme.scope(
    context,
    overRideDarkMode: widget.overRideDarkMode,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    pickerValidateDates(widget.value, widget.minDate, widget.maxDate);
    pickerValidateDates(widget.initialDisplayDate, null, null);
    final enabled = widget.onChanged != null;
    final editor = PickerEditor(
      controller: _controller,
      label: widget.label,
      hint: 'YYYY-MM-DD',
      enabled: enabled,
      error: _error(_controller.text),
      onChanged: _edit,
      focusNode: widget.focusNode ?? _ownFocus,
      autofocus: widget.autofocus,
      suffix: widget.popup
          ? PickerButton(
              label: 'Open calendar',
              disabledOpacity: 1,
              minimumSize: Size.zero,
              visualSize: const Size(36, 36),
              onPressed: enabled ? _openCalendar : null,
              color: WelkTheme.of(context).resolveColors(context).accent,
              rotation: -0.0349066,
              child: Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: WelkTheme.of(context).resolveColors(context).isDark
                    ? null
                    : WelkTheme.of(context).ink,
              ),
            )
          : null,
    );
    return SizedBox(
      width: 336,
      child: widget.popup
          ? DefaultTextStyle(style: pickerTextStyle(context), child: editor)
          : PickerSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  editor,
                  const SizedBox(height: 16),
                  PickerCalendar(
                    value: widget.value,
                    minDate: widget.minDate,
                    maxDate: widget.maxDate,
                    initialDisplayDate: widget.initialDisplayDate,
                    onChanged: enabled ? _select : null,
                  ),
                ],
              ),
            ),
    );
  }
}

class PickerCalendar extends StatefulWidget {
  const PickerCalendar({
    super.key,
    this.value,
    this.minDate,
    this.maxDate,
    this.initialDisplayDate,
    this.onChanged,
    this.overRideDarkMode,
  });

  final DateTime? value;
  final DateTime? minDate;
  final DateTime? maxDate;
  final DateTime? initialDisplayDate;
  final ValueChanged<DateTime>? onChanged;
  final bool? overRideDarkMode;

  @override
  State<PickerCalendar> createState() => _PickerCalendarState();
}

enum _CalendarView { days, years, months }

class _PickerCalendarState extends State<PickerCalendar> {
  late DateTime _month;
  _CalendarView _view = _CalendarView.days;
  final _dayFocus = List.generate(31, (_) => FocusNode());

  DateTime _bounded(DateTime date) {
    date = pickerDateOnly(date);
    if (widget.minDate != null &&
        date.isBefore(pickerDateOnly(widget.minDate!))) {
      return pickerDateOnly(widget.minDate!);
    }
    if (widget.maxDate != null &&
        date.isAfter(pickerDateOnly(widget.maxDate!))) {
      return pickerDateOnly(widget.maxDate!);
    }
    return date;
  }

  DateTime _initialMonth() {
    final date = _bounded(
      widget.value ?? widget.initialDisplayDate ?? DateTime.now(),
    );
    return DateTime(date.year, date.month);
  }

  @override
  void initState() {
    super.initState();
    _month = _initialMonth();
  }

  @override
  void didUpdateWidget(PickerCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (pickerFormatDate(widget.value) != pickerFormatDate(oldWidget.value) ||
        pickerFormatDate(widget.minDate) !=
            pickerFormatDate(oldWidget.minDate) ||
        pickerFormatDate(widget.maxDate) !=
            pickerFormatDate(oldWidget.maxDate) ||
        pickerFormatDate(widget.initialDisplayDate) !=
            pickerFormatDate(oldWidget.initialDisplayDate)) {
      _month = _initialMonth();
      _view = _CalendarView.days;
    }
  }

  @override
  void dispose() {
    for (final node in _dayFocus) {
      node.dispose();
    }
    super.dispose();
  }

  bool _available(DateTime date) =>
      widget.onChanged != null &&
      (widget.minDate == null ||
          !date.isBefore(pickerDateOnly(widget.minDate!))) &&
      (widget.maxDate == null ||
          !date.isAfter(pickerDateOnly(widget.maxDate!)));

  KeyEventResult _key(DateTime date, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => rtl ? 1 : -1,
      LogicalKeyboardKey.arrowRight => rtl ? -1 : 1,
      LogicalKeyboardKey.arrowUp => -7,
      LogicalKeyboardKey.arrowDown => 7,
      LogicalKeyboardKey.home => 1 - date.weekday,
      LogicalKeyboardKey.end => 7 - date.weekday,
      _ => null,
    };
    if (step == null) return KeyEventResult.ignored;
    var target = DateTime(date.year, date.month, date.day + step);
    if (target.year < 1 || target.year > 9999) return KeyEventResult.handled;
    target = _bounded(target);
    setState(() => _month = DateTime(target.year, target.month));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _dayFocus[target.day - 1];
      node.requestFocus();
      if (node.context != null) {
        Scrollable.ensureVisible(node.context!, duration: Duration.zero);
      }
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => WelkTheme.scope(
    context,
    overRideDarkMode: widget.overRideDarkMode,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final theme = WelkTheme.of(context).resolveColors(context);
    final localizations = MaterialLocalizations.of(context);
    final previous = DateTime(_month.year, _month.month - 1);
    final next = DateTime(_month.year, _month.month + 1);
    final previousEnd = DateTime(_month.year, _month.month, 0);
    final previousEnabled =
        _view == _CalendarView.days &&
        widget.onChanged != null &&
        previous.year >= 1 &&
        (widget.minDate == null ||
            !previousEnd.isBefore(pickerDateOnly(widget.minDate!)));
    final nextEnabled =
        _view == _CalendarView.days &&
        widget.onChanged != null &&
        next.year <= 9999 &&
        (widget.maxDate == null ||
            !next.isAfter(pickerDateOnly(widget.maxDate!)));
    final offset = _month.weekday - 1;
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((offset + count) / 7).ceil();
    final today = pickerFormatDate(DateTime.now());
    final selected = pickerFormatDate(widget.value);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerSurface(
          color: theme.accent,
          radii: pickerCircularRadii(8, 14, 9, 12),
          shadow: false,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              PickerButton(
                label: 'Previous month',
                radii: _calendarRadii(48, 48),
                onPressed: previousEnabled
                    ? () => setState(() => _month = previous)
                    : null,
                child: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_right
                      : Icons.chevron_left,
                  color: theme.isDark ? null : theme.ink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: PickerButton(
                    label: _view == _CalendarView.days
                        ? 'Choose month and year'
                        : 'Show calendar',
                    outlined: false,
                    minimumSize: const Size(0, 48),
                    onPressed: widget.onChanged == null
                        ? null
                        : () => setState(() {
                            _view = _view == _CalendarView.days
                                ? _CalendarView.years
                                : _CalendarView.days;
                          }),
                    child: Text(
                      localizations.formatMonthYear(_month),
                      textAlign: TextAlign.center,
                      style: pickerTextStyle(context).copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.onFill(theme.accent),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PickerButton(
                label: 'Next month',
                radii: _calendarRadii(48, 48),
                onPressed: nextEnabled
                    ? () => setState(() => _month = next)
                    : null,
                child: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left
                      : Icons.chevron_right,
                  color: theme.isDark ? null : theme.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_view == _CalendarView.years)
          _PickerCalendarYears(
            firstYear: widget.minDate?.year ?? 1,
            lastYear: widget.maxDate?.year ?? 9999,
            year: _month.year,
            onChanged: widget.onChanged == null
                ? null
                : (year) => setState(() {
                    final date = _bounded(DateTime(year, _month.month));
                    _month = DateTime(date.year, date.month);
                    _view = _CalendarView.months;
                  }),
          )
        else if (_view == _CalendarView.months)
          Column(
            children: [
              for (var row = 0; row < 6; row++)
                Row(
                  children: [
                    for (var col = 0; col < 2; col++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _monthButton(row * 2 + col + 1, localizations),
                        ),
                      ),
                  ],
                ),
            ],
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final dayHeight =
                  MediaQuery.textScalerOf(context).scale(13.6) * 1.5 + 28;
              return Column(
                children: [
                  Row(
                    children: [
                      for (final day in const [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Semantics(
                              label: day,
                              child: ExcludeSemantics(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    day,
                                    textAlign: TextAlign.center,
                                    style: pickerTextStyle(context, size: 11.2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (var row = 0; row < rows; row++)
                    Row(
                      children: [
                        for (var col = 0; col < 7; col++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(1.6),
                              child: _day(
                                row * 7 + col - offset + 1,
                                count,
                                today,
                                selected,
                                localizations,
                                width / 7 - 3.2,
                                dayHeight,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _monthButton(int month, MaterialLocalizations localizations) {
    final date = DateTime(_month.year, month);
    final lastDay = DateTime(_month.year, month + 1, 0);
    final enabled =
        widget.onChanged != null &&
        (widget.minDate == null ||
            !lastDay.isBefore(pickerDateOnly(widget.minDate!))) &&
        (widget.maxDate == null ||
            !date.isAfter(pickerDateOnly(widget.maxDate!)));
    final label = localizations.formatMonthYear(date);
    return PickerButton(
      key: ValueKey('month-${date.year}-$month'),
      label: label,
      selected: month == _month.month,
      onPressed: enabled
          ? () => setState(() {
              _month = date;
              _view = _CalendarView.days;
            })
          : null,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: pickerTextStyle(context)),
      ),
    );
  }

  Widget _day(
    int day,
    int count,
    String today,
    String selected,
    MaterialLocalizations localizations,
    double width,
    double height,
  ) {
    if (day < 1 || day > count) return SizedBox(height: height + 4);
    final date = DateTime(_month.year, _month.month, day);
    final iso = pickerFormatDate(date);
    return PickerButton(
      key: ValueKey('date-$iso'),
      label: localizations.formatFullDate(date),
      selected: iso == selected,
      current: iso == today,
      outlined: false,
      // Seven columns must fit even when 48px-wide targets cannot.
      minimumSize: Size(0, height),
      radii: _calendarRadii(width, height),
      rotation: iso == selected ? -0.0523599 : 0,
      focusNode: _dayFocus[day - 1],
      onKeyEvent: (_, event) => _key(date, event),
      onPressed: _available(date) ? () => widget.onChanged!(date) : null,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$day',
          style: const TextStyle(fontSize: 13.6, height: 1.5).copyWith(
            fontWeight: iso == selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _PickerCalendarYears extends StatefulWidget {
  const _PickerCalendarYears({
    required this.firstYear,
    required this.lastYear,
    required this.year,
    required this.onChanged,
  });

  final int firstYear;
  final int lastYear;
  final int year;
  final ValueChanged<int>? onChanged;

  @override
  State<_PickerCalendarYears> createState() => _PickerCalendarYearsState();
}

class _PickerCalendarYearsState extends State<_PickerCalendarYears> {
  ScrollController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight = MediaQuery.textScalerOf(context).scale(13.6) * 1.5 + 36;
    final rows = ((widget.lastYear - widget.firstYear + 1) / 3).ceil();
    const visibleRows = 5;
    final initialRow = ((widget.year - widget.firstYear) ~/ 3 - 2).clamp(
      0,
      rows > visibleRows ? rows - visibleRows : 0,
    );
    _controller ??= ScrollController(
      initialScrollOffset: initialRow * rowHeight,
    );
    final localizations = MaterialLocalizations.of(context);
    return SizedBox(
      height: rowHeight * visibleRows,
      child: ListView.builder(
        key: const ValueKey('calendar-years'),
        controller: _controller,
        primary: false,
        padding: EdgeInsets.zero,
        itemExtent: rowHeight,
        itemCount: rows,
        itemBuilder: (context, row) => Row(
          children: [
            for (var col = 0; col < 3; col++)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final year = widget.firstYear + row * 3 + col;
                    if (year > widget.lastYear) return const SizedBox.shrink();
                    final label = localizations.formatYear(DateTime(year));
                    return Padding(
                      padding: const EdgeInsets.all(4),
                      child: PickerButton(
                        key: ValueKey('year-$year'),
                        label: label,
                        selected: year == widget.year,
                        onPressed: widget.onChanged == null
                            ? null
                            : () => widget.onChanged!(year),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(label, style: pickerTextStyle(context)),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

WelkCornerRadii _calendarRadii(double width, double height) => WelkCornerRadii(
  topLeft: Radius.elliptical(width * .18, height * .12),
  topRight: Radius.elliptical(width * .10, height * .22),
  bottomRight: Radius.elliptical(width * .20, height * .14),
  bottomLeft: Radius.elliptical(width * .12, height * .18),
);
