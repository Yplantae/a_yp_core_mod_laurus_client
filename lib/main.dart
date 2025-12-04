import 'package:a_yp_core_mod_common_client/common/image/image_screen.dart';
import 'package:a_yp_core_mod_common_client/common/navigator/global_router.dart';
import 'package:a_yp_core_mod_common_client/common/navigator/navi.dart';
import 'package:a_yp_core_mod_common_client/common/web/web_view_screen.dart';
import 'package:a_yp_core_mod_common_client/localization/loc.dart';
import 'package:a_yp_core_mod_common_client/policy/policy_service.dart';
import 'package:a_yp_core_mod_common_client/system/system.dart';
import 'package:a_yp_core_mod_laurus_client/firebase_options.dart';
import 'package:a_yp_core_mod_laurus_client/group/presentation/screen/group_management_screen.dart';
import 'package:a_yp_core_mod_laurus_client/member/screens/member_list_screen.dart';
import 'package:a_yp_core_mod_laurus_client/milestone/milestone_map_screen.dart';
import 'package:a_yp_core_mod_laurus_client/project/exp/create_project_screen.dart';
import 'package:a_yp_core_mod_laurus_client/project/exp/project_config_screen.dart';
import 'package:a_yp_core_mod_laurus_client/zulu/zulu_test_01_screen.dart';
import 'package:a_yp_core_mod_user_client/account/login/login_screen.dart';
import 'package:a_yp_core_mod_user_client/account/logout/logout_screen.dart';
import 'package:a_yp_core_mod_user_client/profile/my_profile_screen.dart';
import 'package:a_yp_core_mod_user_client/push/push_service.dart';
import 'package:a_yp_core_mod_user_client/user/info/user_info_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await AppInitializer.ensureInitialized();
  PushService.instance.pushReceiver.onBackgroundMessageReceived(message);
}

Future<void> main() async {
  setUrlStrategy(PathUrlStrategy());

  await AppInitializer.ensureInitialized();

  runApp(InitScreen());
}

Widget errorScreen(dynamic detailsException) {
  return Scaffold(
    body: Padding(
      padding: EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: Text('$detailsException'),
      ),
    ),
  );
}

class AppInitializer {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _initialized = true;
  }
}

class InitScreen extends StatefulWidget {
  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  late final GoRouter _router = GoRouter(
    initialLocation: Navi.root,
    routes: [
      GoRoute(
        path: Navi.root,
        builder: (context, state) {
          return _buildScreen(Test01Screen());
        },
      ),
      GoRoute(
        path: '/CreateProjectScreen',
        builder: (context, state) {
          final args = CreateProjectScreen.argProc(state);
          return _buildScreen(CreateProjectScreen(args));
        },
      ),
      GoRoute(
        path: "/ProjectConfigScreen",
        builder: (context, state) {
          final args = ProjectConfigScreen.argProc(state);
          return _buildScreen(ProjectConfigScreen(args));
        },
      ),
      GoRoute(
        path: "/MileStoneMapScreen",
        builder: (context, state) {
          final args = MileStoneMapScreen.argProc(state);
          return _buildScreen(MileStoneMapScreen(args));
        },
      ),
      GoRoute(
        path: "/MemberListScreen",
        builder: (context, state) {
          final args = MemberListScreen.argProc(state);
          return _buildScreen(MemberListScreen(args));
        },
      ),
      GoRoute(
        path: "/GroupManagementScreen",
        builder: (context, state) {
          final args = GroupManagementScreen.argProc(state);
          return _buildScreen(GroupManagementScreen(args));
        },
      ),
    ],
  );

  @override
  void initState() {
    super.initState();

    if (PushService.instance.initialPushMessagePayload != null) {
      Future.microtask(() {
        SchedulerBinding.instance.endOfFrame.then((_) {
          PushService.instance.pushReceiver.handleNotiTapFromInitPayload(PushService.instance.initialPushMessagePayload!);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    GlobalRouter.router = _router;

    return MaterialApp.router(
      routerConfig: _router,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ko', 'KR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => ResponsiveBreakpoints.builder(
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
          const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
        child: child!,
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  _buildScreen(Widget child) {
    return ResponsiveBreakpoints(
      breakpoints: const [
        Breakpoint(start: 0, end: 480, name: MOBILE),
        Breakpoint(start: 481, end: 1200, name: TABLET),
        Breakpoint(start: 1201, end: double.infinity, name: DESKTOP),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Container(
          alignment: Alignment.center,
          child: MaxWidthBox(
            maxWidth: 1200,
            child: Container(
              color: Colors.white,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _argProc(GoRouterState state) {
    Map<String, dynamic> args = {};
    final queryParams = state.uri.queryParameters;
    if (state.extra != null && state.extra is Map<String, dynamic>) {
      args = Map<String, dynamic>.from(state.extra as Map);
    }
    args.addAll(queryParams);
    return args;
  }
}
