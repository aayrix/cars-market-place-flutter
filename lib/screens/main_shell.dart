import 'package:flutter/material.dart';

import 'account_tab.dart';
import 'chats_tab.dart';
import 'categories_tab.dart';
import 'discover_tab.dart';
import 'sell_tab.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _titles = ['Discover', 'Categories', 'Sell', 'Chats', 'Account'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: cs.outlineVariant.withOpacity(0.35),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Categories',
            ),
            NavigationDestination(
              icon: Icon(Icons.sell_outlined),
              selectedIcon: Icon(Icons.sell),
              label: 'Sell',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}
