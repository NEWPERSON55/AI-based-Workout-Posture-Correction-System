import 'package:flutter_test/flutter_test.dart';
import 'package:pushup_app/main.dart';

void main() {
  testWidgets('App starts', (tester) async {
    await tester.pumpWidget(const KineticApp());
  });
}
