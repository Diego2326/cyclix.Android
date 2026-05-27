import 'package:cyclix_wear/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Cyclix Watch muestra login sin sesion', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const CyclixWearApp());
    await tester.pumpAndSettle();

    expect(find.text('CYCLIX'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
