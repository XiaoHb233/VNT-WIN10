import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/utils/responsive_utils.dart';

/// Windows WebView 页面 - 用于内网访问
class IntranetWebViewPage extends StatefulWidget {
  final String title;
  final String url;

  const IntranetWebViewPage({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<IntranetWebViewPage> createState() => _IntranetWebViewPageState();
}

class _IntranetWebViewPageState extends State<IntranetWebViewPage> {
  final WebviewController _controller = WebviewController();
  bool _isLoading = true;
  String _currentUrl = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      // 初始化 WebView
      await _controller.initialize();

      // 设置用户代理（模拟 Chrome）
      await _controller.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

      // 启用开发者工具（调试用，发布时可关闭）
      await _controller.openDevTools();

      // 监听加载状态
      _controller.loadingState.listen((state) {
        if (mounted) {
          setState(() {
            _isLoading = state == LoadingState.loading;
          });
        }
      });

      // 监听导航事件
      _controller.url.listen((url) {
        if (mounted) {
          setState(() {
            _currentUrl = url;
          });
        }
      });

      // 监听 WebView 消息（用于调试）
      _controller.webMessage.listen((message) {
        debugPrint('[WebView Message] $message');
      });

      // 加载初始 URL
      await _controller.loadUrl(widget.url);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'WebView 初始化失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      await _controller.reload();
    } catch (e) {
      setState(() {
        _errorMessage = '刷新失败: $e';
      });
    }
  }

  Future<void> _goBack() async {
    try {
      await _controller.goBack();
    } catch (e) {
      // 无法返回时关闭页面
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
          onPressed: _goBack,
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            fontSize: context.fontMedium,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
            onPressed: _reload,
            tooltip: '刷新',
          ),
          IconButton(
            icon: Icon(
              Icons.open_in_browser,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
            onPressed: () {
              // 在外部浏览器打开
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('外部浏览器'),
                  content: Text('当前地址:\n$_currentUrl'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              );
            },
            tooltip: '查看地址',
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView 内容
          if (_errorMessage.isEmpty)
            Webview(
              _controller,
              permissionRequested: (url, permission, isUserInitiated) async {
                debugPrint('[WebView Permission] URL: $url, Permission: $permission, UserInitiated: $isUserInitiated');
                // 允许所有权限请求（文件上传、摄像头等）
                return WebviewPermissionDecision.allow;
              },
            ),

          // 加载指示器
          if (_isLoading && _errorMessage.isEmpty)
            Container(
              color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: primaryColor,
                    ),
                    SizedBox(height: context.spacingMedium),
                    Text(
                      '正在加载页面...',
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                    SizedBox(height: context.spacingSmall),
                    Text(
                      _currentUrl,
                      style: TextStyle(
                        fontSize: context.fontSmall,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

          // 错误显示
          if (_errorMessage.isNotEmpty)
            Container(
              color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
              padding: EdgeInsets.all(context.spacingLarge),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: context.iconXLarge,
                      color: Colors.red,
                    ),
                    SizedBox(height: context.spacingMedium),
                    Text(
                      '加载失败',
                      style: TextStyle(
                        fontSize: context.fontLarge,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    SizedBox(height: context.spacingSmall),
                    Text(
                      _errorMessage,
                      style: TextStyle(
                        fontSize: context.fontSmall,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: context.spacingLarge),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
