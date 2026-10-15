import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/error_messages.dart';
import 'package:provider/provider.dart';

import 'account_tab.dart';
import 'chats_tab.dart';
import 'categories_tab.dart';
import 'discover_tab.dart';
import 'password_recovery_screen.dart';
import 'sell_tab.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../services/push_notification_service.dart';
import 'chat_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _recoveryRouteQueued = false;
  StreamSubscription<Map<String, dynamic>>? _pushSubscription;
  StreamSubscription<Map<String, dynamic>>? _incomingMessageSubscription;
  final ChatService _chat = ChatService();
  String? _incomingUserId;
  String? _unreadUserId;
  Stream<int>? _unreadCountStream;

  static const _titles = ['Discover', 'Categories', 'Sell', 'Chats', 'Account'];

  @override
  void initState() {
    super.initState();
    _pushSubscription = PushNotificationService.instance.openedChats.listen(
      _openChatFromNotification,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = PushNotificationService.instance.takePendingOpen();
      if (initial != null) _openChatFromNotification(initial);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().userId ?? '';
    if (userId == _incomingUserId) return;
    _incomingUserId = userId;
    _incomingMessageSubscription?.cancel();
    if (userId.isNotEmpty) {
      _incomingMessageSubscription = _chat
          .watchIncomingMessages(userId)
          .listen(
            _showInAppMessage,
            onError: (Object error, StackTrace stackTrace) {
              debugLog('Incoming chat stream failed: $error');
            },
          );
    }
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    _incomingMessageSubscription?.cancel();
    super.dispose();
  }

  void _showInAppMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    final buyerId = '${data['buyer_id'] ?? ''}';
    final sellerId = '${data['seller_id'] ?? ''}';
    if (userId == null || (userId != buyerId && userId != sellerId)) return;

    final senderName = userId == buyerId
        ? '${data['seller_name'] ?? 'Seller'}'
        : '${data['buyer_name'] ?? 'Buyer'}';
    final listingTitle = '${data['listing_title'] ?? 'your listing'}';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('New message from $senderName · $listingTitle'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () => _openChatFromNotification(data),
          ),
        ),
      );
  }

  Stream<int> _watchUnreadFor(String userId) {
    if (_unreadUserId != userId || _unreadCountStream == null) {
      _unreadUserId = userId;
      _unreadCountStream = _chat.watchUnreadCount(userId);
    }
    return _unreadCountStream!;
  }

  void _openChatFromNotification(Map<String, dynamic> data) {
    if (!mounted) return;
    PushNotificationService.instance.takePendingOpen();
    final auth = context.read<AuthProvider>();
    final buyerId = '${data['buyer_id'] ?? ''}';
    final sellerId = '${data['seller_id'] ?? ''}';
    final userId = auth.userId;
    if (userId == null || (userId != buyerId && userId != sellerId)) return;
    setState(() => _index = 3);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          listingId: '${data['listing_id']}',
          listingTitle: '${data['listing_title'] ?? 'Listing'}',
          buyerId: buyerId,
          buyerName: '${data['buyer_name'] ?? 'Buyer'}',
          sellerId: sellerId,
          sellerName: '${data['seller_name'] ?? 'Seller'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.passwordRecoveryPending && !_recoveryRouteQueued) {
      _recoveryRouteQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const ResetPasswordScreen()),
        );
        if (!mounted) return;
        auth.dismissPasswordRecovery();
        setState(() => _recoveryRouteQueued = false);
      });
    }
    final cs = Theme.of(context).colorScheme;
    final unreadStream = _watchUnreadFor(auth.userId ?? '');
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          DiscoverTab(),
          CategoriesTab(),
          SellTab(),
          ChatsTab(),
          AccountTab(),
        ],
      ),
      bottomNavigationBar: StreamBuilder<int>(
        stream: unreadStream,
        builder: (context, unreadSnapshot) {
          final unreadCount = unreadSnapshot.data ?? 0;
          final unreadLabel = unreadCount > 99 ? '99+' : '$unreadCount';
          return Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Discover',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view),
                  label: 'Categories',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.sell_outlined),
                  selectedIcon: Icon(Icons.sell),
                  label: 'Sell',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(unreadLabel),
                    child: const Icon(Icons.chat_bubble_outline),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(unreadLabel),
                    child: const Icon(Icons.chat_bubble),
                  ),
                  label: 'Chats',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Account',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
