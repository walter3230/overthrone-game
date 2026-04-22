import 'package:flutter/material.dart';
import 'package:overthrone/core/auth_service.dart';
import 'chat_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.initialChannel = ChatChannel.server});
  final ChatChannel initialChannel;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialChannel.index,
    );
    ChatService.I.seedDemoMessages();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage(ChatChannel channel) {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    ChatService.I.sendMessage(
      channel: channel,
      text: text,
      senderName: 'Player_123',
    );
    _textCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Server'),
            Tab(text: 'Guild'),
            Tab(text: 'Private'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ChatView(channel: ChatChannel.server, onSend: () => _sendMessage(ChatChannel.server), textCtrl: _textCtrl),
          _ChatView(channel: ChatChannel.guild, onSend: () => _sendMessage(ChatChannel.guild), textCtrl: _textCtrl),
          _PrivateChatList(),
        ],
      ),
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView({required this.channel, required this.onSend, required this.textCtrl});
  final ChatChannel channel;
  final VoidCallback onSend;
  final TextEditingController textCtrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: ChatService.I.messagesStream(channel),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? ChatService.I.getMessages(channel);
              if (messages.isEmpty) {
                return Center(child: Text('No messages yet', style: TextStyle(color: cs.onSurfaceVariant)));
              }
              return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  reverse: true,
                  itemBuilder: (_, i) {
                    final msg = messages[messages.length - 1 - i];
                    final isMe = msg.uid == 'local_user' || msg.uid == (AuthService.I.uid);
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? cs.primary.withValues(alpha: .15) : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  msg.senderName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                            Text(msg.text),
                            const SizedBox(height: 4),
                            Text(
                              '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
            },
          ),
        ),
        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.emoji_emotions_outlined),
                onPressed: () {},
              ),
              Expanded(
                child: TextField(
                  controller: textCtrl,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: cs.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send),
                onPressed: onSend,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivateChatList extends StatelessWidget {
  const _PrivateChatList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final demoUsers = ['Commander_X', 'DarkKnight99', 'StormBringer', 'VoidWalker', 'NatureGuard'];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: demoUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        return ListTile(
          tileColor: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: CircleAvatar(child: Text(demoUsers[i][0])),
          title: Text(demoUsers[i]),
          subtitle: const Text('Tap to chat'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _PrivateChatScreen(userName: demoUsers[i]),
              ),
            );
          },
        );
      },
    );
  }
}

class _PrivateChatScreen extends StatefulWidget {
  const _PrivateChatScreen({required this.userName});
  final String userName;

  @override
  State<_PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<_PrivateChatScreen> {
  final _textCtrl = TextEditingController();

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    ChatService.I.sendMessage(
      channel: ChatChannel.private_,
      text: text,
      senderName: 'Player_123',
      targetId: widget.userName,
    );
    _textCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.userName)),
      body: _ChatView(
        channel: ChatChannel.private_,
        onSend: _send,
        textCtrl: _textCtrl,
      ),
    );
  }
}
