import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/repo.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import '../widgets/paged_repo_list.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_views.dart';

/// 用户主页：用户信息 + 热门/最近更新仓库。
class UserProfilePage extends StatefulWidget {
  final String username;

  const UserProfilePage({super.key, required this.username});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  User? _user;
  bool _loading = true;
  String? _error;
  bool _hot = true;
  bool _following = false;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    try {
      final user = await GiteeApi.getUserProfile(widget.username);
      final following = await GiteeApi.checkFollowing(widget.username);
      if (!mounted) return;
      setState(() {
        _user = user;
        _following = following;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _toggleFollowing() async {
    if (_followLoading) return;
    setState(() => _followLoading = true);
    try {
      if (_following) {
        await GiteeApi.unfollowUser(widget.username);
      } else {
        await GiteeApi.followUser(widget.username);
      }
      if (!mounted) return;
      setState(() {
        _following = !_following;
        _followLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_following ? '已关注 @${widget.username}' : '已取消关注'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _followLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<List<Repo>> _loadRepos(int page) async {
    final list = await GiteeApi.getUserRepos(
      username: widget.username,
      page: page,
      perPage: 20,
    );
    if (_hot) {
      list.sort((a, b) => b.stars.compareTo(a.stars));
    } else {
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
        actions: [
          if (_user != null)
            IconButton(
              tooltip: _following ? '取消关注' : '关注',
              onPressed: _followLoading ? null : _toggleFollowing,
              icon: _followLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _following ? Icons.person_remove : Icons.person_add,
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_user == null && _loading)
            const Expanded(child: SkeletonList())
          else if (_user == null && _error != null)
            Expanded(
              child: ErrorState(message: _error!, onRetry: _loadUser),
            )
          else ...[
            _UserHeader(user: _user!),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: true,
                        label: Text('热门'),
                        icon: Icon(Icons.local_fire_department_outlined)),
                    ButtonSegment(
                        value: false,
                        label: Text('最近更新'),
                        icon: Icon(Icons.update)),
                  ],
                  selected: {_hot},
                  onSelectionChanged: (value) =>
                      setState(() => _hot = value.first),
                ),
              ),
            ),
            Expanded(
              child: PagedRepoList(
                key: ValueKey(_hot),
                loadPage: _loadRepos,
                emptyTitle: '暂无仓库',
                emptySubtitle: '该用户还没有公开仓库',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final User user;

  const _UserHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryRed, AppColors.primaryDark],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: AppAvatar(url: user.avatarUrl, size: 64, radius: 32),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text('@${user.login}',
              style: const TextStyle(fontSize: 14, color: Colors.white70)),
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              user.bio,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _HeaderStat(label: '仓库', value: user.publicRepos),
              _HeaderStat(label: '粉丝', value: user.followers),
              _HeaderStat(label: '关注', value: user.following),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final int value;

  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}
