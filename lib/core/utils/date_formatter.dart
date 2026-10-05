import 'package:intl/intl.dart';

final DateFormat _dmy = DateFormat('dd MMM yyyy', 'en_US');

/// `03 Oct 2026`, or an em dash when there is no date.
String formatDate(DateTime? d) => d == null ? '—' : _dmy.format(d);

final DateFormat _dmyHm = DateFormat('dd MMM yyyy, HH:mm', 'en_US');

/// `03 Oct 2026, 14:05`.
String formatDateTime(DateTime d) => _dmyHm.format(d);
