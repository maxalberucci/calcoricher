/// Ein freigeschalteter (bezahlter) Rechnungs-Eintrag im Verlauf.
class HistoryEntry {
  final String expression;
  final String result;
  final int timestamp; // Epoch-Millisekunden

  HistoryEntry({
    required this.expression,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'expression': expression,
        'result': result,
        'timestamp': timestamp,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        expression: json['expression'] as String? ?? '',
        result: json['result'] as String? ?? '',
        timestamp: json['timestamp'] as int? ?? 0,
      );
}
