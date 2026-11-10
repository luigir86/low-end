import 'dart:async';

import 'package:flutter/material.dart';

/// A short notice at the top of the screen, under the status bar, with at
/// most one button: what a snackbar says, where it covers no controls. The
/// sections keep their buttons at the bottom, by the thumb; a notice there
/// hid them for seconds just when they were wanted.
///
/// One at a time: a new one takes the place of the one shown. It goes by
/// itself after [NoticeHost.duration], with its button too, or with a swipe
/// up.
class NoticeHost extends StatefulWidget {
  const NoticeHost({super.key, required this.child});

  final Widget child;

  /// How long a notice stays, as a snackbar's default.
  static const duration = Duration(seconds: 4);

  /// The host above [context]: every screen of the app has one.
  static NoticeHostState of(BuildContext context) =>
      context.findAncestorStateOfType<NoticeHostState>()!;

  @override
  State<NoticeHost> createState() => NoticeHostState();
}

/// One notice on screen, to know how it closed.
class Notice {
  Notice._(this.message, this.actionLabel, this.onAction);

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final _closed = Completer<bool>();

  /// Completes when the notice goes: true if its button was touched.
  Future<bool> get closed => _closed.future;

  void _close({required bool byAction}) {
    if (!_closed.isCompleted) _closed.complete(byAction);
  }
}

class NoticeHostState extends State<NoticeHost> {
  Notice? _shown;
  Timer? _timer;

  /// Shows [message], with a button [actionLabel] that runs [onAction].
  Notice show(String message, {String? actionLabel, VoidCallback? onAction}) {
    final notice = Notice._(message, actionLabel, onAction);
    _shown?._close(byAction: false);
    _timer?.cancel();
    _timer = Timer(NoticeHost.duration, () => hide(notice));
    setState(() => _shown = notice);
    return notice;
  }

  /// Takes [notice] (or whatever is shown) off the screen.
  void hide([Notice? notice]) {
    final shown = _shown;
    if (shown == null || (notice != null && notice != shown)) return;
    _timer?.cancel();
    shown._close(byAction: false);
    if (mounted) setState(() => _shown = null);
  }

  void _act(Notice notice) {
    _timer?.cancel();
    notice._close(byAction: true);
    setState(() => _shown = null);
    notice.onAction?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shown?._close(byAction: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = _shown;
    final still = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        widget.child,
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: still ? Duration.zero : Durations.medium1,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: notice == null
                  ? const SizedBox.shrink()
                  : _NoticeCard(
                      key: ObjectKey(notice),
                      notice: notice,
                      onAction: () => _act(notice),
                      onDismissed: () => hide(notice),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    super.key,
    required this.notice,
    required this.onAction,
    required this.onDismissed,
  });

  final Notice notice;
  final VoidCallback onAction, onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snack = theme.snackBarTheme;
    final ink = snack.contentTextStyle?.color ?? scheme.onInverseSurface;
    final label = notice.actionLabel;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Dismissible(
          key: ObjectKey(notice),
          direction: DismissDirection.up,
          onDismissed: (_) => onDismissed(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Material(
                key: const Key('notice'),
                color: snack.backgroundColor ?? scheme.inverseSurface,
                elevation: snack.elevation ?? 6,
                shape:
                    snack.shape ??
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: 16,
                    end: label == null ? 16 : 8,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              notice.message,
                              style:
                                  snack.contentTextStyle ??
                                  theme.textTheme.bodyMedium?.copyWith(
                                    color: ink,
                                  ),
                            ),
                          ),
                        ),
                        if (label != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  snack.actionTextColor ??
                                  scheme.inversePrimary,
                            ),
                            onPressed: onAction,
                            child: Text(label),
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
  }
}
