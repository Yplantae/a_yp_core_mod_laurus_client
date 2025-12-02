
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class LauCmn {
  static void pushWithParams(BuildContext context, String path, Map<String, dynamic> params) {
    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    context.push('$path?$queryString');
  }
}