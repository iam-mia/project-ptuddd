import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO(MinhAnh): Load .env và khởi tạo Supabase.initialize(...) ở đây

  runApp(
    const ProviderScope(
      child: TluPeerLearnApp(),
    ),
  );
}

class TluPeerLearnApp extends ConsumerWidget {
  const TluPeerLearnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'TLU PeerLearn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
