import 'package:cyclix_mapa_detalle/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CyclixApp se construye', (WidgetTester tester) async {
    await tester.pumpWidget(const CyclixApp());
    expect(find.text('Cyclix'), findsOneWidget);
  });
}
