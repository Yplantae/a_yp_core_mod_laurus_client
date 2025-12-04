import 'package:flutter/foundation.dart';
import 'domain/member_models.dart';
import 'repository/member_repository.dart';

/// [FilterCondition]
/// 사용자 정의 필터 조건을 담는 Value Object.
class FilterCondition {
  final String type; // e.g., 'nickname', 'level_min', 'level_max', 'group_id'
  final dynamic value;

  FilterCondition(this.type, this.value);
}

/// [MemberManager]
/// Member 도메인의 비즈니스 로직 및 상태 관리자.
/// 화면(Screen)에 종속된 생명주기를 가지며, Repository를 사용하여 데이터를 처리함.
class MemberManager extends ChangeNotifier {
  final MemberRepository _repository;

  // --- States ---
  MemberStatus _activeTab = MemberStatus.active; // 현재 선택된 탭
  List<MemberModel> _allMembersInTab = []; // 현재 탭의 원본 데이터 (Server Cache)
  List<MemberModel> _filteredMembers = []; // 필터가 적용된 최종 데이터 (View)
  final List<FilterCondition> _activeFilters = []; // 현재 적용된 필터 목록
  bool _isLoading = false;

  // --- Getters ---
  List<MemberModel> get members => _filteredMembers;
  MemberStatus get currentTab => _activeTab;
  bool get isLoading => _isLoading;
  bool get isFilterActive => _activeFilters.isNotEmpty;
  List<FilterCondition> get activeFilters => List.unmodifiable(_activeFilters);

  // --- Constructor ---
  MemberManager(this._repository);

  // --- Log Helper ---
  void _log(String method, String message) {
    debugPrint('[MemberManager][$method] $message');
  }

  /// [initialize]
  /// 초기 진입 시 기본 탭(Active) 데이터를 로드.
  Future<void> initialize() async {
    _log('initialize', 'Initializing Manager...');
    await setTab(MemberStatus.active);
  }

  /// [setTab]
  /// 탭 변경 시 호출. 서버에서 해당 상태의 멤버들을 새로 가져옴.
  Future<void> setTab(MemberStatus status) async {
    _log('setTab', 'Changing tab to: ${status.name}');

    _activeTab = status;
    _activeFilters.clear(); // 탭 변경 시 필터 초기화
    _isLoading = true;
    notifyListeners(); // UI Loading 시작

    try {
      // 1. Repository Call (Server-Side Filtering)
      _allMembersInTab = await _repository.fetchMembersByStatus(status);

      // 2. Local Filter Apply (No extra filters yet)
      _applyLocalFilters();

      _log('setTab', 'Loaded ${_allMembersInTab.length} members.');
    } catch (e) {
      _log('setTab', 'Error: $e');
      // UI에서 에러를 인지할 수 있도록 빈 리스트 유지 등 처리
      _allMembersInTab = [];
      _filteredMembers = [];
    } finally {
      _isLoading = false;
      notifyListeners(); // UI Update
    }
  }

  /// [addFilter]
  /// 사용자 정의 필터 추가.
  void addFilter(FilterCondition condition) {
    if (_activeFilters.length >= 3) {
      _log('addFilter', 'Filter limit reached (Max 3). Ignoring.');
      return;
    }
    _log('addFilter', 'Adding filter: ${condition.type} = ${condition.value}');
    _activeFilters.add(condition);
    _applyLocalFilters();
    notifyListeners();
  }

  /// [removeFilter]
  /// 특정 인덱스의 필터 제거.
  void removeFilter(int index) {
    if (index >= 0 && index < _activeFilters.length) {
      _log('removeFilter', 'Removing filter at index $index');
      _activeFilters.removeAt(index);
      _applyLocalFilters();
      notifyListeners();
    }
  }

  /// [clearFilters]
  /// 모든 필터 제거.
  void clearFilters() {
    _log('clearFilters', 'Clearing all filters.');
    _activeFilters.clear();
    _applyLocalFilters();
    notifyListeners();
  }

  /// [Core Logic: _applyLocalFilters]
  /// Hybrid Filtering Strategy 의 핵심 로직.
  /// 메모리 상의 _allMembersInTab 에 대해 복합 조건(AND)을 적용.
  void _applyLocalFilters() {
    _log('applyLocalFilters', 'Filtering ${_allMembersInTab.length} items...');

    if (_activeFilters.isEmpty) {
      _filteredMembers = List.from(_allMembersInTab);
      return;
    }

    _filteredMembers = _allMembersInTab.where((member) {
      for (final filter in _activeFilters) {
        bool pass = true;

        switch (filter.type) {
          case 'nickname':
            final keyword = (filter.value as String).toLowerCase();
            pass = member.nickName.toLowerCase().contains(keyword);
            break;
          case 'level_min':
            final min = filter.value as int;
            pass = member.permissionLevel >= min;
            break;
          case 'level_max':
            final max = filter.value as int;
            pass = member.permissionLevel <= max;
            break;
          case 'group_id':
            final gid = filter.value as String;
            pass = member.groupIds.contains(gid);
            break;
          default:
            pass = true;
        }

        if (!pass) return false;
      }
      return true;
    }).toList();

    _log('applyLocalFilters', 'Result: ${_filteredMembers.length} members.');
  }

  /// [updateMemberStatus]
  /// 멤버 상태 변경 및 로컬 리스트 동기화.
  Future<void> updateMemberStatus(String memberId, MemberStatus newStatus) async {
    _log('updateMemberStatus', 'ID: $memberId -> $newStatus');

    try {
      // 1. Server Update
      await _repository.updateMemberStatus(memberId, newStatus);

      // 2. Local List Update (Optimistic UI)
      final index = _allMembersInTab.indexWhere((m) => m.memberId == memberId);
      if (index != -1) {
        // 현재 탭과 상태가 다르면 제거, 같으면 업데이트
        if (_activeTab != newStatus) {
          _allMembersInTab.removeAt(index);
        } else {
          _allMembersInTab[index] = _allMembersInTab[index].copyWith(status: newStatus);
        }

        // 3. Re-filter & Notify
        _applyLocalFilters();
        notifyListeners();
      }
    } catch (e) {
      _log('updateMemberStatus', 'Failed: $e');
      rethrow;
    }
  }
}