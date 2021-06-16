@JS()
library t;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:js/js.dart';
import 'package:http/http.dart' as http;
import 'package:js/js_util.dart';
import 'package:quiver/strings.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom show Element;

// JS interop for callback
@JS('dartCallWithUrl')
external set _dartCallWithUrl(void Function(String) f);

// JS interop for requesting callback with URL
@JS()
external bool getCurrentUrl();

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

  String siteUrl = '';

  late Stream<int> checkStream;

  Stream<int> go(Duration interval) async* {
    await promiseToFuture(getCurrentUrl());
    yield 1;
    await Future.delayed(interval);

    // Get website source
    yield 2;
    final urlResponse = await http.get(Uri.parse(siteUrl));

    // check if the website has a permissions-policy : interest-cohort=() set to block the data collection of FLoC
    yield 3;
    if (urlResponse.headers.containsKey('permissions-policy') &&
        equalsIgnoreCase(
            urlResponse.headers['permissions-policy'], 'interest-cohort=()')) {
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
        if (jsSrcUr.startsWith('https://') || jsSrcUr.startsWith('https://'))
          jsUrl = Uri.parse(jsSrcUr);
        else
          jsUrl = Uri.parse(siteUrl + jsSrcUr);

        // get the source code of the jsUrl and search for the FLoC usage API
        print(jsUrl);
        final respJS = await http.get(jsUrl);
        if (respJS.body.contains('document.interestCohort()')) {
          isFloc = true;
        }
        await Future.delayed(Duration(milliseconds: 10));
        progressJS++;
        yield 4;
      } catch (e) {
        print('Non-fatal javascript error: $e');
        continue;
      }
    }
    yield 5;
    return;
  }

  void _recieveUrl(String tab) {
    siteUrl = tab;
  }

  @override
  void initState() {
    _dartCallWithUrl = allowInterop(_recieveUrl);
    checkStream = go(Duration(seconds: 1));
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
                    List<Widget> children;
                    if (snapshot.hasData) {
                      switch (snapshot.connectionState) {
                        case ConnectionState.active:
                          switch (snapshot.data) {
                            case 1:
                              children = [Text("Retrieving page URL...")];
                              break;
                            case 2:
                              children = [
                                Text("Retrieving page source code...")
                              ];
                              break;
                            case 3:
                              children = [
                                Text(
                                    "Checking page for FLoC blocking header...")
                              ];
                              break;
                            case 4:
                              children = [
                                Text(
                                    "Retrieving & scanning page javascript..."),
                                Text(
                                    '${((progressJS / totalJS.toDouble()) * 100).round()}% done'),
                              ];
                              break;
                            default:
                              children = [Text("Encountered issue")];
                          }
                          children.insert(
                            0,
                            SizedBox(
                              child: CircularProgressIndicator(),
                              width: 40,
                              height: 40,
                            ),
                          );
                          break;
                        case ConnectionState.none:
                          children = [Text("Encountered issue")];
                          break;
                        case ConnectionState.waiting:
                          children = [Text("Encountered issue")];
                          break;
                        case ConnectionState.done:
                          switch (snapshot.data) {
                            case 5:
                              if (isFloc)
                                children = [
                                  Icon(Icons.warning, color: Colors.orange),
                                  Text(
                                      'This website has included code from the FLoC Javascript API'),
                                ];
                              else
                                children = [
                                  Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                  Text(
                                      'This website does not seem to be using the FLoC Javascript API')
                                ];
                              if (isFlocBlocked) {
                                children.insert(
                                    0,
                                    SizedBox(
                                      height: 5,
                                    ));
                                children.insert(
                                    0,
                                    Text(
                                        'This website is blocking FLoC data collection'));
                                children.insert(
                                    0,
                                    Icon(Icons.check_circle_outline,
                                        color: Colors.green));
                              }
                              break;
                            default:
                              children = [Text("Encountered issue")];
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
                        Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text('Scanning website'),
                        )
                      ];
                    }
                    children.insert(0, SizedBox(height: 25));
                    return Column(children: children);
                  },
                ),
              ))),
    );
  }
}
