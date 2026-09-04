import 'package:flutter/material.dart';
import '../models/user.dart';
import '../pages/user_profile_page.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';
import 'pressable_scale.dart';

/// 通用用户列表项。
class UserTile extends StatelessWidget {
  final User user;

  const UserTile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserProfilePage(username: user.login),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: AppAvatar(url: user.avatarUrl, size: 44, radius: 10),
          title: Text(user.name, style: theme.textTheme.titleMedium),
          subtitle: Text('@${user.login}', style: theme.textTheme.bodySmall),
          trailing:
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
