import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../widgets/issue_list_view.dart';
import 'issue_detail_page.dart';

class MyIssuesPage extends StatefulWidget {
  const MyIssuesPage({super.key});

  @override
  State<MyIssuesPage> createState() => _MyIssuesPageState();
}

class _MyIssuesPageState extends State<MyIssuesPage> {
  String _state = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的 Issue')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('全部')),
                ButtonSegment(value: 'open', label: Text('开启')),
                ButtonSegment(value: 'closed', label: Text('已关闭')),
                ButtonSegment(value: 'rejected', label: Text('已拒绝')),
              ],
              selected: {_state},
              onSelectionChanged: (v) => setState(() => _state = v.first),
            ),
          ),
          Expanded(
            child: IssueListView(
              key: ValueKey(_state),
              loadPage: (page) => GiteeApi.getUserIssues(
                filter: 'all',
                state: _state == 'all' ? null : _state,
                page: page,
                perPage: 20,
              ),
              onTap: (issue) {
                if (issue.repositoryOwner.isEmpty ||
                    issue.repositoryName.isEmpty) {
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IssueDetailPage(
                      owner: issue.repositoryOwner,
                      repo: issue.repositoryName,
                      number: issue.number,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
