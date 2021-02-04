import 'dart:async';
import 'dart:convert';

import 'package:dsm_helper/util/function.dart';
import 'package:dsm_helper/widgets/label.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:neumorphic/neumorphic.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class Accounts extends StatefulWidget {
  @override
  _AccountsState createState() => _AccountsState();
}

class _AccountsState extends State<Accounts> {
  List servers = [];
  Timer timer;
  @override
  void initState() {
    getData();
    super.initState();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  getData() async {
    String serverString = await Util.getStorage("servers");
    if (serverString.isNotBlank) {
      setState(() {
        servers = json.decode(serverString);
      });
      print(servers);
      getInfo();
    }
  }

  getInfo() async {
    if (timer == null) {
      timer = Timer.periodic(Duration(seconds: 5), (timer) {
        getInfo();
      });
    }
    servers.forEach((server) {
      server['is_login'] = server['is_login'] ?? false;
      if (server['is_login']) {
        serverInfo(server);
      } else {
        //仅首次重新登录
        if (server['loading']) {
          String host = "${server['https'] ? "https" : "http"}://${server['host']}:${server['port']}";
          Api.shareList(sid: server['sid'], checkSsl: server['check_ssl'], cookie: server['smid'], host: host).then((checkLogin) async {
            if (checkLogin['success']) {
              server['is_login'] = true;
              //获取系统信息
              serverInfo(server);
            } else {
              //登录失败，尝试重新登录
              var res = await Api.login(host: host, account: server['account'], password: server['password'], otpCode: "", rememberDevice: server['remember_device'], cookie: server['smid']);
              if (res['success']) {
                server['sid'] = res['data']['sid'];
              } else {
                setState(() {
                  server['loading'] = false;
                });
              }
            }
          });
        }
      }
    });
  }

  serverInfo(server) async {
    var res = await Api.utilization(sid: server['sid'], checkSsl: server['check_ssl'], cookie: server['smid'], host: "${server['https'] ? "https" : "http"}://${server['host']}:${server['port']}");
    if (res['success']) {
      setState(() {
        server['cpu'] = (res['data']['cpu']['user_load'] + res['data']['cpu']['system_load']);
        server['ram'] = res['data']['memory']['real_usage'];
        if (res['data']['network'].length > 0) {
          server['rx'] = res['data']['network'][0]['rx'];
          server['tx'] = res['data']['network'][0]['tx'];
        }
        if (res['data']['disk']['total'] != null) {
          server['read'] = res['data']['disk']['total']['read_byte'];
          server['write'] = res['data']['disk']['total']['write_byte'];
        }

        server['loading'] = false;
      });
    }
  }

  Widget _buildServerItem(server) {
    server['loading'] = server['loading'] ?? true;
    server['cpu'] = server['cpu'] ?? 0.0;
    server['ram'] = server['ram'] ?? 0.0;
    server['tx'] = server['tx'] ?? 0.0;
    server['rx'] = server['rx'] ?? 0.0;
    server['read'] = server['read'] ?? 0.0;
    server['write'] = server['write'] ?? 0.0;
    return GestureDetector(
      onTap: () {
        if (server['is_login']) {}
      },
      child: NeuCard(
        curveType: CurveType.flat,
        decoration: NeumorphicDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        bevel: 20,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${server['account']}",
                                style: TextStyle(fontSize: 18),
                              ),
                              Text(
                                "${server['https'] ? "https" : "http"}://${server['host']}",
                                style: TextStyle(color: Colors.grey),
                              )
                            ],
                          ),
                        ),
                        if (server['loading']) CupertinoActivityIndicator() else if (!server['is_login']) Label("登录失效", Colors.red),
                      ],
                    ),
                    Row(
                      children: [
                        Column(
                          children: [
                            NeuCard(
                              curveType: CurveType.flat,
                              margin: EdgeInsets.only(top: 10, right: 10),
                              decoration: NeumorphicDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(60),
                                // color: Colors.red,
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              bevel: 8,
                              child: CircularPercentIndicator(
                                radius: 60,
                                // progressColor: Colors.lightBlueAccent,
                                animation: true,
                                linearGradient: LinearGradient(
                                  colors: server['cpu'] <= 90
                                      ? [
                                          Colors.blue,
                                          Colors.blueAccent,
                                        ]
                                      : [
                                          Colors.red,
                                          Colors.orangeAccent,
                                        ],
                                ),
                                animateFromLastPercent: true,
                                circularStrokeCap: CircularStrokeCap.round,
                                lineWidth: 8,
                                backgroundColor: Colors.black12,
                                percent: server['cpu'] / 100,
                                center: server['loading']
                                    ? CupertinoActivityIndicator()
                                    : Text(
                                        "${server['cpu']}%",
                                        style: TextStyle(color: server['cpu'] <= 90 ? Colors.blue : Colors.red, fontSize: 16),
                                      ),
                              ),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Text("CPU"),
                          ],
                        ),
                        Column(
                          children: [
                            NeuCard(
                              curveType: CurveType.flat,
                              margin: EdgeInsets.only(top: 10, right: 10),
                              decoration: NeumorphicDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(60),
                                // color: Colors.red,
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              bevel: 8,
                              child: CircularPercentIndicator(
                                radius: 60,
                                // progressColor: Colors.lightBlueAccent,
                                animation: true,
                                linearGradient: LinearGradient(
                                  colors: server['ram'] <= 90
                                      ? [
                                          Colors.blue,
                                          Colors.blueAccent,
                                        ]
                                      : [
                                          Colors.red,
                                          Colors.orangeAccent,
                                        ],
                                ),
                                animateFromLastPercent: true,
                                circularStrokeCap: CircularStrokeCap.round,
                                lineWidth: 8,
                                backgroundColor: Colors.black12,
                                percent: server['ram'] / 100,
                                center: server['loading']
                                    ? CupertinoActivityIndicator()
                                    : Text(
                                        "${server['ram']}%",
                                        style: TextStyle(color: server['ram'] <= 90 ? Colors.blue : Colors.red, fontSize: 16),
                                      ),
                              ),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Text("RAM"),
                          ],
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              SizedBox(
                                height: 85,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.upload_sharp,
                                          color: Colors.blue,
                                          size: 16,
                                        ),
                                        Text(
                                          "${server['loading'] ? "-" : "${Util.formatSize(server['tx'], fixed: 0)}/S"}",
                                          style: TextStyle(color: Colors.blue, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.download_sharp,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                        Text(
                                          "${server['loading'] ? "-" : "${Util.formatSize(server['rx'], fixed: 0)}/S"}",
                                          style: TextStyle(color: Colors.green, fontSize: 12),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                              Text("网络"),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              SizedBox(
                                height: 85,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "R:${server['loading'] ? "-" : "${Util.formatSize(server['read'], fixed: 0)}/S"}",
                                      style: TextStyle(color: Colors.blue, fontSize: 12),
                                    ),
                                    SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "W:${server['loading'] ? "-" : "${Util.formatSize(server['write'], fixed: 0)}/S"}",
                                      style: TextStyle(color: Colors.green, fontSize: 12),
                                    )
                                  ],
                                ),
                              ),
                              Text("磁盘"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("选择账号"),
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(20),
        itemBuilder: (context, i) {
          return _buildServerItem(servers[i]);
        },
        itemCount: servers.length,
        separatorBuilder: (context, i) {
          return SizedBox(
            height: 20,
          );
        },
      ),
      // floatingActionButton: FloatingActionButton(
      //   child: Icon(Icons.refresh),
      //   onPressed: () {
      //     getInfo();
      //   },
      // ),
    );
  }
}