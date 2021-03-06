import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:http/http.dart' as http;

import 'database/database_helper.dart';




const EVENTS_KEY = "fetch_events";
const url = "http://mayadin.tehran.ir/DesktopModules/TM_ArticleList/API/Article/GetList/2766";




void _insert(String string) async {
  final dbHelper = DatabaseHelper.instance;
  // row to insert
  Map<String, dynamic> row = {
    DatabaseHelper.columnArticleId : string,
  };
  final id = await dbHelper.insert(row);
  print('inserted row id: $id');
}



Future<List> _query(List firstArticleId, List lastArticleId) async {
  final dbHelper = DatabaseHelper.instance;
  firstArticleId = await dbHelper.queryAllRows();
  print('query all rows:');
  firstArticleId.forEach((row) => print(row));

  for (var i = 0; i < firstArticleId.length; i++)
    lastArticleId.add(firstArticleId[i]['articleId']);

  return lastArticleId;
}



void _update() async {
  final dbHelper = DatabaseHelper.instance;
  // row to update
  Map<String, dynamic> row = {
    DatabaseHelper.columnId   : 1,
    DatabaseHelper.columnArticleId : 'Mary',
  };
  final rowsAffected = await dbHelper.update(row);
  print('updated $rowsAffected row(s)');
}



void _delete() async {
  final dbHelper = DatabaseHelper.instance;
  // Assuming that the number of rows is the id for the last row.
  final id = await dbHelper.queryRowCount();
  final rowsDeleted = await dbHelper.delete();
  print('deleted $rowsDeleted row(s): row $id');
}





Future<Map> getData() async {

  List firstArticleId = new List();
  List lastArticleId = new List();
  List savedArticleId = new List();
  savedArticleId = await _query(firstArticleId, lastArticleId);


  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();


  var initializationSettingsAndroid =
  new AndroidInitializationSettings('app_icon');
  var initializationSettingsIOS = new IOSInitializationSettings();
  var initializationSettings = new InitializationSettings(
      initializationSettingsAndroid, initializationSettingsIOS);
  flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();
  flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: onSelectNotification);



  http.Response response = await http.get(url);

  Map result = new Map();
  result = jsonDecode(response.body);
  print(result.toString());
  int temp = 0;

  for (var i = 0; i < result['list'].length; i++) {
    for (var j = 0; j < savedArticleId.length; j++) {
      if (result['list'][i]['ArticleId'].toString() == savedArticleId[j].toString())
        temp++;
    }
    if (temp == 0) {
      _showNotification(flutterLocalNotificationsPlugin);
      _insert(result['list'][i]['ArticleId'].toString());
    }
    else temp = 0;
  }

  return result;
}





Future onSelectNotification(String payload) async {

  print("Tapped notification");

}





Future _showNotification(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails('notiifcation_channel_id', 'Channel Name', 'here we will show',
    importance: Importance.Max, priority: Priority.High, );

    var iosPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(androidPlatformChannelSpecifics, iosPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(0, 'برای مشاهده پیام های جدید کلیک کنید', 'بازار روز همراه', platformChannelSpecifics,
    payload: 'Default_Sound');

}




/// This "Headless Task" is run when app is terminated.
void backgroundFetchHeadlessTask(String taskId) async {
  print("[BackgroundFetch] Headless event received: $taskId");
  DateTime timestamp = DateTime.now();

  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Read fetch_events from SharedPreferences
  List<String> events = [];
  String json = prefs.getString(EVENTS_KEY);
  if (json != null) {
    events = jsonDecode(json).cast<String>();
  }

  Map list = await getData();
  // Add new event.
  events.insert(0, "[Headless] $taskId@${list.toString()}");
  // Persist fetch events in SharedPreferences
  prefs.setString(EVENTS_KEY, jsonEncode(events));

  BackgroundFetch.finish(taskId);

//  if (taskId == 'flutter_background_fetch') {
//    BackgroundFetch.scheduleTask(TaskConfig(
//        taskId: "com.transistorsoft.customtask",
//        delay: 5000,
//        periodic: false,
//        forceAlarmManager: true,
//        stopOnTerminate: false,
//        enableHeadless: true
//    ));
//  }
}








void main() {
  // Enable integration testing with the Flutter Driver extension.
  // See https://flutter.io/testing/ for more info.
  runApp(new MyApp());

  // Register to receive BackgroundFetch events after app is terminated.
  // Requires {stopOnTerminate: false, enableHeadless: true}
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}







class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}







class _MyAppState extends State<MyApp> {

  bool _enabled = true;
  int _status = 0;
  List<String> _events = [];





  @override
  void initState() {
    super.initState();

    initPlatformState();
  }








  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // Load persisted fetch events from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String json = prefs.getString(EVENTS_KEY);
    if (json != null) {
      setState(() {
        _events = jsonDecode(json).cast<String>();
      });
    }



    // Configure BackgroundFetch.
    BackgroundFetch.configure(BackgroundFetchConfig(
      minimumFetchInterval: 15,
      forceAlarmManager: false,
      stopOnTerminate: false,
      startOnBoot: true,
      enableHeadless: true,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresStorageNotLow: false,
      requiresDeviceIdle: false,
      requiredNetworkType: NetworkType.NONE,
    ), _onBackgroundFetch).then((int status) {
      print('[BackgroundFetch] configure success: $status');
      setState(() {
        _status = status;
      });

    }).catchError((e) {
      print('[BackgroundFetch] configure ERROR: $e');
      setState(() {
        _status = e;
      });
    });





    // Schedule a "one-shot" custom-task in 10000ms.
    // These are fairly reliable on Android (particularly with forceAlarmManager) but not iOS,
    // where device must be powered (and delay will be throttled by the OS).
//    BackgroundFetch.scheduleTask(TaskConfig(
//        taskId: "com.transistorsoft.customtask",
//        delay: 10000,
//        periodic: false,
//        forceAlarmManager: true,
//        stopOnTerminate: false,
//        enableHeadless: true
//    ));





    // Optionally query the current BackgroundFetch status.
    int status = await BackgroundFetch.status;
    setState(() {
      _status = status;
    });





    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }





  void _onBackgroundFetch(String taskId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime timestamp = new DateTime.now();
    // This is the fetch-event callback.
    print("[BackgroundFetch] Event received: $taskId");


    Map list = await getData();
    setState(() {
      List ff = new List();
      List kk = new List();
      _query(ff, kk);
      _events.insert(0, "$taskId@${list.toString()}");

    });

    // Persist fetch events in SharedPreferences
    prefs.setString(EVENTS_KEY, jsonEncode(_events));

//    if (taskId == "flutter_background_fetch") {
//      // Schedule a one-shot task when fetch event received (for testing).
//      BackgroundFetch.scheduleTask(TaskConfig(
//          taskId: "com.transistorsoft.customtask",
//          delay: 5000,
//          periodic: false,
//          forceAlarmManager: true,
//          stopOnTerminate: false,
//          enableHeadless: true
//      ));
//    }

    // IMPORTANT:  You must signal completion of your fetch task or the OS can punish your app
    // for taking too long in the background.
    BackgroundFetch.finish(taskId);
  }







  void _onClickEnable(enabled) {
    setState(() {
      _enabled = enabled;
    });
    if (enabled) {
      BackgroundFetch.start().then((int status) {
        print('[BackgroundFetch] start success: $status');
      }).catchError((e) {
        print('[BackgroundFetch] start FAILURE: $e');
      });
    } else {
      BackgroundFetch.stop().then((int status) {
        print('[BackgroundFetch] stop success: $status');
      });
    }
  }







  void _onClickStatus() async {
    int status = await BackgroundFetch.status;
    print('[BackgroundFetch] status: $status');
    setState(() {
      _status = status;
    });
  }







  void _onClickClear() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(EVENTS_KEY);
    setState(() {
      _events = [];
    });
  }






  @override
  Widget build(BuildContext context) {
    const EMPTY_TEXT = Center(child: Text('Waiting for fetch events.  Simulate one.\n [Android] \$ ./scripts/simulate-fetch\n [iOS] XCode->Debug->Simulate Background Fetch'));

    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
            title: const Text('BackgroundFetch Example', style: TextStyle(color: Colors.black)),
            backgroundColor: Colors.amberAccent,
            brightness: Brightness.light,
            actions: <Widget>[
              Switch(value: _enabled, onChanged: _onClickEnable),
            ]
        ),
        body: (_events.isEmpty) ? EMPTY_TEXT : Container(
          child: new ListView.builder(
              itemCount: _events.length,
              itemBuilder: (BuildContext context, int index) {
                List<String> event = _events[index].split("@");
                return InputDecorator(
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.only(left: 5.0, top: 5.0, bottom: 5.0),
                        labelStyle: TextStyle(color: Colors.blue, fontSize: 20.0),
                        labelText: "[${event[0].toString()}]"
                    ),
                    child: new Text(event[1], style: TextStyle(color: Colors.black, fontSize: 16.0))
                );
              }
          ),
        ),
        bottomNavigationBar: BottomAppBar(
            child: Container(
                padding: EdgeInsets.only(left: 5.0, right:5.0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      RaisedButton(onPressed: _onClickStatus, child: Text('Status: $_status')),
                      RaisedButton(onPressed: _onClickClear, child: Text('Clear'))
                    ]
                )
            )
        ),
      ),
    );
  }







}
