import 'package:flutter_test/flutter_test.dart';
import 'package:plantidentifier/services/identification_policy.dart';

void main() {
  test('normal identification is not quota-gated', () {
    expect(IdentificationPolicy.showFreeScanCounter, isFalse);
    expect(
      IdentificationPolicy.canStartIdentification(freeScansRemaining: 0),
      isTrue,
    );
  });
}
