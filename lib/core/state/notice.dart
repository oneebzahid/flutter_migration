import 'package:equatable/equatable.dart';
import 'package:get/get.dart';

/// One-shot feedback message. A controller publishes it through
/// [NoticeMixin.notify]; the screen shows a snackbar whenever [id] changes
/// (see `NoticeListener`), so the same text can be shown twice in a row.
class Notice extends Equatable {
  const Notice({
    required this.id,
    required this.message,
    this.isError = false,
    this.tag,
  });

  final int id;
  final String message;
  final bool isError;

  /// Lets a screen react to a specific operation (e.g. 'create').
  final String? tag;

  @override
  List<Object?> get props => [id, message, isError, tag];
}

/// Gives a controller a `notice` Rx and a `notify()` to publish feedback.
mixin NoticeMixin on GetxController {
  final Rxn<Notice> notice = Rxn<Notice>();
  int _noticeSeq = 0;

  void notify(String message, {bool isError = false, String? tag}) {
    notice.value = Notice(
      id: ++_noticeSeq,
      message: message,
      isError: isError,
      tag: tag,
    );
  }
}
