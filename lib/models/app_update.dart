import 'package:flutter/foundation.dart';

/// GitHub Release 中用于应用更新的二进制附件。
class AppUpdateAsset {
  final String name;
  final String url;
  final int size;

  const AppUpdateAsset({
    required this.name,
    required this.url,
    this.size = 0,
  });

  factory AppUpdateAsset.fromJson(Map<String, dynamic> json) {
    return AppUpdateAsset(
      name: json['name']?.toString() ?? '',
      url: json['browser_download_url']?.toString() ??
          json['download_url']?.toString() ??
          json['downloadUrl']?.toString() ??
          '',
      size: json['size'] is num ? (json['size'] as num).toInt() : 0,
    );
  }
}

/// 公开 Release 中的一次客户端更新。
class AppUpdate {
  final String version;
  final String name;
  final String notes;
  final String htmlUrl;
  final String publishedAt;
  final List<AppUpdateAsset> assets;

  const AppUpdate({
    required this.version,
    required this.name,
    required this.notes,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  factory AppUpdate.fromGitHubJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'];
    return AppUpdate(
      version: json['tag_name']?.toString() ?? '',
      name: json['name']?.toString() ?? json['tag_name']?.toString() ?? '',
      notes: json['body']?.toString() ?? '',
      htmlUrl: json['html_url']?.toString() ?? '',
      publishedAt: json['published_at']?.toString() ?? '',
      assets: rawAssets is List
          ? rawAssets
              .whereType<Map>()
              .map((asset) => AppUpdateAsset.fromJson(
                    Map<String, dynamic>.from(asset),
                  ))
              .where((asset) => asset.name.isNotEmpty && asset.url.isNotEmpty)
              .toList(growable: false)
          : const [],
    );
  }

  /// 返回当前平台最合适的发布附件；没有对应安装包时返回 null。
  AppUpdateAsset? assetForPlatform(TargetPlatform platform) {
    if (platform == TargetPlatform.android) {
      final apks = assets
          .where((asset) => asset.name.toLowerCase().endsWith('.apk'))
          .toList(growable: false);
      for (final asset in apks) {
        final name = asset.name.toLowerCase();
        if (name == 'app-release.apk' ||
            name.contains('android-universal') ||
            name.contains('universal')) {
          return asset;
        }
      }
      return apks.isEmpty ? null : apks.first;
    }
    if (platform == TargetPlatform.windows) {
      for (final asset in assets) {
        if (asset.name.toLowerCase().endsWith('windows-x64.zip')) {
          return asset;
        }
      }
    }
    return null;
  }
}

/// 仅比较数字版本，兼容 v2.0.0、2.0 和带构建号的版本。
int compareAppVersions(String left, String right) {
  List<int> parts(String value) {
    final match = RegExp(r'\d+(?:\.\d+){0,2}').firstMatch(value);
    if (match == null) return [0, 0, 0];
    final values = match.group(0)!.split('.').map(int.parse).toList();
    while (values.length < 3) {
      values.add(0);
    }
    return values.take(3).toList();
  }

  final a = parts(left);
  final b = parts(right);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}
