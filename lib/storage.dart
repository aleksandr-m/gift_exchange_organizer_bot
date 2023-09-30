import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart';
import 'package:teledart/model.dart' as tg;

class Storage {
  final _resultFile = File('./result.txt');
  final _data = File('./data.json');

  final _encrypter = Encrypter(AES(Key.fromUtf8('dgbfkla4wernmfgadrfkjhe3')));
  final _initVector = IV.fromLength(16);

  Map<String, tg.Chat> _chats = {};

  static final Storage _instance = Storage._internal();

  factory Storage() {
    return _instance;
  }

  Storage._internal() {
    _chats = _fetchChats();
  }

  Map<String, tg.Chat> _fetchChats() {
    if (_chats.isEmpty) {
      final fileData = _data.existsSync() ? _data.readAsStringSync() : '';
      _chats = fileData.isEmpty
          ? {}
          : (jsonDecode(fileData) as Map).map((key, value) =>
              MapEntry(key.toString(), tg.Chat.fromJson(value)));
    }
    return _chats;
  }

  bool persistChat(tg.Chat chat) {
    if (_chats.containsKey(chat.id.toString())) {
      return false;
    }

    _chats[chat.id.toString()] = chat;

    _data.writeAsStringSync(
      jsonEncode(_chats.map((key, value) => MapEntry(key, value.toJson()))),
      mode: FileMode.writeOnly,
    );

    return true;
  }

  List<tg.Chat> listChats() {
    return _chats.values.toList();
  }

  bool existResult() {
    final resultFileText =
        _resultFile.existsSync() ? _resultFile.readAsStringSync() : '';
    return resultFileText.isNotEmpty;
  }

  void persistResult(Map<int, tg.Chat> connectedChats) {
    final encrypted = _encrypter.encrypt(
      jsonEncode(connectedChats
          .map((key, value) => MapEntry(key.toString(), value.toJson()))),
      iv: _initVector,
    );
    _resultFile.writeAsStringSync(encrypted.base64);
  }

  Map<int, tg.Chat> loadResult() {
    final resultFileText = _resultFile.readAsStringSync();
    final data = _encrypter.decrypt64(
      resultFileText,
      iv: _initVector,
    );
    return (jsonDecode(data) as Map)
        .map((key, value) => MapEntry(int.parse(key), tg.Chat.fromJson(value)));
  }
}
