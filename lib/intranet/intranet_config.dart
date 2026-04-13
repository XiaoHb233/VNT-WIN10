import 'dart:convert';

/// 内网功能配置
class IntranetConfig {
  // 用户端端口
  int userPort;
  // 管理端端口
  int adminPort;
  // 是否启用内网功能
  bool enabled;

  IntranetConfig({
    this.userPort = 8080,
    this.adminPort = 8081,
    this.enabled = false,
  });

  factory IntranetConfig.fromJson(Map<String, dynamic> json) {
    return IntranetConfig(
      userPort: json['userPort'] ?? 8080,
      adminPort: json['adminPort'] ?? 8081,
      enabled: json['enabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userPort': userPort,
      'adminPort': adminPort,
      'enabled': enabled,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory IntranetConfig.fromJsonString(String jsonString) {
    return IntranetConfig.fromJson(jsonDecode(jsonString));
  }

  IntranetConfig copyWith({
    int? userPort,
    int? adminPort,
    bool? enabled,
  }) {
    return IntranetConfig(
      userPort: userPort ?? this.userPort,
      adminPort: adminPort ?? this.adminPort,
      enabled: enabled ?? this.enabled,
    );
  }
}
