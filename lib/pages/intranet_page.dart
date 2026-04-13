import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/utils/responsive_utils.dart';
import 'package:vnt_app/window_manager.dart';

/// 内网访问页面 - 用户端和管理端双入口，弹出新窗口显示WebView
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

  @override
  void initState() {
    super.initState();
    _loadConfigs();
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

  /// 打开用户端页面（弹出新窗口）
  Future<void> _openUserPage() async {
    await MultiWindowManager().createWebViewWindow(
      title: '用户端 - VNT App',
      url: _buildUserUrl(),
      username: _userUsername,
      password: _userPassword,
      usernameId: 'login-username',
      passwordId: 'login-password',
      width: 1280,
      height: 800,
    );
  }

  /// 打开管理端页面（弹出新窗口）
  Future<void> _openAdminPage() async {
    await MultiWindowManager().createWebViewWindow(
      title: '管理端 - VNT App',
      url: _buildAdminUrl(),
      username: _adminUsername,
      password: _adminPassword,
      usernameId: 'username',
      passwordId: 'password',
      width: 1280,
      height: 800,
    );
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
        child: _buildEntryContent(isDark, primaryColor),
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
