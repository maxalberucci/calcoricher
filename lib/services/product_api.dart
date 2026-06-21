import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/daily_question.dart';
import '../models/feed_item.dart';
import '../models/receipt_model.dart';
import '../models/room_model.dart';

class ProductApi {
  final Uri baseUri;
  final http.Client _client;

  ProductApi({
    required this.baseUri,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<Guardrails> guardrails() async {
    final json = await _send('GET', '/api/guardrails');
    return Guardrails.fromJson(json);
  }

  Future<DailyQuestion> dailyQuestion() async {
    final json = await _send('GET', '/api/daily-question');
    return DailyQuestion.fromJson(json);
  }

  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final json = await _send('POST', '/api/auth/register', body: {
      'username': username,
      'email': email,
      'password': password,
    });
    return AuthSession.fromJson(json);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _send('POST', '/api/auth/login', body: {
      'email': email,
      'password': password,
    });
    return AuthSession.fromJson(json);
  }

  Future<ProductUser> me({required String token}) async {
    final json = await _send('GET', '/api/me', token: token);
    return ProductUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<PurchaseResponse> createPurchase({
    required String token,
    required String expression,
    required String result,
    required int amountMinor,
    int? durationMs,
    PurchaseContext context = const PurchaseContext(),
  }) async {
    final body = <String, Object?>{
      'expression': expression,
      'result': result,
      'amountMinor': amountMinor,
      'context': context.toJson(),
    };
    if (durationMs != null) body['durationMs'] = durationMs;

    final json =
        await _send('POST', '/api/purchases', token: token, body: body);
    return PurchaseResponse.fromJson(json);
  }

  Future<List<LeaderboardUser>> leaderboard() async {
    final json = await _send('GET', '/api/leaderboard');
    return _list(json['users'], LeaderboardUser.fromJson);
  }

  Future<List<FeedItem>> feed() async {
    final json = await _send('GET', '/api/feed');
    return _list(json['items'], FeedItem.fromJson);
  }

  Future<RoomModel> createRoom({
    required String token,
    required String title,
  }) async {
    final json = await _send('POST', '/api/rooms', token: token, body: {
      'title': title,
    });
    return RoomModel.fromJson(json['room'] as Map<String, dynamic>);
  }

  Future<RoomModel> joinRoom({
    required String token,
    required String code,
  }) async {
    final json = await _send('POST', '/api/rooms/$code/join', token: token);
    return RoomModel.fromJson(json['room'] as Map<String, dynamic>);
  }

  Future<ApiCompetitionLeaders> roomCompetition(String code) async {
    final encoded = Uri.encodeComponent(code);
    final json = await _send('GET', '/api/rooms/$encoded/competition');
    return ApiCompetitionLeaders.fromJson(
      json['leaders'] as Map<String, dynamic>,
    );
  }

  Future<ApiCompetitionLeaders> challengeCompetition(String slug) async {
    final encoded = Uri.encodeComponent(slug);
    final json = await _send('GET', '/api/challenges/$encoded/competition');
    return ApiCompetitionLeaders.fromJson(
      json['leaders'] as Map<String, dynamic>,
    );
  }

  Future<List<LeaderboardUser>> weeklyLeaderboard(String weekKey) async {
    final encoded = Uri.encodeComponent(weekKey);
    final json = await _send('GET', '/api/weekly/$encoded/leaderboard');
    return _list(json['users'], LeaderboardUser.fromJson);
  }

  Future<void> deleteAccount({required String token}) async {
    await _send('DELETE', '/api/me', token: token);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) async {
    final headers = <String, String>{'accept': 'application/json'};
    if (body != null) headers['content-type'] = 'application/json';
    if (token != null) headers['authorization'] = 'Bearer $token';

    final request = http.Request(method, baseUri.resolve(path));
    request.headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw ProductApiException(
        statusCode: response.statusCode,
        code: decoded['code'] as String? ?? 'request_failed',
        message: decoded['message'] as String? ?? 'Request failed.',
      );
    }
    return decoded;
  }
}

class ProductApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ProductApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'ProductApiException($statusCode, $code, $message)';
}

class AuthSession {
  final String token;
  final ProductUser user;

  const AuthSession({required this.token, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String? ?? '',
        user: ProductUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class ProductUser {
  final String id;
  final String username;
  final String email;
  final int totalSpentMinor;
  final int unlockedResultsCount;
  final int highestUnlockMinor;
  final int currentResultPriceMinor;
  final List<ProductBadge> badges;
  final List<String> titles;
  final List<ReceiptModel> receipts;

  const ProductUser({
    required this.id,
    required this.username,
    required this.email,
    required this.totalSpentMinor,
    required this.unlockedResultsCount,
    required this.highestUnlockMinor,
    required this.currentResultPriceMinor,
    required this.badges,
    required this.titles,
    required this.receipts,
  });

  factory ProductUser.fromJson(Map<String, dynamic> json) => ProductUser(
        id: json['id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        totalSpentMinor: json['totalSpentMinor'] as int? ?? 0,
        unlockedResultsCount: json['unlockedResultsCount'] as int? ?? 0,
        highestUnlockMinor: json['highestUnlockMinor'] as int? ?? 0,
        currentResultPriceMinor: json['currentResultPriceMinor'] as int? ?? 0,
        badges: _list(json['badges'], ProductBadge.fromJson),
        titles:
            (json['titles'] as List?)?.whereType<String>().toList() ?? const [],
        receipts: _list(json['receipts'], ReceiptModel.fromJson),
      );
}

class ProductBadge {
  final String id;
  final String title;

  const ProductBadge({required this.id, required this.title});

  factory ProductBadge.fromJson(Map<String, dynamic> json) => ProductBadge(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );
}

class Guardrails {
  final int dailySpendLimitMinor;
  final String currencyCode;
  final String currencySymbol;
  final String satireDisclosure;
  final String helpUrl;
  final String refundUrl;
  final List<PriceStep> priceLadder;

  const Guardrails({
    required this.dailySpendLimitMinor,
    required this.currencyCode,
    required this.currencySymbol,
    required this.satireDisclosure,
    required this.helpUrl,
    required this.refundUrl,
    required this.priceLadder,
  });

  factory Guardrails.fromJson(Map<String, dynamic> json) => Guardrails(
        dailySpendLimitMinor: json['dailySpendLimitMinor'] as int? ?? 0,
        currencyCode: json['currencyCode'] as String? ?? '',
        currencySymbol: json['currencySymbol'] as String? ?? '',
        satireDisclosure: json['satireDisclosure'] as String? ?? '',
        helpUrl: json['helpUrl'] as String? ?? '',
        refundUrl: json['refundUrl'] as String? ?? '',
        priceLadder: _list(json['priceLadder'], PriceStep.fromJson),
      );
}

class PriceStep {
  final int unlock;
  final int amountMinor;
  final String label;

  const PriceStep({
    required this.unlock,
    required this.amountMinor,
    required this.label,
  });

  factory PriceStep.fromJson(Map<String, dynamic> json) => PriceStep(
        unlock: json['unlock'] as int? ?? 0,
        amountMinor: json['amountMinor'] as int? ?? 0,
        label: json['label'] as String? ?? '',
      );
}

class PurchaseContext {
  final String? roomCode;
  final String? challengeSlug;
  final String? dailyQuestionDate;
  final String? charityCampaignId;

  const PurchaseContext({
    this.roomCode,
    this.challengeSlug,
    this.dailyQuestionDate,
    this.charityCampaignId,
  });

  Map<String, Object?> toJson() => {
        'roomCode': roomCode,
        'challengeSlug': challengeSlug,
        'dailyQuestionDate': dailyQuestionDate,
        'charityCampaignId': charityCampaignId,
      };
}

class PurchaseResponse {
  final PurchaseRecord purchase;
  final ReceiptModel receipt;
  final FeedItem feedItem;
  final ProductUser user;

  const PurchaseResponse({
    required this.purchase,
    required this.receipt,
    required this.feedItem,
    required this.user,
  });

  factory PurchaseResponse.fromJson(Map<String, dynamic> json) =>
      PurchaseResponse(
        purchase:
            PurchaseRecord.fromJson(json['purchase'] as Map<String, dynamic>),
        receipt: ReceiptModel.fromJson(json['receipt'] as Map<String, dynamic>),
        feedItem: FeedItem.fromJson(json['feedItem'] as Map<String, dynamic>),
        user: ProductUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class PurchaseRecord {
  final String id;
  final String expression;
  final String result;
  final int amountMinor;
  final int? durationMs;
  final int ridiculousScore;
  final String timestamp;

  const PurchaseRecord({
    required this.id,
    required this.expression,
    required this.result,
    required this.amountMinor,
    required this.durationMs,
    required this.ridiculousScore,
    required this.timestamp,
  });

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) => PurchaseRecord(
        id: json['id'] as String? ?? '',
        expression: json['expression'] as String? ?? '',
        result: json['result'] as String? ?? '',
        amountMinor: json['amountMinor'] as int? ?? 0,
        durationMs: json['durationMs'] as int?,
        ridiculousScore: json['ridiculousScore'] as int? ?? 0,
        timestamp: json['timestamp'] as String? ?? '',
      );
}

class LeaderboardUser {
  final String id;
  final String username;
  final int totalSpentMinor;
  final int unlockedResultsCount;
  final int highestUnlockMinor;

  const LeaderboardUser({
    required this.id,
    required this.username,
    required this.totalSpentMinor,
    required this.unlockedResultsCount,
    required this.highestUnlockMinor,
  });

  factory LeaderboardUser.fromJson(Map<String, dynamic> json) =>
      LeaderboardUser(
        id: json['id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        totalSpentMinor: json['totalSpentMinor'] as int? ?? 0,
        unlockedResultsCount: json['unlockedResultsCount'] as int? ?? 0,
        highestUnlockMinor: json['highestUnlockMinor'] as int? ?? 0,
      );
}

class ApiCompetitionLeaders {
  final List<ApiCompetitionEntry> spent;
  final List<ApiCompetitionEntry> highestUnlock;
  final List<ApiCompetitionEntry> ridiculous;
  final List<ApiCompetitionEntry> fastest;

  const ApiCompetitionLeaders({
    required this.spent,
    required this.highestUnlock,
    required this.ridiculous,
    required this.fastest,
  });

  factory ApiCompetitionLeaders.fromJson(Map<String, dynamic> json) =>
      ApiCompetitionLeaders(
        spent: _list(json['spent'], ApiCompetitionEntry.fromJson),
        highestUnlock:
            _list(json['highestUnlock'], ApiCompetitionEntry.fromJson),
        ridiculous: _list(json['ridiculous'], ApiCompetitionEntry.fromJson),
        fastest: _list(json['fastest'], ApiCompetitionEntry.fromJson),
      );
}

class ApiCompetitionEntry {
  final String id;
  final String username;
  final int totalSpentMinor;
  final int unlockedResultsCount;
  final int highestUnlockMinor;
  final int ridiculousScore;
  final int? fastestRevealMs;

  const ApiCompetitionEntry({
    required this.id,
    required this.username,
    required this.totalSpentMinor,
    required this.unlockedResultsCount,
    required this.highestUnlockMinor,
    required this.ridiculousScore,
    required this.fastestRevealMs,
  });

  factory ApiCompetitionEntry.fromJson(Map<String, dynamic> json) =>
      ApiCompetitionEntry(
        id: json['id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        totalSpentMinor: json['totalSpentMinor'] as int? ?? 0,
        unlockedResultsCount: json['unlockedResultsCount'] as int? ?? 0,
        highestUnlockMinor: json['highestUnlockMinor'] as int? ?? 0,
        ridiculousScore: json['ridiculousScore'] as int? ?? 0,
        fastestRevealMs: json['fastestRevealMs'] as int?,
      );
}

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    (value as List?)
        ?.whereType<Map>()
        .map((item) => parse(item.cast<String, dynamic>()))
        .toList() ??
    const [];
