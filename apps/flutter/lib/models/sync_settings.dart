class SyncSettings {
  static const defaultServerUrl = 'https://todo.darker.one';

  const SyncSettings({
    this.serverUrl = defaultServerUrl,
    this.token = '',
    this.deviceName = '',
    this.autoSync = true,
  });

  final String serverUrl;
  final String token;
  final String deviceName;
  final bool autoSync;

  bool get hasValidToken => RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(token.trim());

  String? get validationMessage {
    if (serverUrl.trim().isEmpty) return '请填写服务器地址';
    final normalizedUrl = serverUrl.trim().contains('://')
        ? serverUrl.trim()
        : 'https://${serverUrl.trim()}';
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || uri.host.isEmpty) return '服务器地址格式不正确';
    final host = uri.host.toLowerCase();
    final isLoopback = host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1';
    if (uri.scheme.toLowerCase() != 'https' &&
        !(uri.scheme.toLowerCase() == 'http' && isLoopback)) {
      return '远程同步必须使用 HTTPS；HTTP 仅允许本机调试';
    }
    if (token.trim().isEmpty) return '请填写同步密钥';
    if (!hasValidToken) return '同步密钥必须是 64 位十六进制字符';
    if (deviceName.trim().isEmpty) return '请填写设备名';
    return null;
  }

  bool get isConfigured => validationMessage == null;

  SyncSettings normalized() => SyncSettings(
    serverUrl: serverUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
    token: token.trim(),
    deviceName: deviceName.trim(),
    autoSync: autoSync,
  );

  Map<String, Object?> toJson() => {
    'serverUrl': serverUrl,
    'deviceName': deviceName,
    'autoSync': autoSync,
  };

  factory SyncSettings.fromJson(Map<String, Object?> json) => SyncSettings(
    serverUrl: (json['serverUrl'] as String?) ?? defaultServerUrl,
    // Reading token here supports one-time migration from an early plaintext
    // configuration. New writes deliberately omit it from [toJson].
    token: (json['token'] as String?) ?? '',
    deviceName: (json['deviceName'] as String?) ?? '',
    autoSync: (json['autoSync'] as bool?) ?? true,
  ).normalized();
}
