import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth_profile/data/auth_repository.dart';
import '../features/auth_profile/presentation/login_screen.dart';
import '../features/auth_profile/presentation/register_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final profileAsync = ref.watch(currentProfileProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final profile = profileAsync.value;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (profile == null) {
        return isAuthRoute ? null : '/login';
      }

      if (isAuthRoute) {
        return profile.isAdmin ? '/admin' : '/student';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/student',
        builder: (context, state) => const _RoleHomePlaceholder(
          title: 'Sinh viên - TLU PeerLearn',
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const _RoleHomePlaceholder(
          title: 'Admin - TLU PeerLearn',
        ),
      ),
    ],
  );
});

class _RoleHomePlaceholder extends ConsumerWidget {
  final String title;
  const _RoleHomePlaceholder({required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Center(child: Text(title)),
    );
  }
}
