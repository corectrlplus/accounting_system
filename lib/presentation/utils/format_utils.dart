import 'package:intl/intl.dart';

String formatAmount(int amountMinor) {
  final value = amountMinor.abs();
  final formatted = NumberFormat('#,###', 'en').format(value);
  return amountMinor < 0 ? '-$formatted' : formatted;
}

String formatDate(int dateMs) {
  final date = DateTime.fromMillisecondsSinceEpoch(dateMs);
  return DateFormat('dd/MM/yyyy', 'en').format(date);
}

String formatCurrency(int amountMinor) {
  return '${formatAmount(amountMinor)} د.ع';
}
