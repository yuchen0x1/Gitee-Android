class OAuthToken {
  const OAuthToken({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String tokenType;

  bool get isExpired =>
      expiresAt != null &&
      !expiresAt!.isAfter(DateTime.now().add(const Duration(minutes: 1)));

  factory OAuthToken.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw const FormatException('OAuth 响应缺少 access_token');
    }

    DateTime? expiresAt;
    final expiresIn = int.tryParse(json['expires_in']?.toString() ?? '');
    if (expiresIn != null && expiresIn > 0) {
      final createdAt = int.tryParse(json['created_at']?.toString() ?? '');
      final issuedAt = createdAt == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
      expiresAt = issuedAt.add(Duration(seconds: expiresIn));
    }

    return OAuthToken(
      accessToken: accessToken,
      refreshToken: _nullableString(json['refresh_token']),
      expiresAt: expiresAt,
      tokenType: _nullableString(json['token_type']) ?? 'Bearer',
    );
  }

  factory OAuthToken.fromStoredJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw const FormatException('保存的 OAuth 凭据无效');
    }
    final expiresAtMillis = int.tryParse(json['expiresAt']?.toString() ?? '');
    return OAuthToken(
      accessToken: accessToken,
      refreshToken: _nullableString(json['refreshToken']),
      expiresAt: expiresAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAtMillis),
      tokenType: _nullableString(json['tokenType']) ?? 'Bearer',
    );
  }

  Map<String, dynamic> toStoredJson() => {
        'accessToken': accessToken,
        if (refreshToken != null) 'refreshToken': refreshToken,
        if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
        'tokenType': tokenType,
      };

  static String? _nullableString(dynamic value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? null : text;
  }
}
