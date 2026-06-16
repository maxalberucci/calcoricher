import 'dart:math';

class UserModel {
  String name;
  int coins;
  int spentCoins;
  int resultsShown;

  UserModel({
    required this.name,
    this.coins = 100,
    this.spentCoins = 0,
    this.resultsShown = 0,
  });

  /// Price for the next result: 1, 2, 4, 8, 16, ... (doubles each time)
  int get nextPrice => pow(2, resultsShown).toInt();

  bool get canAffordNextResult => coins >= nextPrice;

  Map<String, dynamic> toJson() => {
        'name': name,
        'coins': coins,
        'spentCoins': spentCoins,
        'resultsShown': resultsShown,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        name: json['name'] as String,
        coins: json['coins'] as int? ?? 100,
        spentCoins: json['spentCoins'] as int? ?? 0,
        resultsShown: json['resultsShown'] as int? ?? 0,
      );

  UserModel copyWith({
    String? name,
    int? coins,
    int? spentCoins,
    int? resultsShown,
  }) =>
      UserModel(
        name: name ?? this.name,
        coins: coins ?? this.coins,
        spentCoins: spentCoins ?? this.spentCoins,
        resultsShown: resultsShown ?? this.resultsShown,
      );
}
