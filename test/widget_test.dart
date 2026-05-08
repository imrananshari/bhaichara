import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/app.dart';

void main() {
  testWidgets('Initial screen shows welcome message', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BhaiCharaApp()));

    expect(find.text('Welcome to bhai chara'), findsOneWidget);
  });
}
