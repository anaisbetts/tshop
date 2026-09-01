import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tshop/src/app.dart';

void main() {
  testWidgets('home shows tShop', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TshopApp()));
    expect(find.text('tShop'), findsOneWidget);
  });
}
