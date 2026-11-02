import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../painting/welk_shape_border.dart';
import '../theme/welk_theme.dart';
import 'welk_button.dart';
import 'welk_icon_button.dart';

enum WelkDialogVariant { alert, info, warning, error, success }

enum WelkDialogType { standard, confirmation }

/// Presents a focus-trapped modal and restores focus when it is dismissed.
Future<T?> showWelkDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool closeOnTapOutside = false,
  bool useRootNavigator = true,
  bool? overRideDarkMode,
}) {
  return showDialog<T>(
    context: context,
    // showDialog captures local inherited themes to its target Navigator.
    builder: (context) => WelkTheme.scope(
      context,
      overRideDarkMode: overRideDarkMode,
      child: Builder(builder: builder),
    ),
    barrierDismissible: closeOnTapOutside,
    barrierColor: const Color(0x73000000),
    useRootNavigator: useRootNavigator,
    animationStyle: welkAnimationsDisabled(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(duration: Duration(milliseconds: 180)),
  );
}

/// The paper dialog surface; present with [showWelkDialog].
///
/// Action callbacks replace automatic dismissal, matching the React contract.
class WelkDialog extends StatelessWidget {
  const WelkDialog({
    super.key,
    required this.title,
    this.child,
    this.variant = WelkDialogVariant.alert,
    this.type = WelkDialogType.standard,
    this.onClose,
    this.closeLabel = 'Close dialog',
    this.buttonText = 'Okay',
    this.onPressed,
    this.yesText = 'Yes',
    this.noText = 'No',
    this.onYesPressed,
    this.onNoPressed,
    this.overRideDarkMode,
  });

  final Widget title;
  final Widget? child;
  final WelkDialogVariant variant;
  final WelkDialogType type;
  final VoidCallback? onClose;
  final String closeLabel;
  final String buttonText;
  final VoidCallback? onPressed;
  final String yesText;
  final String noText;
  final VoidCallback? onYesPressed;
  final VoidCallback? onNoPressed;
  final bool? overRideDarkMode;

  @override
  Widget build(BuildContext context) => WelkTheme.scope(
    context,
    overRideDarkMode: overRideDarkMode,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final theme = WelkTheme.of(context).resolveColors(context);
    void close() => (onClose ?? () => Navigator.of(context).pop())();
    final color = switch (variant) {
      WelkDialogVariant.alert => theme.accent,
      WelkDialogVariant.info => theme.info,
      WelkDialogVariant.warning => theme.warning,
      WelkDialogVariant.error => theme.error,
      WelkDialogVariant.success => theme.success,
    };
    final buttonVariant = switch (variant) {
      WelkDialogVariant.alert => WelkButtonVariant.primary,
      WelkDialogVariant.info => WelkButtonVariant.info,
      WelkDialogVariant.warning => WelkButtonVariant.warning,
      WelkDialogVariant.error => WelkButtonVariant.error,
      WelkDialogVariant.success => WelkButtonVariant.success,
    };
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              close();
              return null;
            },
          ),
        },
        child: AnimatedPadding(
          duration: welkAnimationsDisabled(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          padding: MediaQuery.viewInsetsOf(context) + const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // CSS percentage radii depend on both axes of the dialog.
                  return _DialogSurface(
                    theme: theme,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: color,
                              border: Border(
                                bottom: BorderSide(
                                  color: theme.outline,
                                  width: theme.borderWidth,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Semantics(
                                    namesRoute: true,
                                    header: true,
                                    child: DefaultTextStyle.merge(
                                      style: TextStyle(
                                        color: theme.onFill(color),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      child: title,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                _DialogClose(
                                  label: closeLabel,
                                  onPressed: close,
                                ),
                              ],
                            ),
                          ),
                          if (child != null)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: child,
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 16,
                              runSpacing: 16,
                              children: type == WelkDialogType.confirmation
                                  ? [
                                      WelkButton(
                                        variant: WelkButtonVariant.success,
                                        onPressed: onYesPressed ?? close,
                                        child: Text(yesText),
                                      ),
                                      WelkButton(
                                        variant: WelkButtonVariant.error,
                                        onPressed: onNoPressed ?? close,
                                        child: Text(noText),
                                      ),
                                    ]
                                  : [
                                      WelkButton(
                                        variant: buttonVariant,
                                        onPressed: onPressed ?? close,
                                        child: Text(buttonText),
                                      ),
                                    ],
                            ),
                          ),
                        ],
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
  }
}

class _DialogClose extends StatelessWidget {
  const _DialogClose({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => WelkIconButton.close(
    dialog: true,
    autofocus: true,
    label: label,
    onPressed: onPressed,
  );
}

class _DialogSurface extends StatelessWidget {
  const _DialogSurface({required this.theme, required this.child});

  final WelkColors theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = _DialogShape(
      strokeColor: theme.outline,
      strokeWidth: theme.borderWidth,
    );
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: theme.fontFamily,
          package: theme.fontPackage,
          fontSize: 16,
          height: 1.5,
          color: theme.ink,
          decoration: TextDecoration.none,
        ),
        child: CustomPaint(
          painter: WelkHardShadowPainter(
            shape: shape,
            color: theme.shadow,
            offset: const Offset(6, 6),
          ),
          child: Container(
            decoration: ShapeDecoration(color: theme.paper, shape: shape),
            padding: EdgeInsets.all(theme.borderWidth),
            child: ClipPath(
              clipper: ShapeBorderClipper(shape: shape),
              child: Material(
                type: MaterialType.transparency,
                textStyle: DefaultTextStyle.of(context).style.copyWith(
                  fontFamily: theme.fontFamily,
                  package: theme.fontPackage,
                  fontSize: 16,
                  height: 1.5,
                  color: theme.ink,
                  decoration: TextDecoration.none,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogShape extends WelkShapeBorder {
  const _DialogShape({required super.strokeColor, required super.strokeWidth})
    : super(radii: welkCardRadii);

  WelkShapeBorder _forRect(Rect rect) => WelkShapeBorder(
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
    radii: WelkCornerRadii(
      topLeft: Radius.elliptical(rect.width * .03, rect.height * .02),
      topRight: Radius.elliptical(rect.width * .02, rect.height * .05),
      bottomRight: Radius.elliptical(rect.width * .04, rect.height * .03),
      bottomLeft: Radius.elliptical(rect.width * .02, rect.height * .06),
    ),
  );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _forRect(rect).getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) =>
      _forRect(rect).paint(canvas, rect, textDirection: textDirection);
}
