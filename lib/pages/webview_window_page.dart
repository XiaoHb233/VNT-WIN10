import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:vnt_app/theme/app_theme.dart';

/// WebView 窗口页面 - 在新窗口中显示 WebView，避免主窗口掉帧
class WebViewWindowPage extends StatefulWidget {
  final WindowController windowController;
  final Map<String, dynamic> arguments;

  const WebViewWindowPage({
    super.key,
    required this.windowController,
    required this.arguments,
  });

  @override
  State<WebViewWindowPage> createState() => _WebViewWindowPageState();
}

class _WebViewWindowPageState extends State<WebViewWindowPage> {
  WebviewController? _webViewController;
  bool _isLoading = true;
  String _currentUrl = '';
  String _errorMessage = '';

  // 从参数中获取配置
  String get _title => widget.arguments['title'] ?? 'WebView';
  String get _url => widget.arguments['url'] ?? '';
  String get _username => widget.arguments['username'] ?? '';
  String get _password => widget.arguments['password'] ?? '';
  String get _usernameId => widget.arguments['usernameId'] ?? 'username';
  String get _passwordId => widget.arguments['passwordId'] ?? 'password';

  @override
  void initState() {
    super.initState();
    _initWebView();
    _setWindowTitle();
  }

  @override
  void dispose() {
    _webViewController?.dispose();
    super.dispose();
  }

  /// 设置窗口标题
  Future<void> _setWindowTitle() async {
    await widget.windowController.setTitle(_title);
  }

  /// 初始化 WebView
  Future<void> _initWebView() async {
    if (_url.isEmpty) {
      setState(() {
        _errorMessage = 'URL 不能为空';
        _isLoading = false;
      });
      return;
    }

    try {
      final controller = WebviewController();
      _webViewController = controller;

      // 初始化 WebView
      await controller.initialize();

      // 设置用户代理（模拟 Chrome）
      await controller.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

      // 监听加载状态
      controller.loadingState.listen((state) {
        if (mounted) {
          setState(() {
            _isLoading = state == LoadingState.loading;
          });
          // 页面加载完成后，检测是否是登录页面并自动填充
          if (state == LoadingState.navigationCompleted) {
            _checkAndAutoFill(controller);
          }
        }
      });

      // 监听导航事件
      controller.url.listen((currentUrl) {
        if (mounted) {
          setState(() {
            _currentUrl = currentUrl;
          });
        }
      });

      // 加载 URL
      await controller.loadUrl(_url);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'WebView 初始化失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// 检测当前页面是否是登录页面，如果是则自动填充
  Future<void> _checkAndAutoFill(WebviewController controller) async {
    // 如果没有配置用户名密码，跳过
    if (_username.isEmpty || _password.isEmpty) return;

    // 延迟确保页面元素已加载
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      // 检测页面是否存在登录表单元素
      final result = await controller.executeScript('''
        (function() {
          var usernameInput = document.getElementById('$_usernameId');
          var passwordInput = document.getElementById('$_passwordId');
          return (usernameInput !== null && passwordInput !== null) ? 'login_page' : 'not_login';
        })();
      ''');

      if (result == 'login_page') {
        debugPrint('检测到登录页面，开始自动填充');
        // 执行自动填充
        await controller.executeScript('''
          (function() {
            var usernameInput = document.getElementById('$_usernameId');
            var passwordInput = document.getElementById('$_passwordId');
            if (usernameInput) {
              usernameInput.value = '${_escapeJsString(_username)}';
              usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
              usernameInput.dispatchEvent(new Event('change', { bubbles: true }));
            }
            if (passwordInput) {
              passwordInput.value = '${_escapeJsString(_password)}';
              passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
              passwordInput.dispatchEvent(new Event('change', { bubbles: true }));
            }
          })();
        ''');
      }
    } catch (e) {
      debugPrint('自动填充检测失败: $e');
    }
  }

  /// 转义 JavaScript 字符串
  String _escapeJsString(String str) {
    return str
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }

  /// 刷新当前页面
  Future<void> _reloadWebView() async {
    if (_webViewController == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      await _webViewController!.reload();
    } catch (e) {
      setState(() {
        _errorMessage = '刷新失败: $e';
      });
    }
  }

  /// WebView后退
  Future<void> _goBack() async {
    if (_webViewController == null) {
      _closeWindow();
      return;
    }
    try {
      // webview_windows 插件没有 canGoBack 方法，直接尝试 goBack
      await _webViewController!.goBack();
    } catch (e) {
      // goBack 失败（已经在第一页），关闭窗口
      debugPrint('无法后退，关闭窗口: $e');
      _closeWindow();
    }
  }

  /// 关闭窗口
  void _closeWindow() {
    widget.windowController.close();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: _buildTitleBar(isDark, primaryColor),
      ),
      body: _buildBody(isDark, primaryColor),
    );
  }

  /// 构建自定义标题栏
  Widget _buildTitleBar(bool isDark, Color primaryColor) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 后退按钮
          _buildToolbarButton(
            icon: Icons.arrow_back,
            onPressed: _goBack,
            tooltip: '返回',
            isDark: isDark,
          ),
          // 刷新按钮
          _buildToolbarButton(
            icon: Icons.refresh,
            onPressed: _reloadWebView,
            tooltip: '刷新',
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          // 标题
          Expanded(
            child: Text(
              _title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // URL 显示
          if (_currentUrl.isNotEmpty)
            Expanded(
              flex: 2,
              child: Text(
                _currentUrl,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(width: 8),
          // 关闭按钮
          _buildToolbarButton(
            icon: Icons.close,
            onPressed: _closeWindow,
            tooltip: '关闭',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  /// 构建工具栏按钮
  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建主体内容
  Widget _buildBody(bool isDark, Color primaryColor) {
    if (_errorMessage.isNotEmpty) {
      return _buildErrorView(isDark);
    }

    return Stack(
      children: [
        // WebView
        if (_webViewController != null)
          Webview(
            _webViewController!,
            permissionRequested: (url, permission, isUserInitiated) async {
              debugPrint('[WebView Permission] URL: $url, Permission: $permission, UserInitiated: $isUserInitiated');
              return WebviewPermissionDecision.allow;
            },
          ),

        // 加载指示器
        if (_isLoading)
          Container(
            color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '正在加载页面...',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _currentUrl.isEmpty ? _url : _currentUrl,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 构建错误视图
  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initWebView,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
