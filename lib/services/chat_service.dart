import 'dart:async';

class ChatService {
  static final Map<String, Map<String, dynamic>> _threads =
      <String, Map<String, dynamic>>{};
  static final Map<String, List<Map<String, dynamic>>> _messages =
      <String, List<Map<String, dynamic>>>{};
  static final StreamController<int> _updates =
      StreamController<int>.broadcast();

  String threadIdFor({
    required String listingId,
    required String buyerId,
    required String sellerId,
  }) {
    final sorted = [buyerId, sellerId]..sort();
    return '${listingId}_${sorted[0]}_${sorted[1]}';
  }

  Stream<List<Map<String, dynamic>>> watchThreadsForUser(String userId) {
    return _updates.stream.map((_) => _threadsForUser(userId)).startWith(
          _threadsForUser(userId),
        );
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String threadId) {
    return _updates.stream
        .map((_) => _messagesForThread(threadId))
        .startWith(_messagesForThread(threadId));
  }

  Future<void> sendMessage({
    required String listingId,
    required String listingTitle,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required String sellerName,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final now = DateTime.now();
    final threadId = threadIdFor(
      listingId: listingId,
      buyerId: buyerId,
      sellerId: sellerId,
    );
    _threads[threadId] = {
      'id': threadId,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'participants': [buyerId, sellerId],
      'lastMessage': body,
      'lastMessageAt': now,
    };

    final list = _messages.putIfAbsent(threadId, () => <Map<String, dynamic>>[]);
    list.add({
      'id': '${now.microsecondsSinceEpoch}_${list.length}',
      'senderId': senderId,
      'senderName': senderName,
      'text': body,
      'sentAt': now,
    });
    _updates.add(now.microsecondsSinceEpoch);
  }

  List<Map<String, dynamic>> _threadsForUser(String userId) {
    final items = _threads.values
        .where((t) => (t['participants'] as List<dynamic>).contains(userId))
        .map((t) => Map<String, dynamic>.from(t))
        .toList()
      ..sort(
        (a, b) => (b['lastMessageAt'] as DateTime)
            .compareTo(a['lastMessageAt'] as DateTime),
      );
    return items;
  }

  List<Map<String, dynamic>> _messagesForThread(String threadId) {
    final list = _messages[threadId] ?? const <Map<String, dynamic>>[];
    final copy = list.map((m) => Map<String, dynamic>.from(m)).toList()
      ..sort(
        (a, b) => (a['sentAt'] as DateTime).compareTo(b['sentAt'] as DateTime),
      );
    return copy;
  }
}

extension<T> on Stream<T> {
  Stream<T> startWith(T initialValue) async* {
    yield initialValue;
    yield* this;
  }
}
