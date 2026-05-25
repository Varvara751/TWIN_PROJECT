import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin_project/main.dart';

class _TestAssetBundle extends CachingAssetBundle {
  static final Uint8List _transparentPng = Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<Object?, Object?>{})!;
    }

    return ByteData.sublistView(_transparentPng);
  }
}

Widget _buildTestApp(Widget child) {
  return DefaultAssetBundle(
    bundle: _TestAssetBundle(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('WelcomeScreen renders the auth entry points', (tester) async {
    await tester.pumpWidget(_buildTestApp(const WelcomeScreen()));

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('TWIN'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('Create profile action opens RegisterScreen', (tester) async {
    await tester.pumpWidget(_buildTestApp(const WelcomeScreen()));

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('RegisterScreen validates empty email before network calls', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const RegisterScreen()));

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('MainScreen switches between bottom navigation tabs', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const MainScreen()));

    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    expect(find.byType(FavoritesScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pump();
    expect(find.byType(MessengerScreen), findsOneWidget);
  });
}
