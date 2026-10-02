import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/models/sync_settings.dart';

void main() {
  const token = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('remote synchronization requires HTTPS', () {
    const settings = SyncSettings(
      serverUrl: 'http://sync.example.test',
      token: token,
      deviceName: '测试设备',
    );

    expect(settings.validationMessage, contains('HTTPS'));
  });

  test('loopback HTTP remains available for local development', () {
    const settings = SyncSettings(
      serverUrl: 'http://127.0.0.1:8080',
      token: token,
      deviceName: '测试设备',
    );

    expect(settings.validationMessage, isNull);
  });
}
