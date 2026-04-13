import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/utils/responsive_utils.dart';

/// 内网访问页面 - 用户端和管理端双入口，嵌入WebView显示
class IntranetPage extends StatefulWidget {
  const IntranetPage({super.key});

  @override
  State<IntranetPage> createState() => _IntranetPageState();
}

class _IntranetPageState extends State<IntranetPage> {
  // 配置存储键
  static const String _userIpKey = 'intranet_user_ip';
  static const String _userPortKey = 'intranet_user_port';
  static const String _userUsernameKey = 'intranet_user_username';
  static const String _userPasswordKey = 'intranet_user_password';
  static const String _adminIpKey = 'intranet_admin_ip';
  static const String _adminPortKey = 'intranet_admin_port';
  static const String _adminUsernameKey = 'intranet_admin_username';
  static const String _adminPasswordKey = 'intranet_admin_password';

  // 默认配置
  String _userIp = '127.0.0.1';
  String _userPort = '8080';
  String _userUsername = '';
  String _userPassword = '';
  String _adminIp = '127.0.0.1';
  String _adminPort = '8081';
  String _adminUsername = '';
  String _adminPassword = '';

  // WebView 相关状态
  WebviewController? _webViewController;
  bool _isWebViewLoading = false;
  String _currentUrl = '';
  String _webViewTitle = '';
  String _errorMessage = '';
  bool _showWebView = false;
  bool _isUserEnd = true; // 当前是否是用户端

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  @override
  void dispose() {
    _webViewController?.dispose();
    super.dispose();
  }

  Future<void> _loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userIp = prefs.getString(_userIpKey) ?? '127.0.0.1';
      _userPort = prefs.getString(_userPortKey) ?? '8080';
      _userUsername = prefs.getString(_userUsernameKey) ?? '';
      _userPassword = prefs.getString(_userPasswordKey) ?? '';
      _adminIp = prefs.getString(_adminIpKey) ?? '127.0.0.1';
      _adminPort = prefs.getString(_adminPortKey) ?? '8081';
      _adminUsername = prefs.getString(_adminUsernameKey) ?? '';
      _adminPassword = prefs.getString(_adminPasswordKey) ?? '';
    });
  }

  Future<void> _saveUserConfig(String ip, String port, String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIpKey, ip);
    await prefs.setString(_userPortKey, port);
    await prefs.setString(_userUsernameKey, username);
    await prefs.setString(_userPasswordKey, password);
    setState(() {
      _userIp = ip;
      _userPort = port;
      _userUsername = username;
      _userPassword = password;
    });
  }

  Future<void> _saveAdminConfig(String ip, String port, String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adminIpKey, ip);
    await prefs.setString(_adminPortKey, port);
    await prefs.setString(_adminUsernameKey, username);
    await prefs.setString(_adminPasswordKey, password);
    setState(() {
      _adminIp = ip;
      _adminPort = port;
      _adminUsername = username;
      _adminPassword = password;
    });
  }

  String _buildUserUrl() {
    // 打开主页面，如果未登录后端会返回登录页面
    return 'http://$_userIp:$_userPort/index.html';
  }

  String _buildAdminUrl() {
    // 打开管理后台，如果未登录后端会返回登录页面
    return 'http://$_adminIp:$_adminPort/admin/dashboard.html';
  }

  /// 打开用户端页面（嵌入WebView）
  void _openUserPage() {
    _isUserEnd = true;
    _openWebView('用户端', _buildUserUrl(), _userUsername, _userPassword);
  }

  /// 打开管理端页面（嵌入WebView）
  void _openAdminPage() {
    _isUserEnd = false;
    _openWebView('管理端', _buildAdminUrl(), _adminUsername, _adminPassword);
  }

  /// 初始化并加载WebView
  Future<void> _openWebView(String title, String url, String username, String password) async {
    // 如果已经有WebView，复用并只切换URL，保留缓存
    if (_webViewController != null) {
      setState(() {
        _showWebView = true;
        _isWebViewLoading = true;
        _webViewTitle = title;
        _currentUrl = url;
        _errorMessage = '';
      });
      // 复用现有WebView，只加载新URL，保留Cookie和缓存
      await _webViewController!.loadUrl(url);
      return;
    }

    setState(() {
      _showWebView = true;
      _isWebViewLoading = true;
      _webViewTitle = title;
      _currentUrl = url;
      _errorMessage = '';
    });

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
            _isWebViewLoading = state == LoadingState.loading;
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

      // 监听 WebView 消息（用于调试）
      controller.webMessage.listen((message) {
        debugPrint('[WebView Message] $message');
      });

      // 加载 URL
      await controller.loadUrl(url);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'WebView 初始化失败: $e';
          _isWebViewLoading = false;
        });
      }
    }
  }



  /// 检测当前页面是否是登录页面，如果是则自动填充
  Future<void> _checkAndAutoFill(WebviewController controller) async {
    // 延迟确保页面元素已加载
    await Future.delayed(const Duration(milliseconds: 800));
    try {
      // 根据当前端获取对应的用户名密码和元素ID
      final usernameId = _isUserEnd ? 'login-username' : 'username';
      final passwordId = _isUserEnd ? 'login-password' : 'password';
      final username = _isUserEnd ? _userUsername : _adminUsername;
      final password = _isUserEnd ? _userPassword : _adminPassword;
      
      if (username.isEmpty || password.isEmpty) return;
      
      // 检测页面是否存在登录表单元素
      final result = await controller.executeScript('''
        (function() {
          var usernameInput = document.getElementById('$usernameId');
          var passwordInput = document.getElementById('$passwordId');
          return (usernameInput !== null && passwordInput !== null) ? 'login_page' : 'not_login';
        })();
      ''');
      
      if (result == 'login_page') {
        debugPrint('检测到登录页面，开始自动填充');
        // 执行自动填充
        await controller.executeScript('''
          (function() {
            var usernameInput = document.getElementById('$usernameId');
            var passwordInput = document.getElementById('$passwordId');
            if (usernameInput) {
              usernameInput.value = '$username';
              usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
              usernameInput.dispatchEvent(new Event('change', { bubbles: true }));
            }
            if (passwordInput) {
              passwordInput.value = '$password';
              passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
              passwordInput.dispatchEvent(new Event('change', { bubbles: true }));
            }
          })();
        ''');
      }
    } catch (e) {
      debugPrint('自动填充检测失败: \$e');
    }
  }

  /// 关闭WebView，返回入口选择页面（隐藏但不销毁，保留缓存）
  void _closeWebView() {
    setState(() {
      _showWebView = false;
      _webViewTitle = '';
      _currentUrl = '';
      _errorMessage = '';
    });
    // 重要：不调用 dispose()，保持 WebView 实例存活
    // 这样 Cookie 和登录状态会被保留，下次打开时仍然有效
  }

  /// 刷新当前页面
  Future<void> _reloadWebView() async {
    if (_webViewController == null) return;
    setState(() {
      _isWebViewLoading = true;
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
      _closeWebView();
      return;
    }
    try {
      // 尝试返回上一页
      await _webViewController!.goBack();
    } catch (e) {
      // WebView 无法返回时（已经在第一页或出错），关闭WebView返回入口页面
      _closeWebView();
    }
  }

  void _showUserConfigDialog() {
    final ipController = TextEditingController(text: _userIp);
    final portController = TextEditingController(text: _userPort);
    final usernameController = TextEditingController(text: _userUsername);
    final passwordController = TextEditingController(text: _userPassword);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCardBackground
            : AppTheme.lightCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.cardRadius),
        ),
        title: Text(
          '用户端配置',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkTextPrimary
                : AppTheme.lightTextPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  labelText: '服务器地址',
                  hintText: '例如: 127.0.0.1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.cardRadius),
                  ),
                ),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              SizedBox(height: context.spacingMedium),
              TextField(
                controller: portController,
                decoration: InputDecoration(
                  labelText: '端口',
                  hintText: '例如: 8080',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.cardRadius),
                  ),
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              SizedBox(height: context.spacingMedium),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: '用户名（可选，用于自动填充）',
                  hintText: '请输入用户名',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.cardRadius),
                  ),
                ),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              SizedBox(height: context.spacingMedium),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: '密码（可选，用于自动填充）',
                  hintText: '请输入密码',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.cardRadius),
                  ),
                ),
                obscureText: true,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              String ip = ipController.text.trim();
              String port = portController.text.trim();
              String username = usernameController.text.trim();
              String password = passwordController.text.trim();

              // 清理输入
              ip = ip.replaceAll(RegExp(r'^https?://'), '');
              ip = ip.split('/')[0];
              ip = ip.split(':')[0];

              if (ip.isEmpty || port.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写服务器地址和端口')),
                );
                return;
              }

              Navigator.pop(context);
              await _saveUserConfig(ip, port, username, password);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('用户端配置已保存')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.buttonRadius),
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAdminConfigDialog() {
    final ipController = TextEditingController(text: _adminIp);
    final portController = TextEditingController(text: _adminPort);
    final usernameController = TextEditingController(text: _adminUsername);
    final passwordController = TextEditingController(text: _adminPassword);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCardBackground
            : AppTheme.lightCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.cardRadius),
        ),
        title: Text(
          '管理端配置',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkTextPrimary
                : AppTheme.lightTextPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  labelText: '服务器地址',
                  hintText: '例如: 127.0.0.1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.cardRadius),
                  ),
                ),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              SizedBox(height: context.spacingMedium),
              TextField(
                controller: portController,
                decoration: InputDecoration(
                  labelText: '端口',
                  hintText: '例如: 8081',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.cardRadius),
                  ),
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              SizedBox(height: context.spacingMedium),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: '用户名（可选，用于自动填充）',
                  hintText: '请输入用户名',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.cardRadius),
                  ),
                ),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              SizedBox(height: context.spacingMedium),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: '密码（可选，用于自动填充）',
                  hintText: '请输入密码',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.cardRadius),
                  ),
                ),
                obscureText: true,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              String ip = ipController.text.trim();
              String port = portController.text.trim();
              String username = usernameController.text.trim();
              String password = passwordController.text.trim();

              // 清理输入
              ip = ip.replaceAll(RegExp(r'^https?://'), '');
              ip = ip.split('/')[0];
              ip = ip.split(':')[0];

              if (ip.isEmpty || port.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写服务器地址和端口')),
                );
                return;
              }

              Navigator.pop(context);
              await _saveAdminConfig(ip, port, username, password);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('管理端配置已保存')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.buttonRadius),
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        child: _showWebView
            ? _buildWebViewContent(isDark, primaryColor)
            : _buildEntryContent(isDark, primaryColor),
      ),
    );
  }

  /// 构建入口选择页面内容
  Widget _buildEntryContent(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 页面头部
          _buildHeader(isDark, primaryColor),
          SizedBox(height: context.spacingLarge),

          // 入口卡片
          _buildEntryCard(
            isDark: isDark,
            primaryColor: primaryColor,
            title: '用户端',
            subtitle: '查询服务',
            icon: Icons.person_outline,
            ip: _userIp,
            port: _userPort,
            username: _userUsername,
            onTap: _openUserPage,
            onConfigTap: _showUserConfigDialog,
          ),
          SizedBox(height: context.spacingMedium),

          _buildEntryCard(
            isDark: isDark,
            primaryColor: primaryColor,
            title: '管理端',
            subtitle: '后台管理',
            icon: Icons.admin_panel_settings_outlined,
            ip: _adminIp,
            port: _adminPort,
            username: _adminUsername,
            onTap: _openAdminPage,
            onConfigTap: _showAdminConfigDialog,
          ),
        ],
      ),
    );
  }

  /// 构建WebView内容区域
  Widget _buildWebViewContent(bool isDark, Color primaryColor) {
    return Column(
      children: [
        // WebView 工具栏
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacingSmall,
              vertical: context.spacingSmall,
            ),
            child: Row(
              children: [
                // 返回按钮（返回到入口选择页面）
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                  onPressed: _goBack,
                  tooltip: '返回',
                ),
                SizedBox(width: context.spacingSmall),
                // 标题
                Expanded(
                  child: Text(
                    _webViewTitle,
                    style: TextStyle(
                      fontSize: context.fontMedium,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 刷新按钮
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                  onPressed: _reloadWebView,
                  tooltip: '刷新',
                ),
                // 关闭按钮
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                  onPressed: _closeWebView,
                  tooltip: '关闭',
                ),
              ],
            ),
          ),
        ),
        // WebView 内容区域
        Expanded(
          child: Stack(
            children: [
              // WebView
              if (_errorMessage.isEmpty && _webViewController != null)
                Webview(
                  _webViewController!,
                  permissionRequested: (url, permission, isUserInitiated) async {
                    debugPrint('[WebView Permission] URL: $url, Permission: $permission, UserInitiated: $isUserInitiated');
                    return WebviewPermissionDecision.allow;
                  },
                ),

              // 加载指示器
              if (_isWebViewLoading && _errorMessage.isEmpty)
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
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: context.spacingLarge),
                          child: Text(
                            _currentUrl,
                            style: TextStyle(
                              fontSize: context.fontSmall,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
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
                          onPressed: _reloadWebView,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        SizedBox(height: context.spacingMedium),
                        TextButton(
                          onPressed: _closeWebView,
                          child: Text(
                            '返回入口页面',
                            style: TextStyle(
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark, Color primaryColor) {
    return Row(
      children: [
        Container(
          width: context.iconXLarge,
          height: context.iconXLarge,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(context.cardRadius),
          ),
          child: Icon(
            Icons.language,
            color: Colors.white,
            size: context.iconLarge,
          ),
        ),
        SizedBox(width: context.spacingMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '内网访问',
                style: TextStyle(
                  fontSize: context.fontXLarge,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              SizedBox(height: context.spacingSmall / 2),
              Text(
                '访问本地内网服务',
                style: TextStyle(
                  fontSize: context.fontSmall,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard({
    required bool isDark,
    required Color primaryColor,
    required String title,
    required String subtitle,
    required IconData icon,
    required String ip,
    required String port,
    required String username,
    required VoidCallback onTap,
    required VoidCallback onConfigTap,
  }) {
    return Card(
      elevation: 0,
      color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.cardRadius),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.cardRadius),
        child: Padding(
          padding: EdgeInsets.all(context.spacingMedium),
          child: Row(
            children: [
              Container(
                width: context.iconXLarge,
                height: context.iconXLarge,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.2), primaryColor.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(context.cardRadius),
                ),
                child: Icon(
                  icon,
                  color: primaryColor,
                  size: context.iconLarge,
                ),
              ),
              SizedBox(width: context.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: context.fontLarge,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    SizedBox(height: context.spacingSmall / 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: context.fontSmall,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                    SizedBox(height: context.spacingSmall),
                    Row(
                      children: [
                        Icon(
                          Icons.computer,
                          size: context.iconSmall,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                        SizedBox(width: context.spacingSmall / 2),
                        Text(
                          '$ip:$port',
                          style: TextStyle(
                            fontSize: context.fontSmall,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    if (username.isNotEmpty)
                      SizedBox(height: context.spacingSmall),
                    if (username.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: context.iconSmall,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                          SizedBox(width: context.spacingSmall / 2),
                          Text(
                            '用户: $username',
                            style: TextStyle(
                              fontSize: context.fontSmall,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 配置按钮
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onConfigTap,
                      borderRadius: BorderRadius.circular(context.buttonRadius),
                      child: Container(
                        padding: EdgeInsets.all(context.spacingSmall),
                        child: Icon(
                          Icons.settings,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          size: context.iconMedium,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: context.spacingSmall),
                  // 进入按钮
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacingMedium,
                      vertical: context.spacingSmall,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(context.buttonRadius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '进入',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: context.fontSmall,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: context.spacingSmall / 2),
                        Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: context.iconSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
