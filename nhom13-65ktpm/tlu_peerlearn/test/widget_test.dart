import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tlu_peerlearn/main.dart';

void main() {
  testWidgets('App renders placeholder home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: TluPeerLearnApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TLU PeerLearn - Project Setup Complete!'), findsOneWidget);
  });
}
