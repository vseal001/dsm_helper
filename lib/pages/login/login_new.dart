import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dsm_helper/apis/api.dart';
import 'package:dsm_helper/apis/dsm_api/dsm_response.dart';
import 'package:dsm_helper/database/table_extention.dart';
import 'package:dsm_helper/database/tables.dart';
import 'package:dsm_helper/models/Syno/Api/auth.dart';
import 'package:dsm_helper/models/Syno/SDS/Session/SessionData.dart';
import 'package:dsm_helper/pages/dashboard/dashboard.dart';
import 'package:dsm_helper/pages/home.dart';
// import 'package:dsm_helper/pages/index/index.dart';
import 'package:dsm_helper/pages/server/select_server.dart';
import 'package:dsm_helper/utils/db_utils.dart';
import 'package:dsm_helper/utils/extensions/media_query_ext.dart';
import 'package:dsm_helper/utils/extensions/navigator_ext.dart';
import 'package:dsm_helper/utils/utils.dart' hide Api;
import 'package:dsm_helper/widgets/button.dart';
import 'package:dsm_helper/widgets/custom_dialog/custom_dialog.dart';
// import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Login extends StatefulWidget {
  const Login(this.server, {super.key});
  final Server server;
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpCodeController = TextEditingController();
  String account = '';
  String password = '';
  String otpCode = '';
  bool rememberDevice = true;
  bool loading = false;
  bool showPassword = false;
  bool isDefault = false;
  String cipherStr = "";
  SessionDataModel? sessionDataModel;

  @override
  void initState() {
    getSessionData();
    super.initState();
  }

  getSessionData() async {
    var res = await Api.dsm.get("/webapi/query.cgi", parameters: {
      "api": "SYNO.Core.Desktop.SessionData",
      "version": 1,
      "method": "getjs",
      "SynoToken": "",
    });
    final regex = RegExp(r'SYNO\.SDS\.Session\s*=\s*([\s\S]*?);');

    try {
      final match = regex.firstMatch(res);
      final sessionDataString = match?.group(1);
      setState(() {
        sessionDataModel = SessionDataModel.fromJson(jsonDecode(sessionDataString!));
      });
      // 将hostname和backgroundImage存入Servers
      DbUtils.db.updateServer(widget.server.copyWith(
          backgroundImage: drift.Value("${widget.server.url}/${(sessionDataModel?.loginBackgroundEnable ?? false) ? "webman/login_background${sessionDataModel?.loginBackgroundExt}" : "webman/resources/images/2x/default_login_background/dsm7_01.jpg?v=1685410415"}"),
          hostname: drift.Value(sessionDataModel?.hostname)));
    } catch (e) {}
  }

  login() async {
    setState(() {
      loading = true;
    });

    try {
      Map<String, dynamic> data = {
        "account": account,
        "passwd": password,
        "otp_code": otpCode,
        "version": 4,
        "api": "SYNO.API.Auth",
        "method": "login",
        "session": "FileStation",
        "enable_device_token": rememberDevice ? "yes" : "no",
        "enable_sync_token": "yes",
      };
      DsmResponse res = await Api.dsm.entry<Auth>("SYNO.API.Auth", "login", post: true, data: data, parameters: {
        "api": "SYNO.API.Auth",
      }, parser: (json) {
        return Auth.fromJson(json);
      });
      if (res.success ?? false) {
        Auth authModel = res.data;
        Account acc = await DbUtils.db.into(DbUtils.db.accounts).insertReturning(
              AccountsCompanion.insert(
                account: account,
                serverId: widget.server.id,
                password: password,
                remark: "",
                createTime: DateTime.now().secondsSinceEpoch,
                lastLoginTime: DateTime.now().secondsSinceEpoch,
                isDefault: isDefault,
                deviceId: authModel.deviceId!,
                ikMessage: authModel.ikMessage!,
                sid: authModel.sid!,
                synoToken: authModel.synotoken!,
              ),
            );
        await Api.dsm.init(widget.server.url, deviceId: authModel.deviceId, sid: authModel.sid);
        context.push(Home(), replace: true);
      } else if (res.error?['code'] == 400) {
        Utils.toast("用户名/密码有误");
      } else if (res.error?['code'] == 403) {
        showOptCodeDialog("xx");
      } else if (res.error?['code'] == 404) {
        showOptCodeDialog("xx");
        Utils.toast("错误的验证代码。请再试一次。");
      } else if (res.error?['code'] == 414) {
        // 需要二次验证
        showOptCodeDialog("为确认这是您本人登录，系统已将验证码发送到${res.error?['errors']['email']}，请查看您的邮箱，并在5分钟内输入验证码");
      }
      // var res = await Api.dsm.post('/webapi/entry.cgi', parameters: {"api": "SYNO.API.Auth"}, data: data);
      // print(res);
      // var shares = await Api.dsm.post('/webapi/entry.cgi', data: {"api": "SYNO.Core.Desktop.Initdata", "version": 1, "method": "get"});
      // print(shares);
      // context.push(Index());
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  showOptCodeDialog(String message) {
    otpCode = '';
    _otpCodeController.clear();
    showCustomDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            title: Text("验证您的身份"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                SizedBox(
                  height: 10,
                ),
                TextField(
                  onChanged: (v) => setState(() {
                    otpCode = v;
                  }),
                  controller: _otpCodeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "输入验证码",
                    // suffixIconColor: Colors.red,
                  ),
                ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: Button(
                      child: Text("取消"),
                      onPressed: () {
                        context.pop();
                      },
                      fill: false,
                      borderColor: Colors.black,
                    ),
                  ),
                  SizedBox(
                    width: 20,
                  ),
                  Expanded(
                    child: Button(
                      child: Text("登录"),
                      onPressed: () {
                        login();
                        context.pop();
                      },
                    ),
                  ),
                ],
              )
            ],
          );
        });
    // showCustomDialog(context: context, builder: (context){
    //   return AlertDialog(
    //     title: Text("验证您的身份"),
    //     content: Text("$message"),
    //     actions: [
    //
    //     ],
    //   );
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            Container(
              height: context.height,
            ),
            ExtendedImage.network(
              "${widget.server.url}/${(sessionDataModel?.loginBackgroundEnable ?? false) ? "webman/login_background${sessionDataModel?.loginBackgroundExt}" : "webman/resources/images/2x/default_login_background/dsm7_01.jpg?v=1685410415"}",
              cache: false,
              height: context.width / 16 * 9,
              width: context.width,
              fit: BoxFit.cover,
            ),
            if ((sessionDataModel?.loginLogoEnable ?? false) && (sessionDataModel?.loginLogoExt != null))
              Positioned(
                left: 20,
                top: context.padding.top - 10,
                child: ExtendedImage.network(
                  "${widget.server.url}/webman/login_logo${sessionDataModel?.loginLogoExt}",
                  cache: false,
                  height: 30,
                  fit: BoxFit.cover,
                ),
              ),
            if (sessionDataModel?.loginWelcomeTitle != null || sessionDataModel?.loginWelcomeMsg != null)
              Positioned(
                left: 20,
                top: context.width / 16 * 9 / 2 - 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sessionDataModel?.loginWelcomeTitle != null)
                      Text(
                        "${sessionDataModel?.loginWelcomeTitle}",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                      ),
                    if (sessionDataModel?.loginWelcomeMsg != null)
                      Text(
                        "${sessionDataModel?.loginWelcomeMsg}",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                  ],
                ),
              ),
            if (sessionDataModel?.loginFooterMsg != null && sessionDataModel?.loginFooterEnableHtml == false)
              Positioned(
                  top: context.width / 16 * 9 - 70,
                  child: SizedBox(
                    width: context.width,
                    child: Center(
                      child: Text(
                        "${sessionDataModel?.loginFooterMsg}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
                      ),
                    ),
                  )),
            Positioned(
              top: 200,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (ModalRoute.of(context)?.canPop ?? false) {
                          context.pop();
                        } else {
                          context.push(SelectServer(), replace: true);
                        }
                      },
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back_ios),
                          Text("选择服务器"),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 40,
                    ),
                    Text(
                      sessionDataModel?.hostname ?? '账号登录',
                      style: Theme.of(context).textTheme.headlineMedium,
                      strutStyle: StrutStyle(
                        forceStrutHeight: true,
                      ),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Text(
                      "${widget.server.url}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    TextField(
                      onChanged: (v) => setState(() {
                        account = v;
                      }),
                      controller: _accountController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        hintText: "账号",
                        iconColor: Colors.red,
                        suffixIcon: account.isNotEmpty
                            ? GestureDetector(
                                child: Icon(Icons.highlight_remove),
                                onTap: () {
                                  setState(() {
                                    account = '';
                                    _accountController.clear();
                                  });
                                },
                              )
                            : null,
                        // suffixIconColor: Colors.red,
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    TextField(
                      controller: _passwordController,
                      onChanged: (v) => setState(() {
                        password = v;
                      }),
                      obscureText: !showPassword,
                      keyboardType: TextInputType.visiblePassword,
                      decoration: InputDecoration(
                        hintText: "密码",
                        iconColor: Colors.red,
                        suffixIcon: password.isNotEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    child: Icon(Icons.password),
                                    onTap: () {
                                      setState(() {
                                        showPassword = !showPassword;
                                      });
                                    },
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  GestureDetector(
                                    child: Icon(Icons.highlight_remove),
                                    onTap: () {
                                      _passwordController.clear();
                                      setState(() {
                                        password = '';
                                      });
                                    },
                                  ),
                                  SizedBox(
                                    width: 15,
                                  ),
                                ],
                              )
                            : null,
                        // suffixIconColor: Colors.red,
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    Row(
                      children: [
                        Button(
                          child: Text(
                            "设为默认",
                            strutStyle: StrutStyle(
                              forceStrutHeight: true,
                            ),
                          ),
                          color: isDefault ? Colors.green : null,
                          fill: isDefault,
                          borderColor: isDefault ? Colors.green : Colors.black,
                          icon: Icon(
                            Icons.check,
                            color: isDefault ? Colors.white : Colors.black,
                            size: 16,
                          ),
                          onPressed: () {
                            setState(() {
                              isDefault = !isDefault;
                            });
                          },
                        ),
                        SizedBox(
                          width: 20,
                        ),
                        Expanded(
                          child: Button(
                            child: Text("登录"),
                            loading: loading,
                            onPressed: login,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
