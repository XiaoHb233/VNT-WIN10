import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/utils/responsive_utils.dart';
import 'intranet_webview_page.dart';

/// 内网访问页面 - 用户端和管理端双入口
class IntranetPage extends StatefulWidget {
  const IntranetPage({super.key});

  @override
  State<IntranetPage> createState() => _IntranetPageState();
}

class _IntranetPageState extends State<IntranetPage> {
  // 配置存储键
  static const String _userIpKey = 'intranet_user_ip';
  static const String _userPortKey = 'intranet_user_port';
  static const String _adminIpKey = 'intranet_admin_ip';
  static const String _adminPortKey = 'intranet_admin_port';

  // 默认配置
  String _userIp = '127.0.0.1';
  String _userPort = '8080';
  String _adminIp = '127.0.0.1';
  String _adminPort = '8081';

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
      _adminIp = prefs.getString(_adminIpKey) ?? '127.0.0.1';
      _adminPort = prefs.getString(_adminPortKey) ?? '8081';
    });
  }

  Future<void> _saveUserConfig(String ip, String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIpKey, ip);
    await prefs.setString(_userPortKey, port);
    setState(() {
      _userIp = ip;
      _userPort = port;
    });
  }

  Future<void> _saveAdminConfig(String ip, String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adminIpKey, ip);
    await prefs.setString(_adminPortKey, port);
    setState(() {
      _adminIp = ip;
      _adminPort = port;
    });
  }

  String _buildUserUrl() {
    return 'http://$_userIp:$_userPort/index.html';
  }

  String _buildAdminUrl() {
    return 'http://$_adminIp:$_adminPort/admin/dashboard.html';
  }

  void _openUserPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IntranetWebViewPage(
          title: '用户端',
          url: _buildUserUrl(),
        ),
      ),
    );
  }

  void _openAdminPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IntranetWebViewPage(
          title: '管理端',
          url: _buildAdminUrl(),
        ),
      ),
    );
  }

  void _showUserConfigDialog() {
    final ipController = TextEditingController(text: _userIp);
    final portController = TextEditingController(text: _userPort);

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
        content: Column(
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
          ],
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

              // 清理输入
              ip = ip.replaceAll(RegExp(r'^https?://'), '');
              ip = ip.split('/')[0];
              ip = ip.split(':')[0];

              if (ip.isEmpty || port.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写完整配置')),
                );
                return;
              }

              await _saveUserConfig(ip, port);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('用户端配置已保存')),
              );
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
        content: Column(
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
          ],
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

              // 清理输入
              ip = ip.replaceAll(RegExp(r'^https?://'), '');
              ip = ip.split('/')[0];
              ip = ip.split(':')[0];

              if (ip.isEmpty || port.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写完整配置')),
                );
                return;
              }

              await _saveAdminConfig(ip, port);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('管理端配置已保存')),
              );
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
        child: SingleChildScrollView(
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
                onTap: _openAdminPage,
                onConfigTap: _showAdminConfigDialog,
              ),
            ],
          ),
        ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: context.iconLarge,
                    height: context.iconLarge,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(context.cardRadius / 2),
                    ),
                    child: Icon(
                      icon,
                      color: primaryColor,
                      size: context.iconMedium,
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
                            fontWeight: FontWeight.w600,
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
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onConfigTap,
                    icon: Icon(
                      Icons.settings_outlined,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                    tooltip: '配置',
                  ),
                ],
              ),
              SizedBox(height: context.spacingMedium),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacingSmall,
                  vertical: context.spacingSmall / 2,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(context.cardRadius / 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link,
                      size: context.iconSmall,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                    SizedBox(width: context.spacingSmall / 2),
                    Text(
                      'http://$ip:$port',
                      style: TextStyle(
                        fontSize: context.fontSmall,
                        fontFamily: 'Consolas',
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
