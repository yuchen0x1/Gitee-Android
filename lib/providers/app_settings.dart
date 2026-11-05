import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用级设置，负责深色模式与搜索历史的持久化。
class AppSettingsProvider extends ChangeNotifier {
  AppSettingsProvider({
    required bool darkMode,
    List<String>? searchHistory,
    List<String>? recentRepos,
  })  : _darkMode = darkMode,
        _searchHistory = List.of(searchHistory ?? const []),
        _recentRepos = List.of(recentRepos ?? const []);

  bool _darkMode;
  final List<String> _searchHistory;
  final List<String> _recentRepos; // 格式: "owner/repo"

  bool get darkMode => _darkMode;
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  List<String> get recentRepos => List.unmodifiable(_recentRepos);

  /// 记录最近浏览过的仓库 (最多保留 15 个)
  Future<void> addRecentRepo(String fullName) async {
    final name = fullName.trim();
    if (name.isEmpty || !name.contains('/')) return;
    _recentRepos.remove(name);
    _recentRepos.insert(0, name);
    if (_recentRepos.length > 15) {
      _recentRepos.removeRange(15, _recentRepos.length);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_repos', _recentRepos);
    } catch (_) {}
  }

  Future<void> clearRecentRepos() async {
    _recentRepos.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_repos', const []);
    } catch (_) {}
  }

  /// 切换深色模式并写入本地存储。
  Future<void> setDarkMode(bool value) async {
    if (_darkMode == value) return;
    _darkMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', value);
    } catch (_) {
      // 持久化失败不影响内存状态。
    }
  }

  Future<void> toggleDarkMode() => setDarkMode(!_darkMode);

  /// 新增一条搜索历史，最多保留 10 条。
  Future<void> addSearchHistory(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return;
    _searchHistory.remove(q);
    _searchHistory.insert(0, q);
    if (_searchHistory.length > 10) {
      _searchHistory.removeRange(10, _searchHistory.length);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('search_history', _searchHistory);
    } catch (_) {
      // 持久化失败不影响内存状态。
    }
  }

  Future<void> removeSearchHistory(String keyword) async {
    _searchHistory.remove(keyword);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('search_history', _searchHistory);
    } catch (_) {
      // 持久化失败不影响内存状态。
    }
  }

  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('search_history', const []);
    } catch (_) {
      // 持久化失败不影响内存状态。
    }
  }

  static Future<AppSettingsProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettingsProvider(
      darkMode: prefs.getBool('dark_mode') ?? false,
      searchHistory: prefs.getStringList('search_history') ?? const [],
      recentRepos: prefs.getStringList('recent_repos') ?? const [],
    );
  }
}

/// 通过 InheritedNotifier 向整棵组件树提供设置。
class AppSettingsScope extends InheritedNotifier<AppSettingsProvider> {
  const AppSettingsScope({
    super.key,
    required AppSettingsProvider settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettingsProvider of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope not found in widget tree');
    return scope!.notifier!;
  }
}
