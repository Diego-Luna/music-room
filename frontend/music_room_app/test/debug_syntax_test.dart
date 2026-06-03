import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Debug syntax', () {
    double? lat;
    final map = {'lat': ?lat};
    print('Map: $map');
  });
}
