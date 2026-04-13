import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import '../utils/responsive_utils.dart';
import 'intranet_config.dart';
import 'intranet_manager.dart';

/// 内网功能设置组件
class IntranetSettingsWidget extends StatefulWidget {
  const IntranetSettingsWidget({super.key});

  @override
  State<IntranetSettingsWidget> createState() => _IntranetSettingsWidgetState();
}

class _IntranetSettingsWidgetState extends State<IntranetSettingsWidget> {
  final IntranetManager _manager = IntranetManager();
  final TextEditingController _userPortController = TextEditingController();
  final TextEditingController _adminPortController = TextEditingController();
  
  bool _enabled = false;
  bool _isRunning = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _userPortController.dispose();
    _adminPortController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      await _manager.init();
      final config = _manager.config;
      _userPortController.text = config.userPort.toString();
      _adminPortController.text = config.adminPort.toString();
      _enabled = config.enabled;
      _isRunning = _manager.isRunning;
    } catch (e) {
      debugPrint('[内网设置] 加载配置失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    try {
      final userPort = int.tryParse(_userPortController.text) ?? 8080;
      final adminPort = int.tryParse(_adminPortController.text) ?? 8081;

      // 验证端口范围
      if (userPort < 1024 || userPort > 65535) {
        showTopToast(context, '用户端端口必须在 1024-65535 之间', isSuccess: false);
        return;
      }
      if (adminPort < 1024 || adminPort > 65535) {
        showTopToast(context, '管理端端口必须在 1024-65535 之间', isSuccess: false);
        return;
      }
      if (userPort == adminPort) {
        showTopToast(context, '用户端端口和管理端端口不能相同', isSuccess: false);
        return;
      }

      final config = IntranetConfig(
        userPort: userPort,
        adminPort: adminPort,
        enabled: _enabled,
      );

      await _manager.saveConfig(config);
      
      // 如果服务正在运行，需要重启
      if (_isRunning) {
        await _manager.restart();
      }

      if (mounted) {
        showTopToast(context, '配置已保存', isSuccess: true);
      }
    } catch (e) {
      debugPrint('[内网设置] 保存配置失败: $e');
      if (mounted) {
        showTopToast(context, '保存失败: $e', isSuccess: false);
      }
    }
  }

  Future<void> _toggleService() async {
    try {
      setState(() => _isLoading = true);
      
      if (_isRunning) {
        await _manager.stop();
        _isRunning = false;
        _enabled = false;
        if (mounted) {
          showTopToast(context, '内网服务已停止', isSuccess: true);
        }
      } else {
        await _manager.start();
        _isRunning = true;
        _enabled = true;
        if (mounted) {
          showTopToast(context, '内网服务已启动', isSuccess: true);
        }
      }
      
      setState(() {});
    } catch (e) {
      debugPrint('[内网设置] 切换服务状态失败: $e');
      if (mounted) {
        showTopToast(context, '操作失败: $e', isSuccess: false);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      elevation: 0,
      color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Icon(
                  Icons.network_check,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  '内网功能',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
                const Spacer(),
                // 状态指示器
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isRunning 
                        ? Colors.green.withOpacity(0.2) 
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isRunning ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isRunning ? '运行中' : '已停止',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isRunning ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 说明文字
            Text(
              '开启内网功能后，可以通过浏览器访问以下地址：',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            
            // 地址显示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAddressRow('用户端', 'http://localhost:${_userPortController.text.isEmpty ? '8080' : _userPortController.text}'),
                  const SizedBox(height: 4),
                  _buildAddressRow('管理端', 'http://localhost:${_adminPortController.text.isEmpty ? '8081' : _adminPortController.text}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 端口配置
            Row(
              children: [
                Expanded(
                  child: _buildPortInput(
                    label: '用户端端口',
                    controller: _userPortController,
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPortInput(
                    label: '管理端端口',
                    controller: _adminPortController,
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _toggleService,
                    icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                    label: Text(_isRunning ? '停止服务' : '启动服务'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _saveConfig,
                    icon: const Icon(Icons.save),
                    label: const Text('保存配置'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressRow(String label, String address) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        Text(
          address,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Consolas',
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPortInput({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          decoration: InputDecoration(
            hintText: label == '用户端端口' ? '8080' : '8081',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
