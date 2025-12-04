import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Import Custom Domain Files
import '../domain/member_models.dart';
import '../member_manager.dart';
import '../repository/member_repository.dart';
import '../presentation/widgets/filter_dialog_ui.dart';

/// [MemberListScreenArgs]
/// 화면 진입 시 전달받아야 할 인자들.
class MemberListScreenArgs {
  final String projectId;
  // 필요 시 추가 필드 확장 가능

  MemberListScreenArgs({required this.projectId});

  // GoRouter 등에서 에러 발생 시 처리용 팩토리
  factory MemberListScreenArgs.error() {
    return MemberListScreenArgs(projectId: '');
  }
}

/// [MemberListScreen]
/// Member Management 의 Entry Point.
/// 외부 주입 없이 내부에서 Repository 와 Manager 를 생성하여 운용함 (Composition Root).
class MemberListScreen extends StatefulWidget {
  final MemberListScreenArgs args;

  const MemberListScreen(this.args);

  /// GoRouter Redirect Logic Helper (Router 파일에서 호출)
  // lib/member/screens/member_list_screen.dart

  static MemberListScreenArgs argProc(GoRouterState state) {
    // [수정 전] pathParameters 는 주소에 /:projectId 가 있을 때만 작동함
    // final projectId = state.pathParameters['projectId'];

    // [수정 후] pushWithParams 로 넘긴 값은 주로 queryParameters 에 들어옴
    // 만약 LauCmn.pushWithParams 가 'extra' 객체로 넘긴다면 state.extra 로 받아야 함.
    // 우선 일반적인 queryParameters 로 시도:
    var projectId = state.uri.queryParameters['projectId'];

    // [보완] 만약 query에 없다면 extra에서도 찾아봄 (방어 코드)
    if (projectId == null && state.extra != null && state.extra is Map) {
      projectId = (state.extra as Map)['projectId']?.toString();
    }

    if (projectId == null || projectId.isEmpty) {
      return MemberListScreenArgs.error();
    }
    return MemberListScreenArgs(projectId: projectId);
  }

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen>
    with SingleTickerProviderStateMixin {

  // Dependencies (Created internally)
  late final MemberRepository _repository;
  late final MemberManager _memberManager;

  late TabController _tabController;

  final List<MemberStatus> _tabs = [
    MemberStatus.active,
    MemberStatus.invited,
    MemberStatus.restricted,
    MemberStatus.deactivated,
  ];

  @override
  void initState() {
    super.initState();
    _log('initState', 'Screen Initializing with ProjectID: ${widget.args.projectId}');

    if (widget.args.projectId.isEmpty) {
      _log('initState', 'Error: Invalid Project ID');
      return;
    }

    // 1. Dependency Construction (Self-managed)
    _repository = MemberRepository(
      firestore: FirebaseFirestore.instance,
      projectId: widget.args.projectId,
    );
    _memberManager = MemberManager(_repository);

    // 2. Tab Controller Setup
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabSelection);

    // 3. Initial Data Load
    _memberManager.initialize();
  }

  @override
  void dispose() {
    _log('dispose', 'Disposing Screen & Manager');
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _memberManager.dispose(); // Manager 정리 필수
    super.dispose();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      final selectedStatus = _tabs[_tabController.index];
      _memberManager.setTab(selectedStatus);
    }
  }

  void _log(String method, String message) {
    debugPrint('[UI][MemberListScreen][$method] $message');
  }

  Future<void> _showFilterDialog() async {
    final result = await showDialog<FilterCondition>(
      context: context,
      builder: (_) => const MemberFilterDialog(),
    );
    if (result != null) {
      _memberManager.addFilter(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 에러 상태 처리 (Project ID 누락 등)
    if (widget.args.projectId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Invalid Project ID provided.')),
      );
    }

    // Manager 상태 구독
    return AnimatedBuilder(
      animation: _memberManager,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Member Manager'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: _tabs.map((s) => Tab(text: s.name.toUpperCase())).toList(),
            ),
          ),
          body: Column(
            children: [
              _buildFilterBar(),
              const Divider(height: 1),
              Expanded(child: _buildMemberList()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    final filters = _memberManager.activeFilters;
    final bool hasFilters = _memberManager.isFilterActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 60,
      color: Colors.grey[100],
      child: Row(
        children: [
          TextButton.icon(
            onPressed: hasFilters ? _memberManager.clearFilters : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: hasFilters ? Colors.red : Colors.grey,
            ),
          ),
          const VerticalDivider(),
          IconButton(
            icon: const Icon(Icons.filter_list_alt),
            onPressed: _showFilterDialog,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = filters[index];
                return Chip(
                  label: Text('${filter.type}: ${filter.value}'),
                  onDeleted: () => _memberManager.removeFilter(index),
                  backgroundColor: Colors.blue[50],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList() {
    if (_memberManager.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final members = _memberManager.members;
    if (members.isEmpty) {
      return Center(
        child: Text(
          'No members found.\nFilters: ${_memberManager.activeFilters.length}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: member.profileImageUrls.isNotEmpty
                ? NetworkImage(member.profileImageUrls.first)
                : null,
            child: member.profileImageUrls.isEmpty
                ? Text(member.nickName.isEmpty ? '?' : member.nickName[0])
                : null,
          ),
          title: Text(member.nickName),
          subtitle: Text('${member.status.name} / Lv.${member.permissionLevel}'),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Action Sheet or Detail Dialog Logic Here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Clicked: ${member.memberId}')),
              );
            },
          ),
        );
      },
    );
  }
}