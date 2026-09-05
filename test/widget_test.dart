import 'package:flutter_test/flutter_test.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/scripts/data_management/startup_logger.dart';

void main() {
  test('Startup logger records timestamped entries', () {
    expect(() => logStartup('Test stage'), returnsNormally);
  });

  test('Uninitialized transit data defaults to empty collections', () {
    expect(getStops(), isA<List>());
    expect(getSvcs(), isA<Map>());
    expect(getMRTData(), isA<Map>());
  });
}
