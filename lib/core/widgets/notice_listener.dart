import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../state/notice.dart';
import 'app_snackbar.dart';

/// Shows a snackbar for every new [Notice] a controller publishes, then lets
/// the screen react (navigate, clear a selection, ...) through [onNotice].
///
/// Wrap a page's content in this instead of subscribing in the widget:
/// `NoticeListener(notice: controller.notice, onNotice: ..., child: ...)`.
class NoticeListener extends StatefulWidget {
  const NoticeListener({
    super.key,
    required this.notice,
    required this.child,
    this.onNotice,
    this.showSnackBar = true,
  });

  final Rxn<Notice> notice;
  final Widget child;
  final void Function(Notice notice)? onNotice;
  final bool showSnackBar;

  @override
  State<NoticeListener> createState() => _NoticeListenerState();
}

class _NoticeListenerState extends State<NoticeListener> {
  StreamSubscription<Notice?>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.notice.listen(_handle);
  }

  void _handle(Notice? n) {
    if (n == null || !mounted) return;
    if (widget.showSnackBar) {
      showAppSnackBar(context, n.message, isError: n.isError);
    }
    widget.onNotice?.call(n);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
