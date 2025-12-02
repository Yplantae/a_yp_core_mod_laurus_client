import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';

class CreateProjectScreenArg {
  final int? paramA;
  final String? paramB;
  final bool hasError;
  final String? errorMessage;

  CreateProjectScreenArg({
    this.paramA,
    this.paramB,
    this.hasError = false,
    this.errorMessage,
  });

  factory CreateProjectScreenArg.error(String msg) {
    return CreateProjectScreenArg(
      hasError: true,
      errorMessage: msg,
    );
  }
}

class CreateProjectScreen extends StatelessWidget {
  final CreateProjectScreenArg args;

  CreateProjectScreen(this.args);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: CreateProjectPage(this.args),
    );
  }

  static CreateProjectScreenArg argProc(GoRouterState state) {
    // 1) extra 읽기 (Map)
    Map<String, dynamic> data = {};
    if (state.extra is Map<String, dynamic>) {
      data = Map<String, dynamic>.from(state.extra as Map);
    }

    // 2) query param 과 merge (query 가 이기게)
    data.addAll(state.uri.queryParameters);

    // 3) 이후 paramA/paramB 처리
    final rawA = data['paramA']?.toString();
    if (rawA == null) return CreateProjectScreenArg.error("paramA 누락");
    final parsedA = int.tryParse(rawA);
    if (parsedA == null) return CreateProjectScreenArg.error("paramA 형식 오류");

    final rawB = data['paramB']?.toString() ?? "";

    return CreateProjectScreenArg(
      paramA: parsedA,
      paramB: rawB,
    );
  }
}

class CreateProjectPage extends StatefulWidget {
  final CreateProjectScreenArg args;

  CreateProjectPage(this.args);

  @override
  State<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends State<CreateProjectPage> {
  bool _dialogShown = false;
  int _counter = 0;

  // 요구사항을 위한 컨트롤러 추가
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    // 위젯이 dispose될 때 컨트롤러도 해제하여 메모리 누수를 방지합니다.
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _createProject() {
    final title = _titleController.text;
    final description = _descriptionController.text;

    // 프로젝트 생성 로직 (예시로 Toast 메시지 출력)
    Fluttertoast.showToast(
      msg: "프로젝트 생성 요청: Title='$title', Description='$description'",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );

    // 실제로는 여기에 API 호출 또는 상태 업데이트 로직이 들어갑니다.
    print('Title: $title, Description: $description');
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
              GoRouter.of(context).go("/"); // 홈으로 이동
            },
            child: const Text("확인"),
          ),
        ],
      ),
    );
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

    // 기존 Toast 코드는 그대로 유지하거나 필요에 따라 제거/수정
    Fluttertoast.showToast(
      msg: widget.args.paramA!.toString() + " / " + widget.args.paramB!,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("프로젝트 생성 화면"), // 타이틀 변경
      ),
      body: SingleChildScrollView( // 내용이 길어질 경우 스크롤 가능하도록 SingleChildScrollView 사용
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // 버튼 등을 가로로 꽉 채우기 위해 사용
          children: [
            // 1. Title 입력 필드
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '프로젝트 제목 (Title)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0), // 간격 추가

            // 2. Description 입력 필드
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '프로젝트 설명 (Description)',
                border: OutlineInputBorder(),
              ),
              maxLines: 5, // 여러 줄 입력 가능하도록 설정
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 32.0), // 버튼 위에 더 큰 간격 추가

            // 3. "프로젝트 생성" 버튼
            ElevatedButton(
              onPressed: _createProject, // 버튼 클릭 시 _createProject 함수 실행
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15.0),
                backgroundColor: Theme.of(context).primaryColor, // 버튼 배경색
                foregroundColor: Colors.white, // 버튼 텍스트 색상
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('프로젝트 생성'),
            ),

            // 기존 코드 (파라미터 및 카운터 정보) - 필요에 따라 유지하거나 제거
            const SizedBox(height: 32.0),
            const Divider(),
            const Text('URL 파라미터 정보:'),
            Text(
              'paramA: ${widget.args.paramA}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              'paramB: ${widget.args.paramB}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Text('Counter (기존 기능):'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      // 기존 FloatingActionButton은 필요 없다고 판단되어 주석 처리/제거 가능
      /* floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), */
    );
  }
}