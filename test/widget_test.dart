import 'package:flutter_test/flutter_test.dart';
import 'package:trusttier_rider/main.dart';

void main() {
  testWidgets('shows new job requests', (tester) async {
    await tester.pumpWidget(const RiderApp());
    expect(find.text('New requests'), findsOneWidget);
    expect(find.text('Parcel to Hospital Road'), findsOneWidget);
  });
}
