/// Ein freigeschalteter (bezahlter) Rechnungs-Eintrag im Verlauf.
class HistoryEntry {
  final String expression;
  final String result;
  final int amountMinor;
  final String? roomCode;
  final String? challengeSlug;
  final String? dailyQuestionDate;
  final String? charityCampaignId;
  final int? durationMs;
  final int ridiculousScore;
  final int? rank;
  final int timestamp; // Epoch-Millisekunden

  HistoryEntry({
    required this.expression,
    required this.result,
    this.amountMinor = 0,
    this.roomCode,
    this.challengeSlug,
    this.dailyQuestionDate,
    this.charityCampaignId,
    this.durationMs,
    int? ridiculousScore,
    this.rank,
    required this.timestamp,
  }) : ridiculousScore = ridiculousScore ?? _ridiculousScore(expression);

  Map<String, dynamic> toJson() => {
        'expression': expression,
        'result': result,
        'amountMinor': amountMinor,
        'roomCode': roomCode,
        'challengeSlug': challengeSlug,
        'dailyQuestionDate': dailyQuestionDate,
        'charityCampaignId': charityCampaignId,
        'durationMs': durationMs,
        'ridiculousScore': ridiculousScore,
        'rank': rank,
        'timestamp': timestamp,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        expression: json['expression'] as String? ?? '',
        result: json['result'] as String? ?? '',
        amountMinor: json['amountMinor'] as int? ?? 0,
        roomCode: json['roomCode'] as String?,
        challengeSlug: json['challengeSlug'] as String?,
        dailyQuestionDate: json['dailyQuestionDate'] as String?,
        charityCampaignId: json['charityCampaignId'] as String?,
        durationMs: json['durationMs'] as int?,
        ridiculousScore: json['ridiculousScore'] as int?,
        rank: json['rank'] as int?,
        timestamp: json['timestamp'] as int? ?? 0,
      );
}

int _ridiculousScore(String expression) {
  final compact = expression.replaceAll(RegExp(r'\s+'), '');
  final digits = RegExp(r'\d').allMatches(compact).length;
  final operators = RegExp(r'[+\-*/^%]').allMatches(compact).length;
  final parens = RegExp(r'[()]').allMatches(compact).length;
  final longNumbers = RegExp(r'\d{4,}')
      .allMatches(compact)
      .fold<int>(0, (sum, match) => sum + match.group(0)!.length);
  final repeatedDigits = RegExp(r'(\d)\1{2,}')
      .allMatches(compact)
      .fold<int>(0, (sum, match) => sum + match.group(0)!.length);
  return compact.length +
      digits +
      operators * 6 +
      parens * 4 +
      longNumbers * 2 +
      repeatedDigits * 2;
}
