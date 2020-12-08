import 'dart:async';

import 'package:android_intent/android_intent.dart';
import 'package:dsm_helper/pages/file/select_folder.dart';
import 'package:dsm_helper/pages/file/upload.dart';
import 'package:extended_image/extended_image.dart';
import 'package:dsm_helper/pages/common/preview.dart';
import 'package:dsm_helper/pages/file/detail.dart';
import 'package:dsm_helper/util/function.dart';
import 'package:dsm_helper/widgets/file_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';
import 'package:neumorphic/neumorphic.dart';

class Files extends StatefulWidget {
  @override
  _FilesState createState() => _FilesState();
}

class _FilesState extends State<Files> {
  List paths = ["/"];
  List files = [];
  bool loading = true;
  bool success = true;
  String msg = "";
  bool multiSelect = false;
  List<String> selectedFiles = [];
  ScrollController _pathScrollController = ScrollController();
  ScrollController _fileScrollController = ScrollController();
  Map processing = {};
  Timer timer;
  @override
  void initState() {
    getShareList();
    super.initState();
  }

  setPaths(String path) {
    if (path == "/") {
      setState(() {
        paths = ["/"];
      });
    } else {
      List<String> items = path.split("/");
      items[0] = "/";
      setState(() {
        paths = items;
      });
    }
  }

  getShareList() async {
    setState(() {
      loading = true;
    });
    var res = await Api.shareList();
    setState(() {
      loading = false;
      success = res['success'];
    });
    if (res['success']) {
      setState(() {
        files = res['data']['shares'];
      });
    } else {
      if (loading) {
        setState(() {
          msg = res['msg'] ?? "加载失败，code:${res['error']['code']}";
        });
      }
    }
  }

  getFileList(String path) async {
    setState(() {
      loading = true;
    });
    var res = await Api.fileList(path);
    setState(() {
      loading = false;
      success = res['success'];
    });
    if (res['success']) {
      setState(() {
        files = res['data']['files'];
      });
    } else {
      setState(() {
        msg = res['msg'] ?? "加载失败，code:${res['error']['code']}";
      });
    }
  }

  goPath(String path) async {
    setPaths(path);
    if (path == "/") {
      await getShareList();
    } else {
      await getFileList(path);
    }
    double offset = _pathScrollController.position.maxScrollExtent;
    _pathScrollController.animateTo(offset, duration: Duration(milliseconds: 200), curve: Curves.ease);
    _fileScrollController.jumpTo(0);
  }

  deleteFile(List file) {
    List path = file.map((f) => Uri.encodeComponent(f)).toList();
    print(path);
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return Material(
          color: Colors.transparent,
          child: NeuCard(
            width: double.infinity,
            padding: EdgeInsets.all(22),
            bevel: 5,
            curveType: CurveType.emboss,
            decoration: NeumorphicDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  "确认删除",
                  style: TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w500),
                ),
                SizedBox(
                  height: 12,
                ),
                Text(
                  "确认要删除文件？",
                  style: TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w400),
                ),
                SizedBox(
                  height: 22,
                ),
                Row(
                  children: [
                    Expanded(
                      child: NeuButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          var res = await Api.deleteTask(file.join(","));
                          if (res['success']) {
                            //获取删除进度
                            timer = Timer.periodic(Duration(seconds: 1), (_) async {
                              //获取删除进度
                              var result = await Api.deleteResult(res['data']['taskid']);
                              if (result['success'] != null && result['success']) {
                                if (result['data']['finished']) {
                                  Util.toast("文件删除完成");
                                  timer.cancel();
                                  timer = null;
                                  setState(() {
                                    selectedFiles = [];
                                    multiSelect = false;
                                  });
                                  String path = paths.join("/").substring(1);
                                  goPath(path);
                                }
                              }
                            });
                          }
                          // if (res['success']) {
                          //   Util.toast("删除完成");
                          //   setState(() {
                          //     selectedFiles = [];
                          //     multiSelect = false;
                          //   });
                          //   String path = paths.join("/").substring(1);
                          //   print(path);
                          //   goPath(path);
                          // }
                        },
                        decoration: NeumorphicDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        bevel: 5,
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          "确认删除",
                          style: TextStyle(fontSize: 18, color: Colors.redAccent),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 16,
                    ),
                    Expanded(
                      child: NeuButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                        },
                        decoration: NeumorphicDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        bevel: 5,
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          "取消",
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileItem(file) {
    FileType fileType = Util.fileType(file['name']);
    String path = file['path'];
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, left: 20, right: 20),
      child: Opacity(
        opacity: 1,
        child: NeuButton(
          onLongPress: () {
            setState(() {
              multiSelect = true;
              selectedFiles.add(file['path']);
            });
          },
          onPressed: () async {
            if (multiSelect) {
              setState(() {
                if (selectedFiles.contains(file['path'])) {
                  selectedFiles.remove(file['path']);
                } else {
                  selectedFiles.add(file['path']);
                }
              });
            } else {
              if (file['isdir']) {
                goPath(file['path']);
              } else {
                switch (fileType) {
                  case FileType.image:
                    //获取当前目录全部图片文件
                    List<String> images = [];
                    int index = 0;
                    for (int i = 0; i < files.length; i++) {
                      if (Util.fileType(files[i]['name']) == FileType.image) {
                        images.add(Util.baseUrl + "/webapi/entry.cgi?path=${Uri.encodeComponent(files[i]['path'])}&size=original&api=SYNO.FileStation.Thumb&method=get&version=2&_sid=${Util.sid}&animate=true");
                        if (files[i]['name'] == file['name']) {
                          index = images.length - 1;
                        }
                      }
                    }
                    Navigator.of(context).push(TransparentMaterialPageRoute(builder: (context) {
                      return PreviewPage(images, index);
                    }));
                    break;
                  case FileType.movie:
                    AndroidIntent intent = AndroidIntent(
                      action: 'action_view',
                      data: Util.baseUrl + "/webapi/entry.cgi?api=SYNO.FileStation.Download&version=1&method=download&path=${Uri.encodeComponent(file['path'])}&mode=open&_sid=${Util.sid}",
                      arguments: {},
                      type: "video/*",
                    );
                    await intent.launch();
                    break;
                  case FileType.music:
                    AndroidIntent intent = AndroidIntent(
                      action: 'action_view',
                      data: Util.baseUrl + "/webapi/entry.cgi?api=SYNO.FileStation.Download&version=1&method=download&path=${Uri.encodeComponent(file['path'])}&mode=open&_sid=${Util.sid}",
                      arguments: {},
                      type: "audio/*",
                    );
                    await intent.launch();
                    break;
                  case FileType.word:
                    AndroidIntent intent = AndroidIntent(
                      action: 'action_view',
                      data: Util.baseUrl + "/webapi/entry.cgi?api=SYNO.FileStation.Download&version=1&method=download&path=${Uri.encodeComponent(file['path'])}&mode=open&_sid=${Util.sid}",
                      arguments: {},
                      type: "application/msword|application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                    );
                    await intent.launch();
                    break;
                  case FileType.excel:
                    AndroidIntent intent = AndroidIntent(
                      action: 'action_view',
                      data: Util.baseUrl + "/webapi/entry.cgi?api=SYNO.FileStation.Download&version=1&method=download&path=${Uri.encodeComponent(file['path'])}&mode=open&_sid=${Util.sid}",
                      arguments: {},
                      type: "application/vnd.ms-excel|application/x-excel|application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    );
                    await intent.launch();
                    break;
                  default:
                    Util.toast("暂不支持打开此类型文件");
                }
              }
            }
          },
          // margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: EdgeInsets.symmetric(vertical: 20),
          decoration: NeumorphicDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          bevel: 8,
          child: Row(
            children: [
              SizedBox(
                width: 20,
              ),
              Hero(
                tag: Util.baseUrl + "/webapi/entry.cgi?path=${Uri.encodeComponent(path)}&size=original&api=SYNO.FileStation.Thumb&method=get&version=2&_sid=${Util.sid}&animate=true",
                child: FileIcon(
                  file['isdir'] ? FileType.folder : fileType,
                  thumb: file['path'],
                ),
              ),
              SizedBox(
                width: 10,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file['name'],
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(
                      height: 5,
                    ),
                    Text(
                      (file['isdir'] ? "" : "${Util.formatSize(file['additional']['size'])}" + " | ") + DateTime.fromMillisecondsSinceEpoch(file['additional']['time']['crtime'] * 1000).format("Y/m/d H:i:s"),
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.headline5.color),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 10,
              ),
              AnimatedSwitcher(
                duration: Duration(milliseconds: 200),
                child: multiSelect
                    ? NeuCard(
                        decoration: NeumorphicDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        curveType: selectedFiles.contains(file['path']) ? CurveType.emboss : CurveType.flat,
                        padding: EdgeInsets.all(5),
                        bevel: 5,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: selectedFiles.contains(file['path'])
                              ? Icon(
                                  CupertinoIcons.checkmark_alt,
                                  color: Color(0xffff9813),
                                )
                              : null,
                        ),
                      )
                    : NeuButton(
                        onPressed: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (context) {
                              return Material(
                                color: Colors.transparent,
                                child: NeuCard(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(22),
                                  bevel: 5,
                                  curveType: CurveType.emboss,
                                  decoration: NeumorphicDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        "选择操作",
                                        style: TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w500),
                                      ),
                                      SizedBox(
                                        height: 12,
                                      ),
                                      Text(
                                        "暂未做二次确认，请谨慎操作！",
                                        style: TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w400),
                                      ),
                                      SizedBox(
                                        height: 22,
                                      ),
                                      NeuButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          deleteFile([file['path']]);
                                        },
                                        decoration: NeumorphicDecoration(
                                          color: Theme.of(context).scaffoldBackgroundColor,
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        bevel: 5,
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Text(
                                          "删除",
                                          style: TextStyle(fontSize: 18, color: Colors.redAccent),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 16,
                                      ),
                                      NeuButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          Navigator.of(context).push(CupertinoPageRoute(builder: (context) {
                                            return FileDetail(file);
                                          }));
                                        },
                                        decoration: NeumorphicDecoration(
                                          color: Theme.of(context).scaffoldBackgroundColor,
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        bevel: 5,
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Text(
                                          "详情",
                                          style: TextStyle(fontSize: 18),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 16,
                                      ),
                                      NeuButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          String url = Util.baseUrl + "/webapi/entry.cgi?api=SYNO.FileStation.Download&version=2&method=download&path=${Uri.encodeComponent(file['path'])}&mode=download&_sid=${Util.sid}";
                                          await Util.download(file['name'], url);
                                          Util.toast("已添加下载任务，请至下载页面查看");
                                          Util.downloadKey.currentState.getData();
                                        },
                                        decoration: NeumorphicDecoration(
                                          color: Theme.of(context).scaffoldBackgroundColor,
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        bevel: 5,
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Text(
                                          "下载",
                                          style: TextStyle(fontSize: 18),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 16,
                                      ),
                                      NeuButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                        },
                                        decoration: NeumorphicDecoration(
                                          color: Theme.of(context).scaffoldBackgroundColor,
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        bevel: 5,
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Text(
                                          "取消",
                                          style: TextStyle(fontSize: 18),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        padding: EdgeInsets.only(left: 5, right: 3, top: 4, bottom: 4),
                        decoration: NeumorphicDecoration(
                          color: Color(0xfff0f0f0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        bevel: 2,
                        child: Icon(
                          CupertinoIcons.right_chevron,
                          size: 18,
                        ),
                      ),
              ),
              SizedBox(
                width: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPathItem(BuildContext context, int index) {
    return Container(
      margin: index == 0 ? EdgeInsets.only(left: 20) : null,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: NeuButton(
        onPressed: () {
          String path = "";
          List<String> items = [];
          if (index == 0) {
            path = "/";
          } else {
            items = paths.getRange(1, index + 1).toList();
            path = "/" + items.join("/");
          }
          goPath(path);
        },
        decoration: NeumorphicDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        bevel: 5,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: index == 0
            ? Icon(
                CupertinoIcons.home,
                size: 16,
              )
            : Text(
                paths[index],
                style: TextStyle(fontSize: 12),
              ),
      ),
    );
  }

  Future<bool> onWillPop() {
    if (multiSelect) {
      setState(() {
        multiSelect = false;
        selectedFiles = [];
      });
    } else {
      if (paths.length > 1) {
        paths.removeLast();
        String path = "";

        if (paths.length == 1) {
          path = "/";
        } else {
          path = paths.join("/").substring(1);
        }
        print(path);
        goPath(path);
      }
    }

    return new Future.value(false);
  }

  Widget _buildProcessList() {
    List<Widget> children = [];
    processing.forEach((key, value) {
      children.add(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(value['path']),
                    flex: 1,
                  ),
                  Icon(Icons.arrow_right_alt_sharp),
                  Expanded(
                    child: Text(value['dest_folder_path']),
                    flex: 1,
                  ),
                  // Text(value['processing_path']),
                ],
              ),
              SizedBox(
                height: 5,
              ),
              NeuCard(
                curveType: CurveType.flat,
                bevel: 10,
                decoration: NeumorphicDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FAProgressBar(
                  backgroundColor: Colors.transparent,
                  changeColorValue: 100,
                  changeProgressColor: Colors.green,
                  progressColor: Colors.blue,
                  size: 20,
                  currentValue: (num.parse("${value['progress']}") * 100).toInt(),
                  displayText: '%',
                ),
              ),
            ],
          ),
        ),
      );
    });
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "文件",
            style: Theme.of(context).textTheme.headline6,
          ),
          brightness: Brightness.light,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          centerTitle: true,
          actions: [
            if (multiSelect)
              Padding(
                padding: EdgeInsets.only(right: 10),
                child: NeuButton(
                  decoration: NeumorphicDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.all(10),
                  bevel: 5,
                  onPressed: () {
                    if (selectedFiles.length == files.length) {
                      selectedFiles = [];
                    } else {
                      selectedFiles = [];
                      files.forEach((file) {
                        selectedFiles.add(file['path']);
                      });
                    }

                    setState(() {});
                  },
                  child: Image.asset(
                    "assets/icons/select_all.png",
                    width: 20,
                    height: 20,
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            Container(
              height: 45,
              color: Theme.of(context).scaffoldBackgroundColor,
              alignment: Alignment.centerLeft,
              child: ListView.separated(
                controller: _pathScrollController,
                itemBuilder: _buildPathItem,
                itemCount: paths.length,
                scrollDirection: Axis.horizontal,
                separatorBuilder: (context, i) {
                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Icon(
                      CupertinoIcons.right_chevron,
                      size: 14,
                    ),
                  );
                },
              ),
            ),
            if (processing.isNotEmpty) _buildProcessList(),
            Expanded(
              child: success
                  ? Stack(
                      children: [
                        ListView.builder(
                          controller: _fileScrollController,
                          padding: EdgeInsets.only(bottom: selectedFiles.length > 0 ? 140 : 20),
                          itemBuilder: (context, i) {
                            return _buildFileItem(files[i]);
                          },
                          itemCount: files.length,
                        ),
                        // if (selectedFiles.length > 0)
                        AnimatedPositioned(
                          bottom: selectedFiles.length > 0 ? 0 : -100,
                          duration: Duration(milliseconds: 200),
                          child: NeuCard(
                            width: MediaQuery.of(context).size.width - 40,
                            margin: EdgeInsets.all(20),
                            padding: EdgeInsets.all(10),
                            height: 62,
                            bevel: 20,
                            curveType: CurveType.flat,
                            decoration: NeumorphicDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    showCupertinoModalPopup(
                                      context: context,
                                      builder: (context) {
                                        return SelectFolder(
                                          multi: false,
                                        );
                                      },
                                    ).then((folder) async {
                                      if (folder != null && folder.length == 1) {
                                        var res = await Api.copyMoveTask(selectedFiles, folder[0], true);
                                        if (res['success']) {
                                          setState(() {
                                            selectedFiles = [];
                                            multiSelect = false;
                                          });
                                          //获取移动进度
                                          timer = Timer.periodic(Duration(seconds: 1), (_) async {
                                            //获取移动进度
                                            var result = await Api.copyMoveResult(res['data']['taskid']);
                                            if (result['success'] != null && result['success']) {
                                              if (result['data']['finished']) {
                                                Util.toast("文件移动完成");
                                                timer.cancel();
                                                timer = null;

                                                String path = paths.join("/").substring(1);
                                                goPath(path);
                                                Future.delayed(Duration(seconds: 5)).then((value) {
                                                  setState(() {
                                                    processing.remove(res['data']['taskid']);
                                                  });
                                                });
                                              }
                                            }
                                          });
                                        }
                                      }
                                    });
                                  },
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        "assets/icons/move.png",
                                        width: 25,
                                      ),
                                      Text(
                                        "移动到",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    showCupertinoModalPopup(
                                      context: context,
                                      builder: (context) {
                                        return SelectFolder(
                                          multi: false,
                                        );
                                      },
                                    ).then((folder) async {
                                      if (folder != null && folder.length == 1) {
                                        var res = await Api.copyMoveTask(selectedFiles, folder[0], false);
                                        if (res['success']) {
                                          setState(() {
                                            selectedFiles = [];
                                            multiSelect = false;
                                          });
                                          //获取复制进度
                                          timer = Timer.periodic(Duration(seconds: 1), (_) async {
                                            //获取复制进度
                                            var result = await Api.copyMoveResult(res['data']['taskid']);
                                            if (result['success'] != null && result['success']) {
                                              print(result);
                                              setState(() {
                                                processing[res['data']['taskid']] = result['data'];
                                              });
                                              if (result['data']['finished']) {
                                                Util.toast("文件复制完成");
                                                timer.cancel();
                                                timer = null;

                                                String path = paths.join("/").substring(1);
                                                goPath(path);
                                                Future.delayed(Duration(seconds: 5)).then((value) {
                                                  setState(() {
                                                    processing.remove(res['data']['taskid']);
                                                  });
                                                });
                                              }
                                            }
                                          });
                                        }
                                      }
                                    });
                                  },
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        "assets/icons/copy.png",
                                        width: 25,
                                      ),
                                      Text(
                                        "复制到",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Util.toast("敬请期待");
                                  },
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        "assets/icons/archive.png",
                                        width: 25,
                                      ),
                                      Text(
                                        "压缩",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    deleteFile(selectedFiles);
                                  },
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        "assets/icons/delete.png",
                                        width: 25,
                                      ),
                                      Text(
                                        "删除",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                        if (loading)
                          Container(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height,
                            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.7),
                            child: Center(
                              child: NeuCard(
                                padding: EdgeInsets.all(50),
                                curveType: CurveType.flat,
                                decoration: NeumorphicDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                bevel: 20,
                                child: CupertinoActivityIndicator(
                                  radius: 14,
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("$msg"),
                          SizedBox(
                            height: 20,
                          ),
                          SizedBox(
                            width: 200,
                            child: NeuButton(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: NeumorphicDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              bevel: 5,
                              onPressed: () {
                                String path = paths.join("/").substring(1);
                                goPath(path);
                              },
                              child: Text(
                                ' 刷新 ',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: SizedBox(
          width: 60,
          height: 60,
          child: NeuButton(
            decoration: NeumorphicDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(50),
            ),
            onPressed: () {
              Navigator.of(context).push(CupertinoPageRoute(builder: (context) {
                return Upload(paths.join("/").substring(1));
              }));
            },
            child: Icon(Icons.upload_file),
          ),
        ),
      ),
    );
  }
}
