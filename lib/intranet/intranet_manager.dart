import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'intranet_config.dart';
import '../config_manager.dart';

/// 内网功能管理器
class IntranetManager {
  static const String _configKey = 'intranet_config';
  
  static final IntranetManager _instance = IntranetManager._internal();
  factory IntranetManager() => _instance;
  IntranetManager._internal();

  final ConfigManager _configManager = ConfigManager();
  IntranetConfig _config = IntranetConfig();
  
  HttpServer? _userServer;
  HttpServer? _adminServer;
  bool _isRunning = false;

  IntranetConfig get config => _config;
  bool get isRunning => _isRunning;

  /// 初始化并加载配置
  Future<void> init() async {
    await _loadConfig();
    if (_config.enabled) {
      await start();
    }
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      final jsonString = _configManager.getString(_configKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        _config = IntranetConfig.fromJsonString(jsonString);
        debugPrint('[内网] 配置加载成功: 用户端端口=${_config.userPort}, 管理端端口=${_config.adminPort}, 启用=${_config.enabled}');
      }
    } catch (e) {
      debugPrint('[内网] 加载配置失败: $e');
    }
  }

  /// 保存配置
  Future<void> saveConfig(IntranetConfig config) async {
    _config = config;
    await _configManager.setString(_configKey, config.toJsonString());
    debugPrint('[内网] 配置已保存');
  }

  /// 启动内网服务
  Future<void> start() async {
    if (_isRunning) {
      debugPrint('[内网] 服务已在运行');
      return;
    }

    try {
      // 启动用户端服务
      _userServer = await HttpServer.bind(InternetAddress.anyIPv4, _config.userPort);
      debugPrint('[内网] 用户端服务已启动: http://localhost:${_config.userPort}');
      _handleUserRequests(_userServer!);

      // 启动管理端服务
      _adminServer = await HttpServer.bind(InternetAddress.anyIPv4, _config.adminPort);
      debugPrint('[内网] 管理端服务已启动: http://localhost:${_config.adminPort}');
      _handleAdminRequests(_adminServer!);

      _isRunning = true;
      _config = _config.copyWith(enabled: true);
      await saveConfig(_config);
    } catch (e) {
      debugPrint('[内网] 启动服务失败: $e');
      await stop();
      throw Exception('启动内网服务失败: $e');
    }
  }

  /// 停止内网服务
  Future<void> stop() async {
    _isRunning = false;
    
    await _userServer?.close();
    _userServer = null;
    debugPrint('[内网] 用户端服务已停止');

    await _adminServer?.close();
    _adminServer = null;
    debugPrint('[内网] 管理端服务已停止');

    _config = _config.copyWith(enabled: false);
    await saveConfig(_config);
  }

  /// 重启服务（端口变更时调用）
  Future<void> restart() async {
    await stop();
    await start();
  }

  /// 处理用户端请求
  void _handleUserRequests(HttpServer server) {
    server.listen((HttpRequest request) async {
      try {
        final response = request.response;
        
        // 设置CORS头
        response.headers.add('Access-Control-Allow-Origin', '*');
        response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

        if (request.method == 'OPTIONS') {
          response.statusCode = HttpStatus.ok;
          await response.close();
          return;
        }

        // 路由处理
        final path = request.uri.path;
        debugPrint('[内网-用户端] 请求: ${request.method} $path');

        switch (path) {
          case '/':
          case '/status':
            await _handleStatusRequest(request);
            break;
          default:
            response.statusCode = HttpStatus.notFound;
            response.write('Not Found');
            await response.close();
        }
      } catch (e) {
        debugPrint('[内网-用户端] 处理请求错误: $e');
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write('Internal Server Error');
          await request.response.close();
        } catch (_) {}
      }
    });
  }

  /// 处理管理端请求
  void _handleAdminRequests(HttpServer server) {
    server.listen((HttpRequest request) async {
      try {
        final response = request.response;
        
        // 设置CORS头
        response.headers.add('Access-Control-Allow-Origin', '*');
        response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

        if (request.method == 'OPTIONS') {
          response.statusCode = HttpStatus.ok;
          await response.close();
          return;
        }

        // 路由处理
        final path = request.uri.path;
        debugPrint('[内网-管理端] 请求: ${request.method} $path');

        switch (path) {
          case '/':
          case '/status':
            await _handleAdminStatusRequest(request);
            break;
          case '/config':
            await _handleConfigRequest(request);
            break;
          default:
            response.statusCode = HttpStatus.notFound;
            response.write('Not Found');
            await response.close();
        }
      } catch (e) {
        debugPrint('[内网-管理端] 处理请求错误: $e');
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write('Internal Server Error');
          await request.response.close();
        } catch (_) {}
      }
    });
  }

  /// 处理状态请求
  Future<void> _handleStatusRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;
    
    final data = {
      'status': 'ok',
      'service': 'VNT App Intranet - User',
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    response.write(jsonEncode(data));
    await response.close();
  }

  /// 处理管理端状态请求
  Future<void> _handleAdminStatusRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;
    
    final data = {
      'status': 'ok',
      'service': 'VNT App Intranet - Admin',
      'timestamp': DateTime.now().toIso8601String(),
      'config': _config.toJson(),
    };
    
    response.write(jsonEncode(data));
    await response.close();
  }

  /// 处理配置请求
  Future<void> _handleConfigRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;

    if (request.method == 'GET') {
      response.write(jsonEncode(_config.toJson()));
    } else if (request.method == 'POST') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final json = jsonDecode(body);
        final newConfig = IntranetConfig.fromJson(json);
        await saveConfig(newConfig);
        response.write(jsonEncode({'success': true, 'config': _config.toJson()}));
      } catch (e) {
        response.statusCode = HttpStatus.badRequest;
        response.write(jsonEncode({'success': false, 'error': e.toString()}));
      }
    } else {
      response.statusCode = HttpStatus.methodNotAllowed;
      response.write(jsonEncode({'success': false, 'error': 'Method not allowed'}));
    }
    
    await response.close();
  }
}

String jsonEncode(Object? object) => const JsonEncoder().convert(object);
