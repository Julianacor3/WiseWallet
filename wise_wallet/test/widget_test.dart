
import 'package:flutter_test/flutter_test.dart';
import 'package:wise_wallet/main.dart';

void main() {
  testWidgets('La aplicación Wise Wallet inicia correctamente',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WiseWalletApp());

    expect(find.byType(WiseWalletApp), findsOneWidget);
    expect(find.text('Registro'), findsOneWidget);
  });
}