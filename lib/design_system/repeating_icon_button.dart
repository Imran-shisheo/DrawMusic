import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../l10n/strings.dart';

class RepeatingIconButton extends StatefulWidget {
  const RepeatingIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onStep,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onStep;
  @override
  State<RepeatingIconButton> createState() => _RepeatingIconButtonState();
}

class _RepeatingIconButtonState extends State<RepeatingIconButton>
    with WidgetsBindingObserver {
  Timer? _repeat;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  bool _step() {
    if (!mounted ||
        widget.onStep == null ||
        ModalRoute.of(context)?.isCurrent == false) {
      _stop();
      return false;
    }
    widget.onStep!();
    return true;
  }

  void _start(LongPressStartDetails _) {
    _stop();
    if (_step()) {
      _repeat = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _step(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void didUpdateWidget(RepeatingIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onStep == null) _stop();
  }

  @override
  void dispose() {
    _stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    hint: widget.onStep == null ? null : context.strings.pressAndHoldToRepeat,
    child: Tooltip(
      message: widget.tooltip,
      triggerMode: TooltipTriggerMode.manual,
      child: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: const Duration(milliseconds: 400),
                ),
                (recognizer) {
                  recognizer.onLongPressStart = widget.onStep == null
                      ? null
                      : _start;
                  recognizer.onLongPressEnd = (_) => _stop();
                  recognizer.onLongPressCancel = _stop;
                },
              ),
        },
        child: Listener(
          onPointerCancel: (_) => _stop(),
          child: IconButton(icon: Icon(widget.icon), onPressed: widget.onStep),
        ),
      ),
    ),
  );
}
