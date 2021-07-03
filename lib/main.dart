@JS()
library t;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:js/js.dart';
import 'package:http/http.dart' as http;
import 'package:js/js_util.dart';
import 'package:quiver/strings.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom show Element;

// JS interop for requesting url
@JS()
external Future<String> getCurrentUrl();

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Does it FLoC?',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: MyHomePage(title: 'Does it FLoC?'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isFloc = false;
  bool isFlocBlocked = false;

  int progressJS = 0;
  int totalJS = 0;

  String errMessage = '';

  late Stream<int> checkStream;

  Stream<int> runDown(Duration interval) async* {
    try {

      String siteUrl = await promiseToFuture(getCurrentUrl());

      yield 1;
      await Future.delayed(interval);

      // Get website source
      yield 2;
      Response urlResponse;
      urlResponse = await http.get(Uri.parse(siteUrl));

      // check if the website has a permissions-policy : interest-cohort=() set to block the data collection of FLoC
      yield 3;
      if (urlResponse.headers.containsKey('permissions-policy') &&
          equalsIgnoreCase(urlResponse.headers['permissions-policy'],
              'interest-cohort=()')) {
        setState(() {
          isFlocBlocked = true;
        });
      }

      //  iterate through all script tags
      final listOfScriptElements =
          parse(urlResponse.body).getElementsByTagName('script');
      totalJS = listOfScriptElements.length;
      yield 4;
      for (dom.Element e in listOfScriptElements) {
        try {
          String jsSrcUr = '';

          // get the src uri of the script
          if (e.attributes.containsKey('src')) {
            jsSrcUr = e.attributes['src'].toString();
          }
          // if the src tag is not there, assume the JS is inline and search for the FLoC API, and terminate afterwards
          else {
            if (e.text.contains('document.interestCohort()')) {
              isFloc = true;
            }
            progressJS++;
            yield 4;
            continue;
          }

          Uri jsUrl;
          // Hack way to check if the uri is relative or a direct link
          if (jsSrcUr.startsWith('https://') || jsSrcUr.startsWith('http://'))
            jsUrl = Uri.parse(jsSrcUr);
          else
            jsUrl = Uri.parse(siteUrl + jsSrcUr);

          // get the source code of the jsUrl and search for the FLoC usage API
          final respJS = await http.get(jsUrl);
          if (respJS.body.contains('document.interestCohort()')) {
            isFloc = true;
          }
          await Future.delayed(Duration(milliseconds: 10));
          progressJS++;
          yield 4;
        } catch (e) {
          print('Javascript error for single resource, non-fatal: $e');
          continue;
        }
      }
      yield 5;
      return;
    } catch (e) {
      errMessage = e.toString();
      return;
    }
  }

  @override
  void initState() {
    checkStream = runDown(Duration(seconds: 1));
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        child: AppBar(
          title: Text(widget.title),
          centerTitle: true,
        ),
        preferredSize: Size.fromHeight(25),
      ),
      body: Center(
        child: DefaultTextStyle(
          style: TextStyle(color: Colors.black),
          textAlign: TextAlign.center,
          child: Container(
            child: StreamBuilder<int>(
              stream: checkStream,
              builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                List<Widget> children = [];
                if (snapshot.hasData) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.active:
                      switch (snapshot.data) {
                        case 1:
                          children = [Text("Retrieving page URL...")];
                          break;
                        case 2:
                          children = [Text("Retrieving page source code...")];
                          break;
                        case 3:
                          children = [
                            Text("Checking page for FLoC blocking header...")
                          ];
                          break;
                        case 4:
                          children = [
                            Text(
                                "Retrieving & scanning scripts (${((progressJS / totalJS.toDouble()) * 100).round()}%)"),
                          ];
                          break;
                        default:
                      }
                      break;
                    case ConnectionState.none:
                      break;
                    case ConnectionState.waiting:
                      break;
                    case ConnectionState.done:
                      switch (snapshot.data) {
                        case 5:
                          if (isFlocBlocked) {
                            children = [
                              Icon(Icons.thumb_up_sharp,
                                  color: Colors.green, size: 40),
                              SizedBox(
                                height: 15,
                              ),
                              Text(
                                  'This website is blocking FLoC data collection'),
                            ];
                          } else if (isFloc) {
                            children = [
                              Icon(Icons.warning,
                                  color: Colors.orange, size: 40),
                              SizedBox(height: 15),
                              Text(
                                  'This website has included code from the FLoC Javascript API'),
                            ];
                          } else {
                            children = [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 40,
                              ),
                              SizedBox(height: 15),
                              Text(
                                  'This website does not seem to be using the FLoC Javascript API')
                            ];
                          }
                          break;
                        default:
                      }
                      break;
                  }
                } else {
                  children = <Widget>[
                    SizedBox(
                      child: CircularProgressIndicator(),
                      width: 40,
                      height: 40,
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Text('Beginning website scan'),
                  ];
                }
                if (children.isEmpty) {
                  children = [
                    SizedBox(
                      height: 25,
                    ),
                    Icon(Icons.error, color: Colors.red, size: 40),
                    if (errMessage.isEmpty) Text("Encountered Unknown Issue"),
                    if (errMessage.isNotEmpty) Text("Encountered issue:"),
                    if (errMessage.isNotEmpty) Text(errMessage.toString()),
                  ];
                } else {
                  if (snapshot.data != 5) {
                    children.insertAll(0, [
                      SizedBox(
                        child: CircularProgressIndicator(),
                        width: 40,
                        height: 40,
                      ),
                      SizedBox(
                        height: 15,
                      ),
                    ]);
                  }
                  children.insert(
                      0,
                      SizedBox(
                        height: 25,
                      ));
                }
                return Column(children: children);
              },
            ),
          ),
        ),
      ),
    );
  }
}
