import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tlu_peerlearn/features/auth_profile/domain/user_profile.dart';
import 'package:tlu_peerlearn/features/auth_profile/presentation/login_screen.dart';
import 'package:tlu_peerlearn/features/auth_profile/presentation/profile_screen.dart';
import 'package:tlu_peerlearn/features/auth_profile/presentation/register_screen.dart';

void main() {
  testWidgets('LoginScreen validates empty email and password', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('Đăng nhập'));
    await tester.pump();

    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
  });

  testWidgets('RegisterScreen validates required fields', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterScreen()),
      ),
    );

    await tester.tap(find.text('Đăng ký'));
    await tester.pump();

    expect(find.text('Vui lòng nhập họ và tên'), findsOneWidget);
    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
  });

  testWidgets('ProfileScreen displays initial data and validates fullName',
      (tester) async {
    const profile = UserProfile(
      id: 'u1',
      email: 'minhanh@tlu.edu.vn',
      fullName: 'Phùng Minh Anh',
      studentId: '2351170574',
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProfileScreen(initialProfile: profile)),
      ),
    );

    expect(find.text('minhanh@tlu.edu.vn'), findsOneWidget);
    expect(find.text('Phùng Minh Anh'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pump();

    expect(find.text('Vui lòng nhập họ và tên'), findsOneWidget);
  });
}
