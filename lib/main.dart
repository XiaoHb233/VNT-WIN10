import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vnt_app/src/rust/frb_generated.dart';
import 'package:vnt_app/src/rust/api/vnt_api.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/theme/theme_provider.dart';
import 'package:vnt_app/pages/main_navigation_shell.dart';
import 'package:vnt_app/data_persistence.dart';
import 'package:vnt_app/vnt/vnt_manager.dart';
import 'package:vnt_app/utils/responsive_utils.dart';
import 'package:vnt_app/utils/log_utils.dart';
import 'package:vnt_app/network_config.dart';
import 'package:vnt_app/system_tray_manager.dart';
import 'package:vnt_app/config_manager.dart';

final SystemTray systemTray = SystemTray();
final AppWindow appWindow = AppWindow();

/// 检测是否是 Windows 10 或更高版本
bool isWindows10OrGreater() {
  try {
    final version = Platform.operatingSystemVersion;
    // Windows 版本格式: "Microsoft Windows [Version 10.0.19045.5247]"
    // Windows 7: 6.1, Windows 8: 6.2, Windows 8.1: 6.3, Windows 10: 10.0
    final match = RegExp(r'(\d+)\.(\d+)').firstMatch(version);
    if (match != null) {
      final major = int.parse(match.group(1)!);
      return major >= 10;
    }
  } catch (e) {
    debugPrint('检测 Windows 版本失败: $e');
  }

  // 默认返回 true，使用自定义标题栏
  return true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await copyLogConfig();
  } catch (e) {
    debugPrint('copyLogConfig catch $e');
  }

  try {
    await copyAppropriateDll();
  } catch (e) {
    debugPrint('copyAppropriateDll catch $e');
  }

  await RustLib.init();
  
  // 初始化配置管理器
  await ConfigManager().init();

  // 初始化日志系统
  try {
    final logDir = await LogUtils.getLogDirectory();
    debugPrint('日志目录: $logDir');

    final logsDirectory = Directory(logDir);
    if (!await logsDirectory.exists()) {
      await logsDirectory.create(recursive: true);
      debugPrint('创建日志目录: $logDir');
    }

    initLogWithPath(logDir: logDir);
    debugPrint('日志系统初始化成功，日志目录: $logDir');
  } catch (e) {
    debugPrint('初始化日志系统失败: $e');
  }

  await windowManager.ensureInitialized();

  // Windows 配置
  final windowSize = await DataPersistence().loadWindowSize();
  final windowPosition = await DataPersistence().loadWindowPosition();
  windowManager.setTitle('VNT App');

  // 只在 Windows 10+ 上使用自定义标题栏，Windows 7 使用系统标题栏
  if (isWindows10OrGreater()) {
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  }

  if (windowSize != null) {
    await windowManager.setSize(windowSize);
  }
  
  if (windowPosition != null) {
    await windowManager.setPosition(windowPosition);
  }

  windowManager.waitUntilReadyToShow().then((_) async {
    await appWindow.show();
  });

  runApp(const VntApp());
}

class VntApp extends StatefulWidget {
  const VntApp({super.key});

  @override
  State<VntApp> createState() => _VntAppState();
}

class _VntAppState extends State<VntApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Color _customThemeColor = AppTheme.primaryColor;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadCustomThemeColor();
  }

  Future<void> _loadThemeMode() async {
    final savedMode = await DataPersistence().loadThemeMode();
    if (savedMode != null && mounted) {
      setState(() {
        _themeMode = savedMode;
      });
    }
  }

  Future<void> _loadCustomThemeColor() async {
    final savedColor = await DataPersistence().loadCustomThemeColor();
    if (savedColor != null && mounted) {
      setState(() {
        _customThemeColor = savedColor;
      });
    }
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    DataPersistence().saveThemeMode(mode);
  }

  void _setCustomThemeColor(Color color) {
    setState(() {
      _customThemeColor = color;
    });
    DataPersistence().saveCustomThemeColor(color);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      themeMode: _themeMode,
      setThemeMode: _setThemeMode,
      customThemeColor: _customThemeColor,
      setCustomThemeColor: _setCustomThemeColor,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'VNT App',
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('zh', 'Hans'),
          Locale('en', ''),
        ],
        locale: const Locale('zh', 'CN'),
        theme: AppTheme.createLightTheme(_customThemeColor),
        darkTheme: AppTheme.createDarkTheme(_customThemeColor),
        themeMode: _themeMode,
        home: PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (didPop) return;
            if (Platform.isAndroid) {
              VntAppCall.moveTaskToBack();
            }
          },
          child: const MainApp(),
        ),
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WindowListener {
  bool rememberChoice = false;

  @override
  void initState() {
    super.initState();

    initSystemTray();
    // 设置窗口关闭拦截
    windowManager.setPreventClose(true);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowResize() async {
    final size = await windowManager.getSize();
    DataPersistence().saveWindowSize(size);
  }

  @override
  void onWindowMove() async {
    final position = await windowManager.getPosition();
    DataPersistence().saveWindowPosition(position);
  }

  @override
  void onWindowClose() async {
    debugPrint('onWindowClose 被调用');
    
    // Windows 确认逻辑
    var isClose = await DataPersistence().loadCloseApp();
    debugPrint('loadCloseApp 返回: $isClose');
    
    if (isClose == null) {
      debugPrint('显示关闭确认对话框');
      final shouldClose = await _showCloseConfirmationDialog();
      debugPrint('用户选择: $shouldClose');
      isClose = shouldClose;
    } else {
      debugPrint('使用保存的选择: $isClose');
    }
    
    if (isClose != null) {
      if (isClose) {
        // 退出应用：先断开连接再关闭
        debugPrint('退出应用');
        await vntManager.removeAll();
        windowManager.setPreventClose(false);
        appWindow.close();
      } else {
        // 隐藏窗口：不断开连接
        debugPrint('隐藏到托盘');
        appWindow.hide();
      }
    } else {
      debugPrint('用户取消操作');
    }
  }

  Future<bool?> _showCloseConfirmationDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                '确认关闭',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '你确定要关闭应用吗？',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: rememberChoice,
                        onChanged: (bool? value) {
                          setState(() {
                            rememberChoice = value ?? false;
                          });
                        },
                        activeColor: primaryColor,
                      ),
                      Text(
                        '记住此操作',
                        style: TextStyle(
                          fontSize: context.fontXSmall,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    '隐藏到托盘',
                    style: TextStyle(
                      fontSize: context.fontXSmall,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('退出应用', style: TextStyle(fontSize: context.fontXSmall)),
                ),
              ],
            );
          },
        );
      },
    );

    if (rememberChoice && result != null) {
      DataPersistence().saveCloseApp(result);
    }
    return result;
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationShell(onThemeChanged: _onThemeChanged);
  }
}

Future<void> initSystemTray() async {
  // 初始化系统托盘
  await systemTray.initSystemTray(
    title: "VNT",
    toolTip: "VNT - Virtual Network Tool",
    iconPath: 'assets/app_icon.ico',
  );

  // 初始化 SystemTrayManager，传入全局的 systemTray 实例
  final trayManager = SystemTrayManager();
  trayManager.initialize(systemTray);

  // 更新菜单
  await trayManager.updateMenu();

  // 注册事件处理器
  systemTray.registerSystemTrayEventHandler((eventName) {
    if (eventName == kSystemTrayEventClick) {
      windowManager.show();
    } else if (eventName == kSystemTrayEventRightClick) {
      systemTray.popUpContextMenu();
    }
  });
}

Future<void> copyLogConfig() async {
  final directory = await getApplicationDocumentsDirectory();
  final logConfigFile = File('${directory.path}/logs/log4rs.yaml');
  if (!logConfigFile.parent.existsSync()) {
    await logConfigFile.parent.create(recursive: true);
  }

  if (await logConfigFile.exists()) {
    debugPrint('日志配置已存在');
    return;
  }

  final byteData = await rootBundle.load('assets/log4rs.yaml');
  await logConfigFile.writeAsBytes(byteData.buffer
      .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
}

Future<void> copyAppropriateDll() async {
  // Windows DLL 复制逻辑
  debugPrint('copyAppropriateDll 执行');
}
