class DailyQuestion {
  final String date;
  final String expression;
  final String title;

  const DailyQuestion({
    required this.date,
    required this.expression,
    required this.title,
  });

  factory DailyQuestion.fromJson(Map<String, dynamic> json) => DailyQuestion(
        date: json['date'] as String? ?? '',
        expression: json['expression'] as String? ?? '',
        title: json['title'] as String? ?? 'Daily Rich Question',
      );
}
