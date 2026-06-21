import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:calcoricher/models/daily_question.dart';
import 'package:calcoricher/models/feed_item.dart';
import 'package:calcoricher/models/receipt_model.dart';
import 'package:calcoricher/models/room_model.dart';
import 'package:calcoricher/services/product_api.dart';

void main() {
  test('ProductApi maps auth, guardrails, and purchase responses', () async {
    final requests = <http.BaseRequest>[];
    final client = _FakeClient((request) async {
      requests.add(request);
      final body = request is http.Request && request.body.isNotEmpty
          ? jsonDecode(request.body)
          : null;

      if (request.method == 'GET' && request.url.path == '/api/guardrails') {
        return _json({
          'dailySpendLimitMinor': 10000,
          'currencyCode': 'chf',
          'currencySymbol': 'CHF',
          'satireDisclosure': 'This is satire.',
          'helpUrl': 'mailto:help@example.test',
          'refundUrl': 'mailto:refund@example.test',
          'priceLadder': [
            {'unlock': 1, 'amountMinor': 100, 'label': 'CHF 1.00'},
            {'unlock': 2, 'amountMinor': 200, 'label': 'CHF 2.00'},
          ],
        });
      }

      if (request.method == 'POST' &&
          request.url.path == '/api/auth/register') {
        expect(body, {
          'username': 'Ada',
          'email': 'ada@example.test',
          'password': 'pass1234',
        });
        return _json({
          'token': 'token_123',
          'user': {
            'id': 'user_1',
            'username': 'Ada',
            'email': 'ada@example.test',
            'totalSpentMinor': 0,
            'unlockedResultsCount': 0,
            'highestUnlockMinor': 0,
            'currentResultPriceMinor': 100,
            'badges': [],
            'titles': [],
            'receipts': [],
          },
        }, status: 201);
      }

      if (request.method == 'POST' && request.url.path == '/api/purchases') {
        expect(request.headers['authorization'], 'Bearer token_123');
        expect(body['expression'], '17 * 3');
        expect(body['context']['roomCode'], 'ABC123');
        return _json({
          'purchase': {
            'id': 'purchase_1',
            'expression': '17 * 3',
            'result': '51',
            'amountMinor': 400,
            'timestamp': '2026-06-21T12:00:00.000Z',
          },
          'receipt': {
            'id': 'receipt_1',
            'purchaseId': 'purchase_1',
            'expression': '17 * 3',
            'result': '51',
            'amountMinor': 400,
            'rank': 1,
            'shareText': 'I paid CHF 4.00 for this answer.',
            'imageUrl': '/api/receipts/receipt_1.svg',
            'timestamp': '2026-06-21T12:00:00.000Z',
          },
          'feedItem': {
            'id': 'feed_1',
            'purchaseId': 'purchase_1',
            'receiptId': 'receipt_1',
            'by': 'Ada',
            'userId': 'user_1',
            'expression': '17 * 3',
            'result': '51',
            'amountMinor': 400,
            'shareText': 'I paid CHF 4.00 for this answer.',
            'roomCode': 'ABC123',
            'challengeSlug': 'streamer-night',
            'charityCampaignId': 'math-relief',
            'timestamp': '2026-06-21T12:00:00.000Z',
          },
          'user': {
            'id': 'user_1',
            'username': 'Ada',
            'email': 'ada@example.test',
            'totalSpentMinor': 400,
            'unlockedResultsCount': 1,
            'highestUnlockMinor': 400,
            'currentResultPriceMinor': 200,
            'badges': [
              {'id': 'first-reveal', 'title': 'First Reveal'},
            ],
            'titles': ['Receipt Collector'],
            'receipts': [],
          },
        }, status: 201);
      }

      throw StateError('Unexpected request ${request.method} ${request.url}');
    });

    final api = ProductApi(
      baseUri: Uri.parse('https://api.example.test'),
      client: client,
    );

    final guardrails = await api.guardrails();
    expect(guardrails.dailySpendLimitMinor, 10000);
    expect(guardrails.priceLadder.first.label, 'CHF 1.00');

    final session = await api.register(
      username: 'Ada',
      email: 'ada@example.test',
      password: 'pass1234',
    );
    expect(session.token, 'token_123');
    expect(session.user.username, 'Ada');

    final purchase = await api.createPurchase(
      token: session.token,
      expression: '17 * 3',
      result: '51',
      amountMinor: 400,
      context: const PurchaseContext(
        roomCode: 'ABC123',
        challengeSlug: 'streamer-night',
        dailyQuestionDate: '2026-06-21',
        charityCampaignId: 'math-relief',
      ),
    );
    expect(purchase.receipt.shareText, 'I paid CHF 4.00 for this answer.');
    expect(purchase.receipt.rank, 1);
    expect(purchase.feedItem.by, 'Ada');
    expect(purchase.user.totalSpentMinor, 400);
    expect(requests.length, 3);
  });

  test('models parse daily questions, rooms, receipts, and feed items', () {
    final daily = DailyQuestion.fromJson({
      'date': '2026-06-21',
      'expression': '17 * 3',
      'title': 'Daily Rich Question',
    });
    expect(daily.expression, '17 * 3');

    final room = RoomModel.fromJson({
      'id': 'room_1',
      'code': 'ABC123',
      'title': 'Sunday Rich Room',
      'ownerId': 'user_1',
      'members': ['user_1', 'user_2'],
      'createdAt': '2026-06-21T12:00:00.000Z',
    });
    expect(room.members, contains('user_2'));

    final receipt = ReceiptModel.fromJson({
      'id': 'receipt_1',
      'purchaseId': 'purchase_1',
      'expression': '2 + 2',
      'result': '4',
      'amountMinor': 100,
      'rank': 7,
      'shareText': 'I paid CHF 1.00 for this answer.',
      'imageUrl': '/api/receipts/receipt_1.svg',
      'timestamp': '2026-06-21T12:00:00.000Z',
    });
    expect(receipt.imageUrl, '/api/receipts/receipt_1.svg');
    expect(receipt.rank, 7);

    final feed = FeedItem.fromJson({
      'id': 'feed_1',
      'purchaseId': 'purchase_1',
      'receiptId': 'receipt_1',
      'by': 'Lord Spreadsheet',
      'userId': 'user_1',
      'expression': '2 + 2',
      'result': '4',
      'amountMinor': 100,
      'shareText': 'I paid CHF 1.00 for this answer.',
      'roomCode': null,
      'challengeSlug': null,
      'charityCampaignId': null,
      'timestamp': '2026-06-21T12:00:00.000Z',
    });
    expect(feed.by, 'Lord Spreadsheet');
  });

  test('ProductApi maps competition routes and duration-aware purchases',
      () async {
    final client = _FakeClient((request) async {
      final body = request is http.Request && request.body.isNotEmpty
          ? jsonDecode(request.body)
          : null;

      if (request.method == 'POST' && request.url.path == '/api/purchases') {
        expect(body['durationMs'], 1200);
        return _json({
          'purchase': {
            'id': 'purchase_1',
            'expression': '2 + 2',
            'result': '4',
            'amountMinor': 500,
            'durationMs': 1200,
            'ridiculousScore': 17,
            'timestamp': '2026-06-21T12:00:00.000Z',
          },
          'receipt': {
            'id': 'receipt_1',
            'purchaseId': 'purchase_1',
            'expression': '2 + 2',
            'result': '4',
            'amountMinor': 500,
            'rank': 2,
            'shareText': 'I paid CHF 5.00 for this answer.',
            'imageUrl': '/api/receipts/receipt_1.svg',
            'timestamp': '2026-06-21T12:00:00.000Z',
          },
          'feedItem': {
            'id': 'feed_1',
            'purchaseId': 'purchase_1',
            'receiptId': 'receipt_1',
            'by': 'Bob',
            'userId': 'user_2',
            'expression': '2 + 2',
            'result': '4',
            'amountMinor': 500,
            'shareText': 'I paid CHF 5.00 for this answer.',
            'roomCode': 'ABC123',
            'challengeSlug': 'streamer-night',
            'charityCampaignId': null,
            'timestamp': '2026-06-21T12:00:00.000Z',
          },
          'user': {
            'id': 'user_2',
            'username': 'Bob',
            'email': 'bob@example.test',
            'totalSpentMinor': 500,
            'unlockedResultsCount': 1,
            'highestUnlockMinor': 500,
            'currentResultPriceMinor': 200,
            'badges': [],
            'titles': [],
            'receipts': [],
          },
        }, status: 201);
      }

      if (request.method == 'GET' &&
          request.url.path == '/api/rooms/ABC123/competition') {
        return _json({'leaders': _competitionJson()});
      }

      if (request.method == 'GET' &&
          request.url.path == '/api/challenges/streamer-night/competition') {
        return _json({'leaders': _competitionJson()});
      }

      if (request.method == 'GET' &&
          request.url.path == '/api/weekly/2026-W25/leaderboard') {
        return _json({
          'weekKey': '2026-W25',
          'users': [_leaderJson('user_1', 'Ada', 900)],
          'leaders': _competitionJson(),
        });
      }

      throw StateError('Unexpected request ${request.method} ${request.url}');
    });

    final api = ProductApi(
      baseUri: Uri.parse('https://api.example.test'),
      client: client,
    );

    final purchase = await api.createPurchase(
      token: 'token_123',
      expression: '2 + 2',
      result: '4',
      amountMinor: 500,
      durationMs: 1200,
      context: const PurchaseContext(roomCode: 'ABC123'),
    );
    expect(purchase.purchase.durationMs, 1200);
    expect(purchase.purchase.ridiculousScore, 17);

    final room = await api.roomCompetition('ABC123');
    expect(room.spent.first.username, 'Bob');
    expect(room.fastest.first.fastestRevealMs, 1200);

    final challenge = await api.challengeCompetition('streamer-night');
    expect(challenge.highestUnlock.first.username, 'Ada');

    final weekly = await api.weeklyLeaderboard('2026-W25');
    expect(weekly.single.username, 'Ada');
  });
}

class _FakeClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;

  _FakeClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

http.Response _json(Map<String, Object?> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, Object?> _competitionJson() => {
      'spent': [_leaderJson('user_2', 'Bob', 1000)],
      'highestUnlock': [_leaderJson('user_1', 'Ada', 900)],
      'ridiculous': [
        {
          ..._leaderJson('user_1', 'Ada', 900),
          'ridiculousScore': 120,
        }
      ],
      'fastest': [
        {
          ..._leaderJson('user_2', 'Bob', 1000),
          'fastestRevealMs': 1200,
        }
      ],
    };

Map<String, Object?> _leaderJson(String id, String username, int spent) => {
      'id': id,
      'username': username,
      'totalSpentMinor': spent,
      'unlockedResultsCount': 1,
      'highestUnlockMinor': spent,
      'ridiculousScore': 17,
      'fastestRevealMs': null,
    };
