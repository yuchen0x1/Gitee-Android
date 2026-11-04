import 'dart:convert';
import 'api_client.dart';
import '../models/commit.dart';
import '../models/event.dart';
import '../models/file.dart';
import '../models/issue.dart';
import '../models/issue_comment.dart';
import '../models/gitee_api_entities.dart';
import '../models/notification.dart';
import '../models/pull_request.dart';
import '../models/release.dart';
import '../models/repo.dart';
import '../models/user.dart';

/// Gitee Open API v5 封装。
class GiteeApi {
  GiteeApi._();

  static ApiClient _client = ApiClient();

  static void Function()? get onUnauthorized => _client.onUnauthorized;
  static set onUnauthorized(void Function()? value) =>
      _client.onUnauthorized = value;

  static void setToken(String token) {
    _client.clearCache();
    _client.setToken(token);
  }

  static void clearToken() {
    _client.clearCache();
    _client.setToken(null);
  }

  static String? get token => _client.token;

  /// 测试用：注入替换传输层（如 MockClient）。
  static void setClientForTest(ApiClient client) => _client = client;

  // ---------- HTTP 核心（转发到可注入的 ApiClient） ----------

  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool formEncoded = false,
  }) =>
      _client.request(
        method,
        path,
        query: query,
        body: body,
        formEncoded: formEncoded,
      );

  static Future<dynamic> _requestCached(
    String path, {
    Map<String, String>? query,
    Duration ttl = const Duration(seconds: 30),
  }) =>
      _client.requestCached(path, query: query, ttl: ttl);

  static Map<String, String> _paging(int page, int perPage) =>
      ApiClient.paging(page, perPage);
  static Map<String, dynamic> _asMap(dynamic data) => ApiClient.asMap(data);
  static List<dynamic> _asList(dynamic data) => ApiClient.asList(data);
  static String _enc(String value) => ApiClient.enc(value);
  static String _encPath(String path) => ApiClient.encPath(path);
  static String? _decodeContent(dynamic content) =>
      ApiClient.decodeContent(content);

  /// 通用 v5 请求入口，供尚未绑定独立页面的官方接口直接调用。
  static Future<dynamic> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool formEncoded = false,
  }) =>
      _request(
        method,
        path,
        query: query,
        body: body,
        formEncoded: formEncoded,
      );

  static Future<dynamic> get(String path, {Map<String, String>? query}) =>
      request('GET', path, query: query);

  static Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool formEncoded = false,
  }) =>
      request('POST', path, query: query, body: body, formEncoded: formEncoded);

  static Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool formEncoded = false,
  }) =>
      request('PUT', path, query: query, body: body, formEncoded: formEncoded);

  static Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool formEncoded = false,
  }) =>
      request('PATCH', path,
          query: query, body: body, formEncoded: formEncoded);

  static Future<dynamic> delete(String path, {Map<String, String>? query}) =>
      request('DELETE', path, query: query);

  // ---------- 用户 ----------

  static Future<User> getCurrentUser() async {
    final data = await _request('GET', '/user');
    return User.fromJson(_asMap(data));
  }

  static Future<User> getUserProfile(String username) async {
    final data = await _request('GET', '/users/${_enc(username)}');
    return User.fromJson(_asMap(data));
  }

  static Future<List<Repo>> getUserRepos({
    String? username,
    int page = 1,
    int perPage = 20,
    String sort = 'updated',
  }) async {
    final path = (username == null || username.isEmpty)
        ? '/user/repos'
        : '/users/${_enc(username)}/repos';
    final data = await _request(
      'GET',
      path,
      query: {..._paging(page, perPage), 'sort': sort},
    );
    return _asList(data).map((e) => Repo.fromJson(_asMap(e))).toList();
  }

  // ---------- 搜索 ----------

  /// Gitee v5 搜索接口直接返回数组，这里兼容返回对象包裹的响应。
  static List<dynamic> _searchItems(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final map = _asMap(data);
      return _asList(
        map['repositories'] ??
            map['issues'] ??
            map['users'] ??
            map['items'] ??
            <dynamic>[],
      );
    }
    throw GiteeApiException('数据格式错误');
  }

  static Future<List<Repo>> searchRepos(
    String keyword, {
    int page = 1,
    int perPage = 30,
    String? owner,
    String? language,
    bool? includeForks,
    String? sort,
    String? order,
  }) async {
    final query = <String, String>{
      'q': keyword,
      ..._paging(page, perPage),
    };
    if (owner != null && owner.trim().isNotEmpty) query['owner'] = owner.trim();
    if (language != null && language.isNotEmpty) query['language'] = language;
    if (includeForks != null) query['fork'] = includeForks.toString();
    if (sort != null && sort.isNotEmpty) query['sort'] = sort;
    if (order != null && order.isNotEmpty) query['order'] = order;
    final data = await _request(
      'GET',
      '/search/repositories',
      query: query,
    );
    return _searchItems(data).map((e) => Repo.fromJson(_asMap(e))).toList();
  }

  static Future<List<User>> searchUsers(
    String keyword, {
    int page = 1,
    int perPage = 30,
    String? sort,
    String? order,
  }) async {
    final query = <String, String>{
      'q': keyword,
      ..._paging(page, perPage),
    };
    if (sort != null && sort.isNotEmpty) query['sort'] = sort;
    if (order != null && order.isNotEmpty) query['order'] = order;
    final data = await _request(
      'GET',
      '/search/users',
      query: query,
    );
    return _searchItems(data).map((e) => User.fromJson(_asMap(e))).toList();
  }

  static Future<List<Issue>> searchIssues(
    String keyword, {
    int page = 1,
    int perPage = 30,
    String? repo,
    String? language,
    String? label,
    String? state,
    String? author,
    String? assignee,
    String? sort,
    String? order,
  }) async {
    final query = <String, String>{
      'q': keyword,
      ..._paging(page, perPage),
    };
    final optional = <String, String?>{
      'repo': repo,
      'language': language,
      'label': label,
      'state': state,
      'author': author,
      'assignee': assignee,
      'sort': sort,
      'order': order,
    };
    optional.forEach((key, value) {
      if (value != null && value.trim().isNotEmpty) query[key] = value.trim();
    });
    final data = await _request('GET', '/search/issues', query: query);
    return _searchItems(data).map((e) => Issue.fromJson(_asMap(e))).toList();
  }

  // ---------- 仓库 ----------

  static Future<Repo> getRepoDetail(String owner, String repo) async {
    final data = await _requestCached('/repos/${_enc(owner)}/${_enc(repo)}');
    return Repo.fromJson(_asMap(data));
  }

  /// 获取仓库的 Topic 标签名称列表；兼容纯字符串与官方 Topic 对象两种返回。
  static Future<List<String>> getRepoTopics(String owner, String repo) async {
    final data = await _requestCached(
      '/repos/${_enc(owner)}/${_enc(repo)}/topics',
    );
    return _asList(data)
        .map((e) {
          if (e is String) return e;
          if (e is Map) {
            final name = e['topic_name'] ?? e['name'];
            return name?.toString() ?? '';
          }
          return '';
        })
        .where((name) => name.isNotEmpty)
        .toList();
  }

  static Future<String?> getRepoReadme(
    String owner,
    String repo, {
    String? branch,
  }) async {
    try {
      final query = branch == null || branch.isEmpty ? null : {'ref': branch};
      final data = await _requestCached(
        '/repos/${_enc(owner)}/${_enc(repo)}/readme',
        query: query,
      );
      final map = _asMap(data);
      return _decodeContent(map['content']);
    } on GiteeApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  static Future<List<RepoFile>> getRepoContents(
    String owner,
    String repo, {
    String path = '',
    String? branch,
  }) async {
    final suffix = path.isEmpty ? '' : '/${_encPath(path)}';
    final query = branch == null || branch.isEmpty ? null : {'ref': branch};
    final data = await _requestCached(
      '/repos/${_enc(owner)}/${_enc(repo)}/contents$suffix',
      query: query,
    );
    if (data is List) {
      return data.map((e) => RepoFile.fromJson(_asMap(e))).toList();
    }
    return [RepoFile.fromJson(_asMap(data))];
  }

  static Future<String?> getFileContent(
    String owner,
    String repo,
    String path, {
    String? branch,
  }) async {
    final query = branch == null || branch.isEmpty ? null : {'ref': branch};
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/contents/${_encPath(path)}',
      query: query,
    );
    final map = _asMap(data);
    return _decodeContent(map['content']);
  }

  /// 获取文件内容 + sha（编辑/删除需要 sha）。
  static Future<({String? content, String sha})> getFileWithSha(
    String owner,
    String repo,
    String path, {
    String? branch,
  }) async {
    final query = branch == null || branch.isEmpty ? null : {'ref': branch};
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/contents/${_encPath(path)}',
      query: query,
    );
    final map = _asMap(data);
    return (
      content: _decodeContent(map['content']),
      sha: map['sha']?.toString() ?? '',
    );
  }

  static Future<List<String>> getBranches(String owner, String repo) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/branches',
      query: _paging(1, 100),
    );
    return _asList(data)
        .map((e) => _asMap(e)['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  static Future<List<RepositoryBranch>> getBranchDetails(
    String owner,
    String repo, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/branches',
      query: _paging(page, perPage),
    );
    return _asList(data)
        .map((e) => RepositoryBranch.fromJson(_asMap(e)))
        .toList();
  }

  static Future<Map<String, dynamic>> getBranch(
    String owner,
    String repo,
    String branch,
  ) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/branches/${_enc(branch)}',
    );
    return _asMap(data);
  }

  static Future<Map<String, dynamic>> setBranchProtection({
    required String owner,
    required String repo,
    required String branch,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'PUT',
      '/repos/${_enc(owner)}/${_enc(repo)}/branches/${_enc(branch)}/protection',
    );
    return data is Map ? _asMap(data) : <String, dynamic>{};
  }

  static Future<void> removeBranchProtection(
    String owner,
    String repo,
    String branch,
  ) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'DELETE',
      '/repos/${_enc(owner)}/${_enc(repo)}/branches/${_enc(branch)}/protection',
    );
  }

  static Future<Map<String, dynamic>> createRepoFile({
    required String owner,
    required String repo,
    required String path,
    required String content,
    required String message,
    String? branch,
    String? committerName,
    String? committerEmail,
    String? authorName,
    String? authorEmail,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/contents/${_encPath(path)}',
      body: {
        'content': base64Encode(utf8.encode(content)),
        'message': message,
        if (branch != null && branch.isNotEmpty) 'branch': branch,
        if (committerName != null && committerName.isNotEmpty)
          'committer[name]': committerName,
        if (committerEmail != null && committerEmail.isNotEmpty)
          'committer[email]': committerEmail,
        if (authorName != null && authorName.isNotEmpty)
          'author[name]': authorName,
        if (authorEmail != null && authorEmail.isNotEmpty)
          'author[email]': authorEmail,
      },
      formEncoded: true,
    );
    return _asMap(data);
  }

  static Future<Map<String, dynamic>> updateRepoFile({
    required String owner,
    required String repo,
    required String path,
    required String content,
    required String sha,
    required String message,
    String? branch,
    String? committerName,
    String? committerEmail,
    String? authorName,
    String? authorEmail,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'PUT',
      '/repos/${_enc(owner)}/${_enc(repo)}/contents/${_encPath(path)}',
      body: {
        'content': base64Encode(utf8.encode(content)),
        'sha': sha,
        'message': message,
        if (branch != null && branch.isNotEmpty) 'branch': branch,
        if (committerName != null && committerName.isNotEmpty)
          'committer[name]': committerName,
        if (committerEmail != null && committerEmail.isNotEmpty)
          'committer[email]': committerEmail,
        if (authorName != null && authorName.isNotEmpty)
          'author[name]': authorName,
        if (authorEmail != null && authorEmail.isNotEmpty)
          'author[email]': authorEmail,
      },
      formEncoded: true,
    );
    return _asMap(data);
  }

  static Future<void> deleteRepoFile({
    required String owner,
    required String repo,
    required String path,
    required String sha,
    required String message,
    String? branch,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final query = <String, String>{'sha': sha, 'message': message};
    if (branch != null && branch.isNotEmpty) query['branch'] = branch;
    await _request(
      'DELETE',
      '/repos/${_enc(owner)}/${_enc(repo)}/contents/${_encPath(path)}',
      query: query,
    );
  }

  static Future<List<RepositoryTag>> getTags(
    String owner,
    String repo, {
    String sort = 'name',
    String direction = 'asc',
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/tags',
      query: {
        'sort': sort,
        'direction': direction,
        ..._paging(page, perPage),
      },
    );
    return _asList(data).map((e) => RepositoryTag.fromJson(_asMap(e))).toList();
  }

  static Future<Map<String, dynamic>> createTag({
    required String owner,
    required String repo,
    required String tagName,
    String refs = 'master',
    String? tagMessage,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/tags',
      body: {
        'refs': refs,
        'tag_name': tagName,
        if (tagMessage != null && tagMessage.isNotEmpty)
          'tag_message': tagMessage,
      },
      formEncoded: true,
    );
    return _asMap(data);
  }

  static Future<CompareResult> compareBranches(
    String owner,
    String repo,
    String base,
    String head, {
    bool? straight,
    String? suffix,
  }) async {
    final query = <String, String>{};
    if (straight != null) query['straight'] = straight.toString();
    if (suffix != null && suffix.isNotEmpty) query['suffix'] = suffix;
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/compare/${_enc(base)}...${_enc(head)}',
      query: query.isEmpty ? null : query,
    );
    return CompareResult.fromJson(_asMap(data));
  }

  static Future<List<Repo>> getForks(
    String owner,
    String repo, {
    String sort = 'newest',
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/forks',
      query: {'sort': sort, ..._paging(page, perPage)},
    );
    return _asList(data).map((e) => Repo.fromJson(_asMap(e))).toList();
  }

  static Future<Map<String, dynamic>> forkRepo({
    required String owner,
    required String repo,
    String? organization,
    String? name,
    String? path,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/forks',
      body: {
        if (organization != null && organization.isNotEmpty)
          'organization': organization,
        if (name != null && name.isNotEmpty) 'name': name,
        if (path != null && path.isNotEmpty) 'path': path,
      },
      formEncoded: true,
    );
    return _asMap(data);
  }

  static Future<List<Webhook>> getWebhooks(
    String owner,
    String repo, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/hooks',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => Webhook.fromJson(_asMap(e))).toList();
  }

  static Future<Map<String, dynamic>> createWebhook({
    required String owner,
    required String repo,
    required String url,
    String? title,
    int? encryptionType,
    String? password,
    bool pushEvents = true,
    bool? tagPushEvents,
    bool? issuesEvents,
    bool? noteEvents,
    bool? mergeRequestsEvents,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/hooks',
      body: {
        'url': url,
        if (title != null && title.isNotEmpty) 'title': title,
        if (encryptionType != null) 'encryption_type': encryptionType,
        if (password != null && password.isNotEmpty) 'password': password,
        'push_events': pushEvents,
        if (tagPushEvents != null) 'tag_push_events': tagPushEvents,
        if (issuesEvents != null) 'issues_events': issuesEvents,
        if (noteEvents != null) 'note_events': noteEvents,
        if (mergeRequestsEvents != null)
          'merge_requests_events': mergeRequestsEvents,
      },
      formEncoded: true,
    );
    return _asMap(data);
  }

  static Future<Map<String, dynamic>> getWebhook(
    String owner,
    String repo,
    int id,
  ) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/hooks/$id',
    );
    return _asMap(data);
  }

  static Future<Map<String, dynamic>> updateWebhook({
    required String owner,
    required String repo,
    required int id,
    required String url,
    String? title,
    int? encryptionType,
    String? password,
    bool pushEvents = true,
    bool? tagPushEvents,
    bool? issuesEvents,
    bool? noteEvents,
    bool? mergeRequestsEvents,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'PATCH',
      '/repos/${_enc(owner)}/${_enc(repo)}/hooks/$id',
      body: {
        'url': url,
        if (title != null && title.isNotEmpty) 'title': title,
        if (encryptionType != null) 'encryption_type': encryptionType,
        if (password != null && password.isNotEmpty) 'password': password,
        'push_events': pushEvents,
        if (tagPushEvents != null) 'tag_push_events': tagPushEvents,
        if (issuesEvents != null) 'issues_events': issuesEvents,
        if (noteEvents != null) 'note_events': noteEvents,
        if (mergeRequestsEvents != null)
          'merge_requests_events': mergeRequestsEvents,
      },
      formEncoded: true,
    );
    return _asMap(data);
  }

  static Future<void> deleteWebhook(
    String owner,
    String repo,
    int id,
  ) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request('DELETE', '/repos/${_enc(owner)}/${_enc(repo)}/hooks/$id');
  }

  static Future<void> testWebhook(
    String owner,
    String repo,
    int id,
  ) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/hooks/$id/tests',
    );
  }

  static Future<List<User>> getCollaborators(
    String owner,
    String repo, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/collaborators',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => User.fromJson(_asMap(e))).toList();
  }

  static Future<bool> checkCollaborator(
    String owner,
    String repo,
    String username,
  ) async {
    if (GiteeApi.token == null) return false;
    try {
      await _request(
        'GET',
        '/repos/${_enc(owner)}/${_enc(repo)}/collaborators/${_enc(username)}',
      );
      return true;
    } on GiteeApiException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  static Future<void> addCollaborator({
    required String owner,
    required String repo,
    required String username,
    String permission = 'push',
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'PUT',
      '/repos/${_enc(owner)}/${_enc(repo)}/collaborators/${_enc(username)}',
      body: {'permission': permission},
      formEncoded: true,
    );
  }

  static Future<void> removeCollaborator(
    String owner,
    String repo,
    String username,
  ) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'DELETE',
      '/repos/${_enc(owner)}/${_enc(repo)}/collaborators/${_enc(username)}',
    );
  }

  static Future<Map<String, dynamic>> getCollaboratorPermission(
    String owner,
    String repo,
    String username,
  ) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/collaborators/${_enc(username)}/permission',
    );
    return _asMap(data);
  }

  static Future<List<Contributor>> getContributors(
    String owner,
    String repo, {
    String type = 'committers',
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/contributors',
      query: {'type': type},
    );
    return _asList(data).map((e) => Contributor.fromJson(_asMap(e))).toList();
  }

  static Future<Map<String, dynamic>> getLanguages(
      String owner, String repo) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/languages',
    );
    return _asMap(data);
  }

  static Future<Map<String, dynamic>> getRepoLicense(
    String owner,
    String repo,
  ) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/license',
    );
    return _asMap(data);
  }

  // ---------- Star ----------

  static Future<bool> checkStarred(String owner, String repo) async {
    if (GiteeApi.token == null) return false;
    try {
      await _request(
        'GET',
        '/user/starred/${_enc(owner)}/${_enc(repo)}',
      );
      return true;
    } on GiteeApiException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  static Future<bool> starRepo(String owner, String repo) async {
    if (GiteeApi.token == null) return false;
    try {
      await _request('PUT', '/user/starred/${_enc(owner)}/${_enc(repo)}');
      return true;
    } on GiteeApiException catch (e) {
      // 已 Star 的仓库再次 Star 时官方返回 404，业务上按成功处理。
      if (e.statusCode == 404) return true;
      rethrow;
    }
  }

  static Future<bool> unstarRepo(String owner, String repo) async {
    if (GiteeApi.token == null) return false;
    try {
      await _request('DELETE', '/user/starred/${_enc(owner)}/${_enc(repo)}');
      return true;
    } on GiteeApiException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  /// 当前用户 Star 的仓库列表。
  static Future<List<Repo>> getStarredRepos({
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/user/starred',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => Repo.fromJson(_asMap(e))).toList();
  }

  // ---------- 关注 / 粉丝 ----------

  static Future<List<User>> getFollowing({
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/user/following',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => User.fromJson(_asMap(e))).toList();
  }

  static Future<List<User>> getFollowers({
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/user/followers',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => User.fromJson(_asMap(e))).toList();
  }

  static Future<bool> checkFollowing(String username) async {
    if (GiteeApi.token == null) return false;
    try {
      await _request('GET', '/user/following/${_enc(username)}');
      return true;
    } on GiteeApiException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  static Future<void> followUser(String username) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request('PUT', '/user/following/${_enc(username)}');
  }

  static Future<void> unfollowUser(String username) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request('DELETE', '/user/following/${_enc(username)}');
  }

  // ---------- Issue ----------

  static Future<List<Issue>> getIssues(
    String owner,
    String repo, {
    String state = 'all',
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/issues',
      query: {..._paging(page, perPage), 'state': state},
    );
    return _asList(data).map((e) => Issue.fromJson(_asMap(e))).toList();
  }

  static Future<Issue> getIssueDetail(
    String owner,
    String repo,
    String number,
  ) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/issues/$number',
    );
    return Issue.fromJson(_asMap(data));
  }

  static Future<List<IssueComment>> getIssueComments(
    String owner,
    String repo,
    String number, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/issues/$number/comments',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => IssueComment.fromJson(_asMap(e))).toList();
  }

  static Future<IssueComment> createIssueComment({
    required String owner,
    required String repo,
    required String number,
    required String body,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/issues/$number/comments',
      body: {'body': body},
      formEncoded: true,
    );
    return IssueComment.fromJson(_asMap(data));
  }

  static Future<IssueComment> updateIssueComment({
    required String owner,
    required String repo,
    required int commentId,
    required String body,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'PATCH',
      '/repos/${_enc(owner)}/${_enc(repo)}/issues/comments/$commentId',
      body: {'body': body},
      formEncoded: true,
    );
    return IssueComment.fromJson(_asMap(data));
  }

  static Future<void> deleteIssueComment({
    required String owner,
    required String repo,
    required int commentId,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'DELETE',
      '/repos/${_enc(owner)}/${_enc(repo)}/issues/comments/$commentId',
    );
  }

  static Future<Issue> updateIssue({
    required String owner,
    required String repo,
    required String number,
    String? title,
    String? body,
    String? state,
    String? assignee,
    String? labels,
    int? milestone,
    String? collaborators,
    bool? securityHole,
    String? branch,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final payload = <String, dynamic>{
      'repo': repo,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (state != null) 'state': state,
      if (assignee != null) 'assignee': assignee,
      if (collaborators != null) 'collaborators': collaborators,
      if (labels != null) 'labels': labels,
      if (milestone != null) 'milestone': milestone,
      if (securityHole != null) 'security_hole': securityHole,
      if (branch != null) 'branch': branch,
    };
    final data = await _request(
      'PATCH',
      '/repos/${_enc(owner)}/issues/$number',
      body: payload,
      formEncoded: true,
    );
    return Issue.fromJson(_asMap(data));
  }

  // ---------- Commit ----------

  static Future<List<Commit>> getCommits(
    String owner,
    String repo, {
    String? branch,
    int page = 1,
    int perPage = 20,
  }) async {
    final query = <String, String>{..._paging(page, perPage)};
    if (branch != null && branch.isNotEmpty) query['sha'] = branch;
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/commits',
      query: query,
    );
    return _asList(data).map((e) => Commit.fromJson(_asMap(e))).toList();
  }

  static Future<Commit> getCommitDetail(
    String owner,
    String repo,
    String sha,
  ) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/commits/${_enc(sha)}',
    );
    return Commit.fromJson(_asMap(data));
  }

  // ---------- Pull Request ----------

  static Future<List<PullRequest>> getPullRequests(
    String owner,
    String repo, {
    String state = 'all',
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls',
      query: {..._paging(page, perPage), 'state': state},
    );
    return _asList(data).map((e) => PullRequest.fromJson(_asMap(e))).toList();
  }

  static Future<PullRequest> getPullRequestDetail(
    String owner,
    String repo,
    int number,
  ) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number',
    );
    return PullRequest.fromJson(_asMap(data));
  }

  static Future<List<Commit>> getPullRequestCommits(
    String owner,
    String repo,
    int number, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/commits',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => Commit.fromJson(_asMap(e))).toList();
  }

  static Future<List<PullRequestComment>> getPullRequestComments(
    String owner,
    String repo,
    int number, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/comments',
      query: _paging(page, perPage),
    );
    return _asList(data)
        .map((e) => PullRequestComment.fromJson(_asMap(e)))
        .toList();
  }

  static Future<PullRequestComment> createPullRequestComment({
    required String owner,
    required String repo,
    required int number,
    required String body,
    String? commitId,
    String? path,
    String? position,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final payload = <String, dynamic>{
      'body': body,
      if (commitId != null && commitId.isNotEmpty) 'commit_id': commitId,
      if (path != null && path.isNotEmpty) 'path': path,
      if (position != null) 'position': position,
    };
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/comments',
      body: payload,
      formEncoded: true,
    );
    return PullRequestComment.fromJson(_asMap(data));
  }

  static Future<PullRequestComment> updatePullRequestComment({
    required String owner,
    required String repo,
    required int commentId,
    required String body,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'PATCH',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/comments/$commentId',
      body: {'body': body},
      formEncoded: true,
    );
    return PullRequestComment.fromJson(_asMap(data));
  }

  static Future<void> deletePullRequestComment({
    required String owner,
    required String repo,
    required int commentId,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'DELETE',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/comments/$commentId',
    );
  }

  static Future<Map<String, dynamic>> processPullRequestReview({
    required String owner,
    required String repo,
    required int number,
    bool? force,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/review',
      body: {if (force != null) 'force': force},
      formEncoded: true,
    );
    return data is Map ? _asMap(data) : <String, dynamic>{};
  }

  static Future<List<dynamic>> getPullRequestOperateLogs(
    String owner,
    String repo,
    int number, {
    String sort = 'desc',
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/operate_logs',
      query: {'sort': sort},
    );
    return _asList(data);
  }

  static Future<void> assignPullRequestReviewers({
    required String owner,
    required String repo,
    required int number,
    required String assignees,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/assignees',
      body: {'assignees': assignees},
      formEncoded: true,
    );
  }

  static Future<void> removePullRequestReviewers({
    required String owner,
    required String repo,
    required int number,
    required String assignees,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'DELETE',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/assignees',
      query: {'assignees': assignees},
    );
  }

  static Future<void> resetPullRequestReviewers({
    required String owner,
    required String repo,
    required int number,
    bool resetAll = false,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'PATCH',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/assignees',
      body: {'reset_all': resetAll},
      formEncoded: true,
    );
  }

  static Future<void> assignPullRequestTesters({
    required String owner,
    required String repo,
    required int number,
    required String testers,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/testers',
      body: {'testers': testers},
      formEncoded: true,
    );
  }

  static Future<void> removePullRequestTesters({
    required String owner,
    required String repo,
    required int number,
    required String testers,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'DELETE',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/testers',
      query: {'testers': testers},
    );
  }

  static Future<void> resetPullRequestTesters({
    required String owner,
    required String repo,
    required int number,
    bool resetAll = false,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'PATCH',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/testers',
      body: {'reset_all': resetAll},
      formEncoded: true,
    );
  }

  static Future<Map<String, dynamic>> testPullRequest({
    required String owner,
    required String repo,
    required int number,
    bool? force,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/test',
      body: {if (force != null) 'force': force},
      formEncoded: true,
    );
    return data is Map ? _asMap(data) : <String, dynamic>{};
  }

  static Future<PullRequest> updatePullRequest({
    required String owner,
    required String repo,
    required int number,
    String? title,
    String? body,
    String? state,
    bool? draft,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (state != null) 'state': state,
      if (draft != null) 'draft': draft,
    };
    final data = await _request(
      'PATCH',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number',
      body: payload,
      formEncoded: true,
    );
    return PullRequest.fromJson(_asMap(data));
  }

  static Future<PullRequest> closePullRequest(
    String owner,
    String repo,
    int number,
  ) =>
      updatePullRequest(
          owner: owner, repo: repo, number: number, state: 'closed');

  static Future<PullRequest> reopenPullRequest(
    String owner,
    String repo,
    int number,
  ) =>
      updatePullRequest(
          owner: owner, repo: repo, number: number, state: 'open');

  static Future<Map<String, dynamic>> mergePullRequest({
    required String owner,
    required String repo,
    required int number,
    String? mergeMethod,
    String? title,
    String? description,
    bool? pruneSourceBranch,
    bool? closeRelatedIssue,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'PUT',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/merge',
      body: {
        if (mergeMethod != null) 'merge_method': mergeMethod,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (pruneSourceBranch != null) 'prune_source_branch': pruneSourceBranch,
        if (closeRelatedIssue != null) 'close_related_issue': closeRelatedIssue,
      },
      formEncoded: true,
    );
    return data is Map ? _asMap(data) : <String, dynamic>{};
  }

  static Future<List<PullRequestFile>> getPullRequestFiles(
    String owner,
    String repo,
    int number, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls/$number/files',
      query: _paging(page, perPage),
    );
    return _asList(data)
        .map((e) => PullRequestFile.fromJson(_asMap(e)))
        .toList();
  }

  // ---------- Release ----------

  // ---------- 仓库动态 ----------

  static Future<List<Event>> getRepoEvents(
    String owner,
    String repo, {
    String? prevId,
    int limit = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/events',
      query: {
        'limit': limit.toString(),
        if (prevId != null && prevId.isNotEmpty) 'prev_id': prevId,
      },
    );
    return _asList(data).map((e) => Event.fromJson(_asMap(e))).toList();
  }

  // ---------- 版本发布 ----------

  static Future<List<Release>> getReleases(
    String owner,
    String repo, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/releases',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => Release.fromJson(_asMap(e))).toList();
  }

  static Future<Release> getReleaseById(
    String owner,
    String repo,
    int id,
  ) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/releases/$id',
    );
    return Release.fromJson(_asMap(data));
  }

  static Future<Release> getLatestRelease(String owner, String repo) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/releases/latest',
    );
    return Release.fromJson(_asMap(data));
  }

  static Future<Release> getReleaseByTag(
    String owner,
    String repo,
    String tag,
  ) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/releases/tags/${_enc(tag)}',
    );
    return Release.fromJson(_asMap(data));
  }

  static Future<Release> createRelease({
    required String owner,
    required String repo,
    required String tagName,
    required String name,
    required String body,
    required String targetCommitish,
    bool? prerelease,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/releases',
      body: {
        'tag_name': tagName,
        'name': name,
        'body': body,
        'target_commitish': targetCommitish,
        if (prerelease != null) 'prerelease': prerelease,
      },
      formEncoded: true,
    );
    return Release.fromJson(_asMap(data));
  }

  static Future<Release> updateRelease({
    required String owner,
    required String repo,
    required int id,
    required String tagName,
    required String name,
    required String body,
    bool? prerelease,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'PATCH',
      '/repos/${_enc(owner)}/${_enc(repo)}/releases/$id',
      body: {
        'tag_name': tagName,
        'name': name,
        'body': body,
        if (prerelease != null) 'prerelease': prerelease,
      },
      formEncoded: true,
    );
    return Release.fromJson(_asMap(data));
  }

  static Future<void> deleteRelease(
    String owner,
    String repo,
    int id,
  ) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
        'DELETE', '/repos/${_enc(owner)}/${_enc(repo)}/releases/$id');
  }

  // ---------- 订阅 / Watch ----------

  static Future<bool> checkSubscribed(String owner, String repo) async {
    if (GiteeApi.token == null) return false;
    try {
      await _request(
        'GET',
        '/user/subscriptions/${_enc(owner)}/${_enc(repo)}',
      );
      return true;
    } on GiteeApiException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  static Future<bool> subscribeRepo(
    String owner,
    String repo, {
    String watchType = 'watching',
  }) async {
    if (GiteeApi.token == null) return false;
    try {
      await _request(
        'PUT',
        '/user/subscriptions/${_enc(owner)}/${_enc(repo)}',
        body: {'watch_type': watchType},
        formEncoded: true,
      );
      return true;
    } on GiteeApiException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  static Future<bool> unsubscribeRepo(String owner, String repo) async {
    if (GiteeApi.token == null) return false;
    try {
      await _request(
        'DELETE',
        '/user/subscriptions/${_enc(owner)}/${_enc(repo)}',
      );
      return true;
    } on GiteeApiException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  // ---------- Issue / PR 创建 ----------

  static Future<Map<String, dynamic>> createIssue({
    required String owner,
    required String repo,
    required String title,
    String? description,
    String? assignee,
    String? collaborators,
    int? milestone,
    String? labels,
    String? issueType,
    bool? securityHole,
    String? branch,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final body = <String, dynamic>{
      'repo': repo,
      'title': title,
      if (description != null && description.isNotEmpty) 'body': description,
      if (assignee != null && assignee.isNotEmpty) 'assignee': assignee,
      if (collaborators != null && collaborators.isNotEmpty)
        'collaborators': collaborators,
      if (milestone != null) 'milestone': milestone,
      if (labels != null && labels.isNotEmpty) 'labels': labels,
      if (issueType != null && issueType.isNotEmpty) 'issue_type': issueType,
      if (securityHole != null) 'security_hole': securityHole,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
    };
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/issues',
      body: body,
      formEncoded: true,
    );
    return _asMap(data);
  }

  static Future<Map<String, dynamic>> createPullRequest({
    required String owner,
    required String repo,
    required String title,
    required String head,
    required String base,
    String? description,
    int? milestoneNumber,
    String? labels,
    String? assignees,
    String? testers,
    int? assigneesNumber,
    int? testersNumber,
    String? refPullRequestNumbers,
    bool? pruneSourceBranch,
    bool? closeRelatedIssue,
    bool? draft,
    bool? squash,
    bool? securityHole,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final body = <String, dynamic>{
      'title': title,
      'head': head,
      'base': base,
      if (description != null && description.isNotEmpty) 'body': description,
      if (milestoneNumber != null) 'milestone_number': milestoneNumber,
      if (labels != null && labels.isNotEmpty) 'labels': labels,
      if (assignees != null && assignees.isNotEmpty) 'assignees': assignees,
      if (testers != null && testers.isNotEmpty) 'testers': testers,
      if (assigneesNumber != null) 'assignees_number': assigneesNumber,
      if (testersNumber != null) 'testers_number': testersNumber,
      if (refPullRequestNumbers != null && refPullRequestNumbers.isNotEmpty)
        'ref_pull_request_numbers': refPullRequestNumbers,
      if (pruneSourceBranch != null) 'prune_source_branch': pruneSourceBranch,
      if (closeRelatedIssue != null) 'close_related_issue': closeRelatedIssue,
      if (draft != null) 'draft': draft,
      if (squash != null) 'squash': squash,
      if (securityHole != null) 'security_hole': securityHole,
    };
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/pulls',
      body: body,
      formEncoded: true,
    );
    return _asMap(data);
  }

  // ---------- 通知 ----------

  static Future<List<AppNotification>> getNotifications({
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/notifications/threads',
      query: _paging(page, perPage),
    );
    return _asList(data)
        .map((e) => AppNotification.fromJson(_asMap(e)))
        .toList();
  }

  static DateTime? _notifCountAt;
  static int _notifCountCache = 0;

  // ponytail: 30s 内存缓存，去重首页与通知页并发请求；需要实时刷新时去掉缓存即可。
  static Future<int> getNotificationCount({bool unread = true}) async {
    final now = DateTime.now();
    if (_notifCountAt != null &&
        now.difference(_notifCountAt!) < const Duration(seconds: 30)) {
      return _notifCountCache;
    }
    final data = await _request(
      'GET',
      '/notifications/count',
      query: {'unread': unread.toString()},
    );
    final map = _asMap(data);
    final value = map['notification_count'] ??
        map['total_count'] ??
        map['unread'] ??
        map['count'] ??
        map['total'] ??
        0;
    final count =
        value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0;
    _notifCountAt = now;
    _notifCountCache = count;
    return count;
  }

  static Future<List<Issue>> getUserIssues({
    String filter = 'assigned',
    String? state,
    int page = 1,
    int perPage = 20,
  }) async {
    final query = <String, String>{
      ..._paging(page, perPage),
      'filter': filter,
    };
    if (state != null && state.trim().isNotEmpty) {
      query['state'] = state.trim();
    }
    final data = await _request('GET', '/user/issues', query: query);
    return _asList(data).map((e) => Issue.fromJson(_asMap(e))).toList();
  }

  static Future<List<Repo>> getSubscriptions({
    int page = 1,
    int perPage = 20,
    String sort = 'updated',
    String direction = 'desc',
  }) async {
    final data = await _request(
      'GET',
      '/user/subscriptions',
      query: {
        ..._paging(page, perPage),
        'sort': sort,
        'direction': direction,
      },
    );
    return _asList(data).map((e) => Repo.fromJson(_asMap(e))).toList();
  }

  static Future<void> markNotificationRead(String id) async {
    await _request('PATCH', '/notifications/threads/${_enc(id)}');
  }

  static Future<void> markAllNotificationsRead() async {
    await _request('PUT', '/notifications/threads');
  }

  // ---------- 用户动态 ----------

  static Future<List<Event>> getUserEvents(
    String username, {
    String? prevId,
    int limit = 20,
  }) async {
    final data = await _request(
      'GET',
      '/users/${_enc(username)}/events/public',
      query: {
        'limit': limit.toString(),
        if (prevId != null && prevId.isNotEmpty) 'prev_id': prevId,
      },
    );
    return _asList(data).map((e) => Event.fromJson(_asMap(e))).toList();
  }

  static Future<List<Organization>> getCurrentUserOrgs({
    int page = 1,
    int perPage = 20,
    bool? admin,
  }) async {
    final query = <String, String>{..._paging(page, perPage)};
    if (admin != null) query['admin'] = admin.toString();
    final data = await _request('GET', '/user/orgs', query: query);
    return _asList(data).map((e) => Organization.fromJson(_asMap(e))).toList();
  }

  static Future<List<Organization>> getUserOrgs(
    String username, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/users/${_enc(username)}/orgs',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => Organization.fromJson(_asMap(e))).toList();
  }

  static Future<Organization> getOrgDetail(String org) async {
    final data = await _request('GET', '/orgs/${_enc(org)}');
    return Organization.fromJson(_asMap(data));
  }

  static Future<Map<String, dynamic>> updateOrg({
    required String org,
    String? email,
    String? location,
    String? name,
    String? description,
    String? htmlUrl,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'PATCH',
      '/orgs/${_enc(org)}',
      body: {
        if (email != null) 'email': email,
        if (location != null) 'location': location,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (htmlUrl != null) 'html_url': htmlUrl,
      },
      formEncoded: true,
    );
    return _asMap(data);
  }

  static Future<List<User>> getOrgMembers(
    String org, {
    int page = 1,
    int perPage = 20,
    String role = 'all',
  }) async {
    final data = await _request(
      'GET',
      '/orgs/${_enc(org)}/members',
      query: {..._paging(page, perPage), 'role': role},
    );
    return _asList(data).map((e) => User.fromJson(_asMap(e))).toList();
  }

  static Future<bool> checkOrgMember(String org, String username) async {
    if (GiteeApi.token == null) return false;
    try {
      await _request('GET', '/orgs/${_enc(org)}/memberships/${_enc(username)}');
      return true;
    } on GiteeApiException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  static Future<void> addOrgMember({
    required String org,
    required String username,
    String role = 'member',
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'PUT',
      '/orgs/${_enc(org)}/memberships/${_enc(username)}',
      body: {'role': role},
      formEncoded: true,
    );
  }

  static Future<void> removeOrgMember(String org, String username) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'DELETE',
      '/orgs/${_enc(org)}/memberships/${_enc(username)}',
    );
  }

  static Future<List<Repo>> getOrgRepos(
    String org, {
    String type = 'all',
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/orgs/${_enc(org)}/repos',
      query: {'type': type, ..._paging(page, perPage)},
    );
    return _asList(data).map((e) => Repo.fromJson(_asMap(e))).toList();
  }

  static Future<Map<String, dynamic>> createOrgRepo({
    required String org,
    required String name,
    String? description,
    String? homepage,
    bool? hasIssues,
    bool? hasWiki,
    bool? canComment,
    bool? public,
    bool? private,
    bool? autoInit,
    String? gitignoreTemplate,
    String? licenseTemplate,
    String? path,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/orgs/${_enc(org)}/repos',
      body: {
        'name': name,
        if (description != null) 'description': description,
        if (homepage != null) 'homepage': homepage,
        if (hasIssues != null) 'has_issues': hasIssues,
        if (hasWiki != null) 'has_wiki': hasWiki,
        if (canComment != null) 'can_comment': canComment,
        if (public != null) 'public': public ? 1 : 0,
        if (private != null) 'private': private,
        if (autoInit != null) 'auto_init': autoInit,
        if (gitignoreTemplate != null) 'gitignore_template': gitignoreTemplate,
        if (licenseTemplate != null) 'license_template': licenseTemplate,
        if (path != null) 'path': path,
      },
      formEncoded: true,
    );
    return _asMap(data);
  }

  static Future<Map<String, dynamic>> createUserRepo({
    required String name,
    String? description,
    String? homepage,
    bool? hasIssues,
    bool? hasWiki,
    bool? canComment,
    bool? autoInit,
    String? gitignoreTemplate,
    String? licenseTemplate,
    String? path,
    String? namespace,
    bool? public,
    bool? private,
    bool? outsourced,
    String? projectCreator,
    String? members,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/user/repos',
      body: {
        'name': name,
        if (description != null) 'description': description,
        if (homepage != null) 'homepage': homepage,
        if (hasIssues != null) 'has_issues': hasIssues,
        if (hasWiki != null) 'has_wiki': hasWiki,
        if (canComment != null) 'can_comment': canComment,
        if (autoInit != null) 'auto_init': autoInit,
        if (gitignoreTemplate != null) 'gitignore_template': gitignoreTemplate,
        if (licenseTemplate != null) 'license_template': licenseTemplate,
        if (path != null) 'path': path,
        if (namespace != null) 'namespace': namespace,
        if (public != null) 'public': public ? 1 : 0,
        if (private != null) 'private': private,
        if (outsourced != null) 'outsourced': outsourced,
        if (projectCreator != null) 'project_creator': projectCreator,
        if (members != null) 'members': members,
      },
      formEncoded: true,
    );
    return _asMap(data);
  }

  static Future<List<Event>> getUserAllEvents(
    String username, {
    String? prevId,
    int limit = 20,
  }) async {
    final data = await _request(
      'GET',
      '/users/${_enc(username)}/events',
      query: {
        'limit': limit.toString(),
        if (prevId != null && prevId.isNotEmpty) 'prev_id': prevId,
      },
    );
    return _asList(data).map((e) => Event.fromJson(_asMap(e))).toList();
  }

  static Future<List<Event>> getUserReceivedEvents(
    String username, {
    bool publicOnly = false,
    String? prevId,
    int limit = 20,
  }) async {
    final suffix = publicOnly ? 'public' : '';
    final data = await _request(
      'GET',
      '/users/${_enc(username)}/received_events${suffix.isEmpty ? '' : '/$suffix'}',
      query: {
        'limit': limit.toString(),
        if (prevId != null && prevId.isNotEmpty) 'prev_id': prevId,
      },
    );
    return _asList(data).map((e) => Event.fromJson(_asMap(e))).toList();
  }

  // ---------- 仓库关注者 ----------

  /// 仓库关注者（Watchers）列表。
  static Future<List<User>> getRepoSubscribers(
    String owner,
    String repo, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/subscribers',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => User.fromJson(_asMap(e))).toList();
  }

  // ---------- 用户社交 ----------

  /// 任意用户的关注列表。
  static Future<List<User>> getUserFollowing(
    String username, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/users/${_enc(username)}/following',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => User.fromJson(_asMap(e))).toList();
  }

  /// 任意用户的粉丝列表。
  static Future<List<User>> getUserFollowers(
    String username, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/users/${_enc(username)}/followers',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => User.fromJson(_asMap(e))).toList();
  }

  // ---------- 仓库标签 ----------

  static Future<List<Label>> getRepoLabels(
    String owner,
    String repo, {
    int page = 1,
    int perPage = 100,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/labels',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => Label.fromJson(_asMap(e))).toList();
  }

  static Future<Label> createRepoLabel({
    required String owner,
    required String repo,
    required String name,
    required String color,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/labels',
      body: {'name': name, 'color': color},
    );
    return Label.fromJson(_asMap(data));
  }

  static Future<void> deleteRepoLabel(
    String owner,
    String repo,
    int id,
  ) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request('DELETE', '/repos/${_enc(owner)}/${_enc(repo)}/labels/$id');
  }

  static Future<List<Label>> getIssueLabels(
    String owner,
    String repo,
    String number,
  ) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/issues/$number/labels',
    );
    return _asList(data).map((e) => Label.fromJson(_asMap(e))).toList();
  }

  /// 全量替换 Issue 的标签（传名称列表）。
  static Future<void> setIssueLabels({
    required String owner,
    required String repo,
    required String number,
    required List<String> labels,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'PUT',
      '/repos/${_enc(owner)}/${_enc(repo)}/issues/$number/labels',
      body: {'labels': labels},
    );
  }

  // ---------- 里程碑 ----------

  static Future<List<Milestone>> getMilestones(
    String owner,
    String repo, {
    String state = 'open',
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/milestones',
      query: {'state': state, ..._paging(page, perPage)},
    );
    return _asList(data).map((e) => Milestone.fromJson(_asMap(e))).toList();
  }

  static Future<Milestone> createMilestone({
    required String owner,
    required String repo,
    required String title,
    String? description,
    String? dueOn,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/milestones',
      body: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (dueOn != null && dueOn.isNotEmpty) 'due_on': dueOn,
      },
    );
    return Milestone.fromJson(_asMap(data));
  }

  static Future<Milestone> updateMilestone({
    required String owner,
    required String repo,
    required int id,
    String? title,
    String? state,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'PUT',
      '/repos/${_enc(owner)}/${_enc(repo)}/milestones/$id',
      body: {
        if (title != null) 'title': title,
        if (state != null) 'state': state,
      },
    );
    return Milestone.fromJson(_asMap(data));
  }

  static Future<void> deleteMilestone(
    String owner,
    String repo,
    int id,
  ) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request('DELETE', '/repos/${_enc(owner)}/${_enc(repo)}/milestones/$id');
  }

  // ---------- 部署公钥 ----------

  static Future<List<DeployKey>> getDeployKeys(
    String owner,
    String repo, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/keys',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => DeployKey.fromJson(_asMap(e))).toList();
  }

  static Future<DeployKey> createDeployKey({
    required String owner,
    required String repo,
    required String key,
    required String title,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/keys',
      body: {'key': key, 'title': title},
    );
    return DeployKey.fromJson(_asMap(data));
  }

  static Future<void> deleteDeployKey(
    String owner,
    String repo,
    int id,
  ) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request('DELETE', '/repos/${_enc(owner)}/${_enc(repo)}/keys/$id');
  }

  // ---------- SSH 公钥 ----------

  static Future<List<PublicKey>> getPublicKeys({int page = 1}) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'GET',
      '/user/keys',
      query: _paging(page, 20),
    );
    return _asList(data).map((e) => PublicKey.fromJson(_asMap(e))).toList();
  }

  static Future<PublicKey> createPublicKey({
    required String key,
    required String title,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/user/keys',
      body: {'key': key, 'title': title},
    );
    return PublicKey.fromJson(_asMap(data));
  }

  static Future<void> deletePublicKey(int id) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request('DELETE', '/user/keys/$id');
  }

  // ---------- Gist 代码片段 ----------

  /// 当前用户的代码片段。
  static Future<List<Gist>> getGists({int page = 1, int perPage = 20}) async {
    final data = await _request(
      'GET',
      '/gists',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => Gist.fromJson(_asMap(e))).toList();
  }

  static Future<Gist> getGistDetail(String id) async {
    final data = await _request('GET', '/gists/${_enc(id)}');
    return Gist.fromJson(_asMap(data));
  }

  static Future<Gist> createGist({
    required Map<String, String> files,
    String? description,
    bool isPublic = true,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/gists',
      body: {
        'files': {
          for (final e in files.entries)
            e.key: {'content': e.value},
        },
        if (description != null && description.isNotEmpty)
          'description': description,
        'public': isPublic,
      },
    );
    return Gist.fromJson(_asMap(data));
  }

  /// 编辑描述或新增/修改/删除文件（内容传 null 表示删除该文件）。
  static Future<Gist> updateGist(
    String id, {
    String? description,
    Map<String, String?>? files,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'PUT',
      '/gists/${_enc(id)}',
      body: {
        if (description != null) 'description': description,
        if (files != null)
          'files': {
            for (final e in files.entries)
              e.key: {
                if (e.value != null) 'content': e.value,
              },
          },
      },
    );
    return Gist.fromJson(_asMap(data));
  }

  static Future<void> deleteGist(String id) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request('DELETE', '/gists/${_enc(id)}');
  }

  static Future<void> starGist(String id) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request('PUT', '/gists/${_enc(id)}/star');
  }

  static Future<void> unstarGist(String id) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request('DELETE', '/gists/${_enc(id)}/star');
  }

  // ---------- 提交评论 ----------

  static Future<List<IssueComment>> getCommitComments(
    String owner,
    String repo,
    String sha, {
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      'GET',
      '/repos/${_enc(owner)}/${_enc(repo)}/commits/${_enc(sha)}/comments',
      query: _paging(page, perPage),
    );
    return _asList(data).map((e) => IssueComment.fromJson(_asMap(e))).toList();
  }

  static Future<IssueComment> createCommitComment({
    required String owner,
    required String repo,
    required String sha,
    required String body,
  }) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    final data = await _request(
      'POST',
      '/repos/${_enc(owner)}/${_enc(repo)}/commits/${_enc(sha)}/comments',
      body: {'body': body},
    );
    return IssueComment.fromJson(_asMap(data));
  }

  static Future<void> deleteCommitComment(
    String owner,
    String repo,
    int id,
  ) async {
    if (GiteeApi.token == null) throw GiteeApiException('请先登录');
    await _request(
      'DELETE',
      '/repos/${_enc(owner)}/${_enc(repo)}/comments/$id',
    );
  }
}
