import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/pages/webview_window_page.dart';

/// 窗口类型枚举
enum WindowType {
  main,    // 主窗口
  webview, // WebView 窗口
}

/// 窗口参数常量
class WindowArgs {
  static const String type = 'windowType';
  static const String title = 'title';
  static const String url = 'url';
  static const String username = 'username';
  static const String password = 'password';
  static const String usernameId = 'usernameId';
  static const String passwordId = 'passwordId';
}

/// 多窗口管理器
class MultiWindowManager {
  static final MultiWindowManager _instance = MultiWindowManager._internal();
  factory MultiWindowManager() => _instance;
  MultiWindowManager._internal() {
    // 初始化全局方法处理器
    _initMethodHandler();
  }

  // 存储已创建的 WebView 窗口 ID，用于复用
  final Map<String, int> _webviewWindows = {};
  
  // 标记是否已初始化处理器
  bool _handlerInitialized = false;

  /// 创建 WebView 窗口
  /// 
  /// [title] 窗口标题
  /// [url] 要加载的 URL
  /// [username] 用户名（用于自动填充）
  /// [password] 密码（用于自动填充）
  /// [usernameId] 用户名输入框元素 ID
  /// [passwordId] 密码输入框元素 ID
  /// [width] 窗口宽度，默认 1200
  /// [height] 窗口高度，默认 800
  Future<void> createWebViewWindow({
    required String title,
    required String url,
    String username = '',
    String password = '',
    String usernameId = 'username',
    String passwordId = 'password',
    double width = 1200,
    double height = 800,
  }) async {
    // 检查是否已存在相同 URL 的窗口，如果存在则激活它
    final existingWindowId = _webviewWindows[url];
    if (existingWindowId != null) {
      try {
        final controller = WindowController.fromWindowId(existingWindowId);
        // 尝试激活窗口（如果窗口已关闭会抛出异常）
        await controller.show();
        return;
      } catch (e) {
        // 窗口可能已关闭，从 map 中移除
        debugPrint('窗口已关闭，重新创建: $e');
        _webviewWindows.remove(url);
      }
    }

    // 创建新窗口
    final window = await DesktopMultiWindow.createWindow(jsonEncode({
      WindowArgs.type: WindowType.webview.name,
      WindowArgs.title: title,
      WindowArgs.url: url,
      WindowArgs.username: username,
      WindowArgs.password: password,
      WindowArgs.usernameId: usernameId,
      WindowArgs.passwordId: passwordId,
    }));

    // 设置窗口标题
    await window.setTitle(title);
    
    // 设置窗口大小和位置（居中）
    final screenWidth = 1920.0; // 默认屏幕宽度
    final screenHeight = 1080.0; // 默认屏幕高度
    final x = (screenWidth - width) / 2;
    final y = (screenHeight - height) / 2;
    
    await window.setFrame(
      Rect.fromLTWH(x, y, width, height),
    );
    
    // 居中显示
    await window.center();
    
    // 显示窗口
    await window.show();

    // 保存窗口 ID
    _webviewWindows[url] = window.windowId;
  }

  /// 初始化全局方法处理器
  void _initMethodHandler() {
    if (_handlerInitialized) return;
    _handlerInitialized = true;
    
    // 使用 DesktopMultiWindow.setMethodHandler 监听所有窗口事件
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      // 查找对应的 URL 并移除
      String? urlToRemove;
      for (final entry in _webviewWindows.entries) {
        if (entry.value == fromWindowId) {
          urlToRemove = entry.key;
          break;
        }
      }
      if (urlToRemove != null && call.method == 'onClose') {
        _webviewWindows.remove(urlToRemove);
        debugPrint('窗口已关闭，移除缓存: $urlToRemove');
      }
      return null;
    });
  }

  /// 关闭所有 WebView 窗口
  Future<void> closeAllWebViewWindows() async {
    for (final entry in _webviewWindows.entries.toList()) {
      try {
        final controller = WindowController.fromWindowId(entry.value);
        await controller.close();
      } catch (e) {
        debugPrint('关闭窗口失败: $e');
      }
    }
    _webviewWindows.clear();
  }
}

/// 子窗口入口点
/// 
/// 这个函数在子窗口创建时被调用
void subWindowEntryPoint(List<String> args) async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 解析窗口参数
  // args[0] = windowId
  // args[1] = jsonArgs
  final windowId = int.parse(args[0]);
  final windowController = WindowController.fromWindowId(windowId);
  
  Map<String, dynamic> arguments = {};
  if (args.length > 1) {
    try {
      arguments = jsonDecode(args[1]) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('解析窗口参数失败: $e');
    }
  }

  // 获取窗口类型
  final windowTypeStr = arguments[WindowArgs.type] as String? ?? WindowType.webview.name;
  final windowType = WindowType.values.firstWhere(
    (e) => e.name == windowTypeStr,
    orElse: () => WindowType.webview,
  );

  // 根据窗口类型构建不同的页面
  Widget windowWidget;
  switch (windowType) {
    case WindowType.webview:
      windowWidget = WebViewWindowPage(
        windowController: windowController,
        arguments: arguments,
      );
      break;
    default:
      windowWidget = _buildDefaultWindow(arguments);
  }

  // 运行子窗口应用
  runApp(SubWindowApp(
    windowController: windowController,
    child: windowWidget,
  ));
}

/// 构建默认窗口
Widget _buildDefaultWindow(Map<String, dynamic> arguments) {
  return Scaffold(
    body: Center(
      child: Text('未知窗口类型: ${arguments[WindowArgs.type]}'),
    ),
  );
}

/// 子窗口应用
class SubWindowApp extends StatelessWidget {
  final WindowController windowController;
  final Widget child;

  const SubWindowApp({
    super.key,
    required this.windowController,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VNT App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primaryColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primaryColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: child,
    );
  }
}
