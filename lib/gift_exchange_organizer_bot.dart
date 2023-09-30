import 'dart:io';

import 'package:gift_exchange_organizer_bot/configuration.dart';
import 'package:gift_exchange_organizer_bot/storage.dart';
import 'package:teledart/model.dart' as tg;
import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';

const _commandStart = 'start';
const _commandHelp = 'help';
const _commandList = 'list';
const _commandGo = 'go';
const _commandThanks = 'thanks';
const _commandMyId = 'myid';
const _commandRemind = 'remind';

const _commands = {
  _commandList: 'Show participants.',
  _commandRemind: 'Who was it, again?',
  _commandGo: 'Admin command! Start gifting session.',
  _commandThanks: 'Admin command! Say thanks to all.',
  _commandMyId: 'Get your chat id.',
};

const _confirmGoTrue = 'adminConfirmGoTrue';
const _confirmGoFalse = 'adminConfirmGoFalse';

class GiftsBot {
  final _storage = Storage();
  final _config = Configuration();

  late final TeleDart _teledart;

  static final GiftsBot _instance = GiftsBot._internal();

  factory GiftsBot() {
    return _instance;
  }

  GiftsBot._internal();

  Future<void> startBot() async {
    if (_config.botToken.isEmpty) {
      print('There is no bot token in configuration.');
      exit(1);
    }

    final username = (await Telegram(_config.botToken).getMe()).username;
    _teledart = TeleDart(_config.botToken, Event(username!));

    _teledart.start();

    print('Bot started.');

    _teledart.setMyCommands(_commands.entries
        .map((el) => tg.BotCommand(command: el.key, description: el.value))
        .toList());

    _teledart.onMessage().listen(_onMessage);

    _teledart.onCommand(_commandStart).listen(_start);
    _teledart.onCommand(_commandHelp).listen(_help);
    _teledart.onCommand(_commandList).listen(_list);
    _teledart.onCommand(_commandRemind).listen(_remind);
    _teledart.onCommand(_commandGo).listen(_go);
    _teledart.onCommand(_commandThanks).listen(_thanks);
    _teledart.onCommand(_commandMyId).listen(_myId);

    _teledart
        .onCallbackQuery()
        .where((event) =>
            event.data == _confirmGoTrue || event.data == _confirmGoFalse)
        .listen((event) async {
      if (event.teledartMessage != null && event.message != null) {
        if (event.data == _confirmGoTrue) {
          await _goGoGo(event.teledartMessage!);
        }
        if (event.data == _confirmGoFalse) {
          event.teledartMessage?.reply('Let\'s wait.');
        }
        await _teledart.editMessageReplyMarkup(
            chatId: event.message?.chat.id,
            messageId: event.message?.messageId);
      }
    });
  }

  void _onMessage(tg.TeleDartMessage message) {
    try {
      final newChat = _storage.persistChat(message.chat);
      message.reply(newChat
          ? 'Ok. You are in!'
          : 'Yes, yes. You are in. Make no spam. Go. Do some work!');
    } catch (e) {
      print(e);
      message.reply('Something went wrong. Can you try again, please?');
    }
  }

  Future<void> _start(tg.TeleDartMessage message) async {
    await message
        .reply('Hey! Please write something to me if you want to participate.');
    if (_config.emptyAdmins) {
      _config.updateAdminConfig(message.chat.id.toString());
      message
          .reply('You are admin now. You can start gifting session and more.');
    }
  }

  void _help(tg.TeleDartMessage message) {
    final commands =
        _commands.entries.map((el) => '/${el.key} - ${el.value}').join('\r\n');
    message.reply(
        'Write something to me if you want to participate in gifting session.\r\n\r\n$commands');
  }

  Future<void> _list(tg.TeleDartMessage message) async {
    final chats = _storage.listChats();
    final names = chats
        .map((c) =>
            '[${_escapeForMarkdown(c.firstName ?? '')} ${_escapeForMarkdown(c.lastName ?? '')}](tg://user?id=${c.id})')
        .toList();
    final text = '${names.join('\r\n')}\r\n\\-\\-\\-\r\nTotal: ${names.length}';
    await message.reply(
      text,
      parseMode: 'MarkdownV2',
    );
  }

  void _remind(tg.TeleDartMessage message) {
    if (_storage.existResult()) {
      final connectedChats = _storage.loadResult();
      final connectedChat = connectedChats[message.chat.id];
      if (connectedChat == null) {
        message.reply('Sorry, seems like you are not participating.');
      } else {
        message.reply(
          '||Make a nice gift to [${_escapeForMarkdown(connectedChat.firstName ?? '')} ${_escapeForMarkdown(connectedChat.lastName ?? '')}](tg://user?id=${connectedChat.id})||',
          parseMode: 'MarkdownV2',
        );
      }
    } else {
      message.reply('Not started yet. Please wait.');
    }
  }

  Future<void> _go(tg.TeleDartMessage message) async {
    if (_config.isAdmin(message.chat.id.toString())) {
      await _list(message);

      message.reply(
        'Please confirm that you want to start gifting session.',
        replyMarkup: tg.InlineKeyboardMarkup(
          inlineKeyboard: [
            [
              tg.InlineKeyboardButton(
                text: 'Yes',
                callbackData: _confirmGoTrue,
              ),
              tg.InlineKeyboardButton(
                text: 'No',
                callbackData: _confirmGoFalse,
              ),
            ],
          ],
        ),
      );
    } else {
      message.reply(
          'You don\'t have permission to do that. Please contact admin.');
    }
  }

  Future<void> _goGoGo(tg.TeleDartMessage message) async {
    if (_config.isAdmin(message.chat.id.toString())) {
      await message.reply('Sure thing.');

      Map<int, tg.Chat> connectedChats = {};

      if (_storage.existResult()) {
        connectedChats = _storage.loadResult();
      } else {
        final chats = _storage.listChats();
        chats.shuffle();
        connectedChats = _superConnector(chats);
        _storage.persistResult(connectedChats);
      }

      for (final entr in connectedChats.entries) {
        _teledart.sendMessage(
          entr.key,
          '||Make a nice gift to [${_escapeForMarkdown(entr.value.firstName ?? '')} ${_escapeForMarkdown(entr.value.lastName ?? '')}](tg://user?id=${entr.value.id})||',
          parseMode: 'MarkdownV2',
        );
      }
    }
  }

  Future<void> _thanks(tg.TeleDartMessage message) async {
    if (_config.isAdmin(message.chat.id.toString())) {
      await message.reply('Sure thing.');

      if (_storage.existResult()) {
        final connectedChats = _storage.loadResult();
        for (final entr in connectedChats.entries) {
          _teledart.sendMessage(entr.key,
              'Thank you for the wonderful present. You did great. You are the best gift giver ever!');
        }
      } else {
        message.reply('Not started yet. Please wait.');
      }
    } else {
      message.reply(
          'You don\'t have permission to do that. Please contact admin.');
    }
  }

  void _myId(tg.TeleDartMessage message) {
    message.reply(
      'Your chat id is ||${message.chat.id}||',
      parseMode: 'MarkdownV2',
    );
  }

  String _escapeForMarkdown(String txt) {
    return txt.replaceAllMapped(
        RegExp(r'[_*[\]()~`>#\+\-=|{}.!]'), (m) => '\\${m[0]}');
  }

  Map<int, tg.Chat> _superConnector(List<tg.Chat> list) {
    final map = <int, tg.Chat>{};
    if (list.isNotEmpty) {
      for (int i = 0; i < list.length; i++) {
        map[list[i].id] = list[i == list.length - 1 ? 0 : i + 1];
      }
    }
    return map;
  }
}
