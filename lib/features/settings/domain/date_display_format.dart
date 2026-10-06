// Cómo se muestran las fechas en la aplicación; los archivos guardan siempre AAAA-MM-DD.
enum DateDisplayFormat {
  dayMonthSlash('DD/MM/YYYY'),
  monthDaySlash('MM/DD/YYYY'),
  iso('YYYY-MM-DD'),
  monthDayDot('MM.DD.YYYY'),
  dayMonthDot('DD.MM.YYYY'),
  dayMonthDash('DD-MM-YYYY');

  const DateDisplayFormat(this.pattern);

  final String pattern;

  String format(DateTime date) => pattern
      .replaceFirst('YYYY', date.year.toString().padLeft(4, '0'))
      .replaceFirst('MM', date.month.toString().padLeft(2, '0'))
      .replaceFirst('DD', date.day.toString().padLeft(2, '0'));
}
