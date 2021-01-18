import 'package:dorker/dorker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:worker_service/ports.dart';

class TestWorkProxies extends StatefulWidget {
  final Dorker dorker;

  const TestWorkProxies({Key key, @required this.dorker}) : super(key: key);

  @override
  _TestWorkProxiesState createState() => _TestWorkProxiesState();
}

class _TestWorkProxiesState extends State<TestWorkProxies> {
  final _items = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Isolates"),
        ),
        // backgroundColor: Colors.white,
        body: Center(
          child: Column(
            children: [
              SizedBox(height: 10),
              Container(
                child: RaisedButton(
                    onPressed: () {
                      widget.dorker.postMessage.add("Another button!");
                    },
                    child: Text("Go")),
              ),
              for (var s in _items)
                ListTile(
                  title: Text("Work Status"),
                  subtitle: Text("$s"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
