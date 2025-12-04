import 'dart:math';

import 'package:a_yp_core_mod_common_client/common/cmn.dart';
import 'package:a_yp_core_mod_laurus_client/common/lau_cmn.dart';
import 'package:a_yp_core_mod_laurus_client/member/domain/member_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Test01Screen extends StatelessWidget {
  const Test01Screen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: const Test01Page(title: 'Flutter Demo Home Page'),
    );
  }
}

class Test01Page extends StatefulWidget {
  const Test01Page({super.key, required this.title});

  final String title;

  @override
  State<Test01Page> createState() => _Test01PageState();
}

class _Test01PageState extends State<Test01Page> {
  int _counter = 0;

  void _incrementCounter() {
    _counter++;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Count : $_counter')));

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    //
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.inversePrimary, title: Text(widget.title)),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ElevatedButton(
                onPressed: () async {
                  LauCmn.pushWithParams(context, '/CreateProjectScreen', {"paramA": 111, "paramB": "aaa"});
                },
                child: Text('CreateProjectScreen'),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  LauCmn.pushWithParams(context, '/ProjectConfigScreen', {"paramA": 111, "paramB": "aaa"});
                },
                child: Text('ProjectConfigScreen'),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  LauCmn.pushWithParams(context, '/MileStoneMapScreen', {"paramA": 111, "paramB": "aaa"});
                },
                child: Text('MileStoneMapScreen'),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  LauCmn.pushWithParams(context, '/MemberListScreen', {"projectId": "seed-test-project-01"});
                },
                child: Text('MemberListScreen'),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  LauCmn.pushWithParams(context, '/GroupManagementScreen', {"projectId": "seed-test-project-01"});
                },
                child: Text('GroupManagementScreen'),
              ),
              SizedBox(height: 16),

              ElevatedButton(
                onPressed: () async {
                },
                child: Text('Member-Group Test Data Injection'),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ), // This trailing comma makes a
      floatingActionButton: FloatingActionButton(onPressed: _incrementCounter, tooltip: 'Increment', child: const Icon(Icons.add)), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}