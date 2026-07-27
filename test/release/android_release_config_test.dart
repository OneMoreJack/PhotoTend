import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release uses the PhotoTend identity and external signing', () {
    final buildFile = File('android/app/build.gradle.kts').readAsStringSync();

    expect(buildFile, contains('namespace = "top.onemorejack.phototend"'));
    expect(buildFile, contains('applicationId = "top.onemorejack.phototend"'));
    expect(buildFile, contains('PHOTOTEND_KEYSTORE_PATH'));
    expect(buildFile, contains('PHOTOTEND_KEYSTORE_PASSWORD'));
    expect(buildFile, contains('PHOTOTEND_KEY_ALIAS'));
    expect(buildFile, contains('PHOTOTEND_KEY_PASSWORD'));
    expect(
      buildFile,
      isNot(contains('signingConfig = signingConfigs.getByName("debug")')),
    );
  });
}
