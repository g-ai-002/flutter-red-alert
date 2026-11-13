import 'package:flutter/material.dart';

/// 打开一个整页路由；页面跳转统一走这里，避免各处重复拼装 [MaterialPageRoute]。
Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));
