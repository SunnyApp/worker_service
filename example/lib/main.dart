import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:sunny_dart/sunny_dart.dart';
import 'package:worker_service/worker_service.dart';

export 'package:sunny_dart/sunny_dart.dart';

void main() => runApp(ContactsExampleApp());

class ContactsExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PlatformApp(
        home: PlatformScaffold(
      appBar: PlatformAppBar(title: Text("State Test")),
      body: ListView.builder(
          itemCount: 1,
          itemBuilder: (context, idx) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              mainAxisSize: MainAxisSize.max,
              children: [
                Flexible(flex: 1, child: WebWorkerTile(idx, 1)),
//                Flexible(flex: 1, child: WebWorkerTile(idx, 2)),
              ],
            );
          }),
    ));
  }
}

class WebWorkerTile extends StatefulWidget {
  final int rowId;
  final int columnId;

  WebWorkerTile(this.rowId, this.columnId) : super(key: Key("worker-$rowId-$columnId"));

  @override
  _WebWorkerTileState createState() => _WebWorkerTileState();
}

class _WebWorkerTileState extends State<WebWorkerTile> {
  WorkhorseService runnerService;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      alignment: Alignment.center,
      color: Colors.grey,
      child: Column(
        children: <Widget>[
          Text("Worker ${widget.rowId} ${widget.columnId}"),
          Text('${runningTotal / count}', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    runnerService = WorkhorseFactory.global.create((builder) {
      builder.debugName = "Worker ${widget.rowId} ${widget.columnId}";
    });

    initiateRunner();
  }

  int runningTotal = 0;
  int count = 0;
  Future initiateRunner() async {
    for (;;) {
      try {
        runningTotal = await runnerService.run("calculateStuff", runningTotal) as int;
        count++;
        setState(() {});
      } catch (e, stack) {
        print(e);
        print(stack);
      }
      await Future.delayed(5.seconds);
    }
  }
}

int calculateStuff(int starting) {
  final start = DateTime.now();
  for (int i = 0; i < 1000000000; i++) {}
  final end = DateTime.now();
  final diff = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
  return diff + starting;
}
