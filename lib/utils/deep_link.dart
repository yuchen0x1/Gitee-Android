import 'package:flutter/material.dart';
import '../pages/commit_detail_page.dart';
import '../pages/issue_detail_page.dart';
import '../pages/pr_detail_page.dart';
import '../pages/repo_detail_page.dart';
import '../pages/user_profile_page.dart';

/// 解析深链（支持自定义协议 gitee:// 以及标准网页链接 https://gitee.com/...）并跳转到对应页面。
void handleDeepLink(
  Uri uri,
  GlobalKey<NavigatorState> navKey,
) {
  final navigator = navKey.currentState;
  if (navigator == null) return;

  final scheme = uri.scheme.toLowerCase();

  // 1. 自定义协议：gitee://
  if (scheme == 'gitee') {
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
      case 'pull':
      case 'pulls':
        if (segments.length >= 4) {
          final number = int.tryParse(segments[3]);
          if (number != null) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => PullRequestDetailPage(
                  owner: segments[1],
                  repo: segments[2],
                  number: number,
                ),
              ),
            );
          }
        }
      case 'commit':
        if (segments.length >= 4) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => CommitDetailPage(
                owner: segments[1],
                repo: segments[2],
                sha: segments[3],
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
    return;
  }

  // 2. 外部 Web 链接：https://gitee.com/...
  if (scheme == 'http' || scheme == 'https') {
    final host = uri.host.toLowerCase();
    if (host != 'gitee.com' && host != 'www.gitee.com') return;

    final segs = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (segs.isEmpty) return;

    // 单段路径：如 /alice -> 用户主页（需避开系统关键字）
    const sysReserved = {
      'explore',
      'enterprises',
      'gvp',
      'help',
      'login',
      'signup',
      'notifications',
      'search',
      'api',
      'terms',
      'privacy',
    };
    if (segs.length == 1 && !sysReserved.contains(segs[0].toLowerCase())) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => UserProfilePage(username: segs[0]),
        ),
      );
      return;
    }

    // 两段路径：如 /owner/repo -> 仓库主页
    if (segs.length == 2 && !sysReserved.contains(segs[0].toLowerCase())) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => RepoDetailPage(owner: segs[0], repo: segs[1]),
        ),
      );
      return;
    }

    // 三段及以上路径：如 /owner/repo/issues/123 或 /owner/repo/pulls/456 或 /owner/repo/commit/sha
    if (segs.length >= 4 && !sysReserved.contains(segs[0].toLowerCase())) {
      final owner = segs[0];
      final repo = segs[1];
      final type = segs[2].toLowerCase();
      final target = segs[3];

      if (type == 'issues') {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => IssueDetailPage(
              owner: owner,
              repo: repo,
              number: target,
            ),
          ),
        );
        return;
      }

      if (type == 'pulls' || type == 'pull') {
        final prNum = int.tryParse(target);
        if (prNum != null) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => PullRequestDetailPage(
                owner: owner,
                repo: repo,
                number: prNum,
              ),
            ),
          );
          return;
        }
      }

      if (type == 'commit') {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => CommitDetailPage(
              owner: owner,
              repo: repo,
              sha: target,
            ),
          ),
        );
        return;
      }
    }
  }
}
