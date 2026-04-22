import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:overthrone/core/auth_service.dart';

/// Chat message model
class ChatMessage {
  final String id;
  final String uid;
  final String senderName;
  final String text;
  final String type; // text, voice, emoji
  final String? voiceUrl;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.uid,
    required this.senderName,
    required this.text,
    this.type = 'text',
    this.voiceUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'senderName': senderName,
    'text': text,
    'type': type,
    if (voiceUrl != null) 'voiceUrl': voiceUrl,
    'timestamp': ServerValue.timestamp,
  };

  factory ChatMessage.fromSnapshot(DataSnapshot snap) {
    final j = Map<String, dynamic>.from(snap.value as Map);
    return ChatMessage(
      id: snap.key ?? '',
      uid: j['uid'] as String? ?? '',
      senderName: j['senderName'] as String? ?? 'Unknown',
      text: j['text'] as String? ?? '',
      type: j['type'] as String? ?? 'text',
      voiceUrl: j['voiceUrl'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (j['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

enum ChatChannel { server, guild, private_ }

/// Chat service backed by Firebase Realtime Database
class ChatService {
  ChatService._();
  static final ChatService I = ChatService._();

  final _db = FirebaseDatabase.instance;

  // Rate limiting
  DateTime? _lastSent;
  static const _rateLimit = Duration(seconds: 2);

  // Local cache for offline/fast access
  final Map<String, List<ChatMessage>> _cache = {};

  DatabaseReference _ref(ChatChannel channel, {String? targetId}) {
    switch (channel) {
      case ChatChannel.server:
        return _db.ref('chat/server');
      case ChatChannel.guild:
        return _db.ref('chat/guild/${targetId ?? 'default'}');
      case ChatChannel.private_:
        return _db.ref('chat/private/${targetId ?? 'unknown'}');
    }
  }

  /// Listen to messages in real-time
  Stream<List<ChatMessage>> messagesStream(ChatChannel channel, {String? targetId}) {
    final ref = _ref(channel, targetId: targetId);
    return ref.orderByChild('timestamp').limitToLast(100).onValue.map((event) {
      final snap = event.snapshot;
      if (!snap.exists) return <ChatMessage>[];
      final messages = <ChatMessage>[];
      for (final child in snap.children) {
        try {
          messages.add(ChatMessage.fromSnapshot(child));
        } catch (_) {}
      }
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final key = '${channel.name}_${targetId ?? ''}';
      _cache[key] = messages;
      return messages;
    });
  }

  /// Get cached messages (sync)
  List<ChatMessage> getMessages(ChatChannel channel, {String? targetId}) {
    final key = '${channel.name}_${targetId ?? ''}';
    return _cache[key] ?? [];
  }

  /// Send a message
  Future<bool> sendMessage({
    required ChatChannel channel,
    required String text,
    required String senderName,
    String? targetId,
    String type = 'text',
    String? voiceUrl,
  }) async {
    // Rate limit
    if (_lastSent != null &&
        DateTime.now().difference(_lastSent!) < _rateLimit) {
      return false;
    }

    final ref = _ref(channel, targetId: targetId);
    final msg = ChatMessage(
      id: '',
      uid: AuthService.I.uid.isNotEmpty ? AuthService.I.uid : 'local_user',
      senderName: senderName,
      text: text,
      type: type,
      voiceUrl: voiceUrl,
      timestamp: DateTime.now(),
    );

    try {
      await ref.push().set(msg.toJson());
      _lastSent = DateTime.now();
      return true;
    } catch (e) {
      // Fallback to local cache if Firebase fails
      final key = '${channel.name}_${targetId ?? ''}';
      _cache.putIfAbsent(key, () => []);
      _cache[key]!.add(ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        uid: 'local_user',
        senderName: senderName,
        text: text,
        type: type,
        voiceUrl: voiceUrl,
        timestamp: DateTime.now(),
      ));
      _lastSent = DateTime.now();
      return true;
    }
  }

  /// Seed demo messages (only if server channel is empty)
  Future<void> seedDemoMessages() async {
    final ref = _ref(ChatChannel.server);
    final snap = await ref.limitToLast(1).get();
    if (snap.exists) return; // already has messages

    await ref.push().set({
      'uid': 'system',
      'senderName': 'System',
      'text': 'Welcome to Overthrone! Server chat is now live.',
      'type': 'text',
      'timestamp': ServerValue.timestamp,
    });
  }
}
