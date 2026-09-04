import 'package:flutter/material.dart';
import '../pages/issue_detail_page.dart';
import '../pages/repo_detail_page.dart';
import '../pages/user_profile_page.dart';

/// 解析 gitee:// 深链并跳转到对应页面。
/// 支持 repo、issue、user 业务深链。
void handleDeepLink(
  Uri uri,
  GlobalKey<NavigatorState> navKey,
) {
  if (uri.scheme != 'gitee') return;

  final navigator = navKey.currentState;
  if (navigator == null) return;
  // For a URI such as gitee://user/alice, "user" is the host rather than a
  // path segment. Include it so the documented custom-scheme links resolve.
  final segments = <String>[
    if (uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments.where((e) => e.isNotEmpty),
  ];
  if (segments.isEmpty) return;
  switch (segments[0]) {
    case 'repo':
      if (segments.length >= 3) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) =>
                RepoDetailPage(owner: segments[1], repo: segments[2]),
          ),
        );
      }
    case 'issue':
      if (segments.length >= 4) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => IssueDetailPage(
              owner: segments[1],
              repo: segments[2],
              number: segments[3],
            ),
          ),
        );
      }
    case 'user':
      if (segments.length >= 2) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => UserProfilePage(username: segments[1]),
          ),
        );
      }
  }
}
