import 'package:intl/intl.dart';

DateTime hospitalDateTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 7));

String hospitalTime(DateTime value, {String pattern = 'dd/MM/yyyy HH:mm'}) =>
    DateFormat(pattern).format(hospitalDateTime(value));

bool isSameHospitalDay(DateTime a, DateTime b) {
  final left = hospitalDateTime(a);
  final right = hospitalDateTime(b);
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
