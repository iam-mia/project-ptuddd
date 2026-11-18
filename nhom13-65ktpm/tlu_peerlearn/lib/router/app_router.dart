import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _PlaceholderHomeScreen(),
      ),
      // TODO(MinhAnh): Thêm routes cho auth_profile & admin
      // TODO(Phuoc): Thêm routes cho room_matching
      // TODO(TuanAnh): Thêm routes cho documents & ai_generator
      // TODO(TuanSon): Thêm routes cho practice_stats & sessions
    ],
  );
});

class _PlaceholderHomeScreen extends StatelessWidget {
  const _PlaceholderHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TLU PeerLearn')),
      body: const Center(
        child: Text('TLU PeerLearn - Project Setup Complete!'),
      ),
    );
  }
}

