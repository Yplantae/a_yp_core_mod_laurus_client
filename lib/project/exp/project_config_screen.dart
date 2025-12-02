import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

class ProjectConfigScreenArg {
  final int? paramA;
  final String? paramB;
  final bool hasError;
  final String? errorMessage;

  ProjectConfigScreenArg({this.paramA, this.paramB, this.hasError = false, this.errorMessage});

  factory ProjectConfigScreenArg.error(String msg) {
    return ProjectConfigScreenArg(hasError: true, errorMessage: msg);
  }
}

class ProjectConfigScreen extends StatelessWidget {
  final ProjectConfigScreenArg args;

  ProjectConfigScreen(this.args);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Flutter Demo', home: ProjectConfigPage(this.args));
  }

  static ProjectConfigScreenArg argProc(GoRouterState state) {
    final qp = state.uri.queryParameters;

    // ---------------------
    // paramA (필수 + int)
    // ---------------------
    final rawA = qp['paramA'];
    if (rawA == null) {
      return ProjectConfigScreenArg.error("필수 파라미터 'paramA' 가 누락되었습니다.");
    }

    final parsedA = int.tryParse(rawA);
    if (parsedA == null) {
      return ProjectConfigScreenArg.error("파라미터 'paramA' 는 int 타입이어야 합니다. 입력값: $rawA");
    }

    // ---------------------
    // paramB (선택 + String)
    // ---------------------
    final rawB = qp['paramB'];
    String parsedB = "";

    if (rawB != null) {
      // 문자열 타입은 들어오면 무조건 toString 처리
      // 쿼리 파라미터는 항상 문자열이라 별도 타입 검증 불필요
      parsedB = rawB.toString();
    }

    return ProjectConfigScreenArg(paramA: parsedA, paramB: parsedB);
  }
}

enum ProgressType { initial, inProgress, completed, paused }

enum AccessType { private, internal, public }

// Supported Task를 위한 데이터 구조
class SupportedTask {
  final String name;
  final bool isSelected;

  SupportedTask(this.name, this.isSelected);

  SupportedTask copyWith({bool? isSelected}) {
    return SupportedTask(this.name, isSelected ?? this.isSelected);
  }
}

class ProjectConfigPage extends StatefulWidget {
  final ProjectConfigScreenArg args;

  ProjectConfigPage(this.args);

  @override
  State<ProjectConfigPage> createState() => _ProjectConfigPageState();
}

class _ProjectConfigPageState extends State<ProjectConfigPage> {
  bool _dialogShown = false;

  // int _counter = 0; // 사용하지 않는 카운터는 제거하거나 주석 처리

  // 1. Text Field Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // 2. Dropdown Menu State
  ProgressType? _selectedProgressType;
  AccessType? _selectedAccessType;

  // 3. Checkbox State (Supported Task)
  List<SupportedTask> _supportedTasks = [SupportedTask('Post', true), SupportedTask('Photo-Video', false), SupportedTask('Check List', true)];

  @override
  void initState() {
    super.initState();
    // 초기 드롭다운 값 설정
    _selectedProgressType = ProgressType.initial;
    _selectedAccessType = AccessType.private;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 관리 버튼 클릭 이벤트 핸들러
  void _onManageTap(String feature) {
    Fluttertoast.showToast(msg: "$feature 관리 버튼 클릭됨", toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.CENTER);
    // 실제로는 GoRouter를 사용하여 해당 관리 화면으로 이동하는 로직이 들어갑니다.
    // e.g., GoRouter.of(context).push('/$feature/manage');
  }

  void _showErrorDialog(BuildContext context, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("잘못된 URL 파라미터"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              GoRouter.of(context).go("/");
            },
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  // CheckBox 상태 변경 핸들러
  void _onTaskCheckboxChanged(int index, bool? newValue) {
    setState(() {
      _supportedTasks[index] = _supportedTasks[index].copyWith(isSelected: newValue);
    });
  }

  // 최종 설정 저장 (예시)
  void _saveConfiguration() {
    final title = _titleController.text;
    final description = _descriptionController.text;
    final progress = _selectedProgressType.toString().split('.').last;
    final access = _selectedAccessType.toString().split('.').last;
    final supported = _supportedTasks.where((task) => task.isSelected).map((e) => e.name).toList();

    // 최종 설정 값들을 출력
    print('Title: $title');
    print('Description: $description');
    print('Progress Type: $progress');
    print('Access Type: $access');
    print('Supported Tasks: $supported');

    Fluttertoast.showToast(msg: "설정 저장 완료: Title='$title'", toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.TOP, backgroundColor: Colors.blueGrey, textColor: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.args.hasError && !_dialogShown) {
      _dialogShown = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog(context, widget.args.errorMessage!);
      });
    }

    if (widget.args.hasError) {
      return const Center(child: CircularProgressIndicator());
    }

    // 파라미터 Toast (디버깅용)
    Fluttertoast.showToast(msg: widget.args.paramA!.toString() + " / " + widget.args.paramB!, toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("프로젝트 설정"),
        actions: [
          TextButton(
            onPressed: _saveConfiguration,
            child: const Text("저장", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Title 입력 필드
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '프로젝트 제목 (Title)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16.0),

            // 2. Description 입력 필드
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: '프로젝트 설명 (Description)', border: OutlineInputBorder()),
              maxLines: 3,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 24.0),
            const Divider(),

            // 3. Progress Type (Drop Down Menu)
            _buildDropdownTile<ProgressType>(
              title: '진행 상태 (Progress Type)',
              value: _selectedProgressType,
              items: ProgressType.values.map((type) {
                return DropdownMenuItem(value: type, child: Text(type.toString().split('.').last));
              }).toList(),
              onChanged: (ProgressType? newValue) {
                setState(() {
                  _selectedProgressType = newValue;
                });
              },
            ),
            const SizedBox(height: 16.0),

            // 4. Access Type (Drop Down Menu)
            _buildDropdownTile<AccessType>(
              title: '접근 권한 (Access Type)',
              value: _selectedAccessType,
              items: AccessType.values.map((type) {
                return DropdownMenuItem(value: type, child: Text(type.toString().split('.').last));
              }).toList(),
              onChanged: (AccessType? newValue) {
                setState(() {
                  _selectedAccessType = newValue;
                });
              },
            ),
            const SizedBox(height: 24.0),
            const Divider(),

            // 5. Supported Task (Check Box 묶음)
            _buildSectionHeader('지원 기능 (Supported Task)'),
            ..._supportedTasks.asMap().entries.map((entry) {
              int index = entry.key;
              SupportedTask task = entry.value;
              return CheckboxListTile(title: Text(task.name), value: task.isSelected, onChanged: (newValue) => _onTaskCheckboxChanged(index, newValue), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero);
            }).toList(),
            const SizedBox(height: 24.0),
            const Divider(),

            // 6. Milestone Map (관리 버튼)
            _buildManageTile('마일스톤 맵 (MileStoneMap)'),
            // 7. Member (관리 버튼)
            _buildManageTile('멤버 관리 (Member)'),
            // 8. Group (관리 버튼)
            _buildManageTile('그룹 관리 (Group)'),
            // 9. Permission (관리 버튼)
            _buildManageTile('권한 설정 (Permission)'),
            // 10. Category Map (관리 버튼)
            _buildManageTile('카테고리 맵 (Category Map)'),
          ],
        ),
      ),
    );
  }

  // --- 재사용 가능한 위젯 빌더 함수 ---

  // 드롭다운 메뉴를 위한 위젯
  Widget _buildDropdownTile<T>({required String title, required T? value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
      ],
    );
  }

  // 소제목 옆에 "관리" 버튼을 포함하는 위젯
  Widget _buildManageTile(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          OutlinedButton(onPressed: () => _onManageTap(title), child: const Text("관리")),
        ],
      ),
    );
  }

  // 섹션 헤더를 위한 위젯
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
