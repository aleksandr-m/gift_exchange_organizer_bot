import 'dart:convert';
import 'dart:io';

const _configFilePath = './config.json';

class Configuration {
  final _Config _config;

  static final Configuration _instance = Configuration._internal();

  factory Configuration() {
    return _instance;
  }

  Configuration._internal() : _config = _load();

  String get botToken => _config.botToken;
  bool isAdmin(String chatId) => _config.adminsChatIds.contains(chatId);
  bool get emptyAdmins => _config.adminsChatIds.isEmpty;

  void updateAdminConfig(String chatId) {
    _config.adminsChatIds.add(chatId);

    File(_configFilePath).writeAsStringSync(
      jsonEncode(_config),
      mode: FileMode.writeOnly,
    );
  }

  static _Config _load() {
    var config = _Config();
    final confFile = File(_configFilePath);
    if (confFile.existsSync()) {
      final fileData = confFile.readAsStringSync();
      if (fileData.isEmpty) {
        _createConfigFile(confFile, config);
      } else {
        config = _Config.fromJson(jsonDecode(fileData) as Map);
      }
    } else {
      _createConfigFile(confFile, config);
    }
    return config;
  }

  static void _createConfigFile(File confFile, _Config config) {
    confFile.writeAsStringSync(
      jsonEncode(config),
      mode: FileMode.writeOnly,
    );
  }
}

class _Config {
  final String botToken;
  final List<String> adminsChatIds;

  _Config()
      : botToken = '',
        adminsChatIds = [];

  _Config.fromJson(Map<dynamic, dynamic> json)
      : botToken = json['botToken'] ?? '',
        adminsChatIds = List.from(json['adminsChatIds'] ?? []);

  Map<String, dynamic> toJson() => {
        'botToken': botToken,
        'adminsChatIds': adminsChatIds,
      };
}
