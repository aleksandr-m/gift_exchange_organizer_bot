# Gift Exchange Organizer Bot

Telegram bot for organizing gift exchange.

## Getting Started

First you need to create a new bot and obtain [bot API token](https://core.telegram.org/bots/features#creating-a-new-bot).

Start the organizer bot and it will create the configuration file named `config.json` on the first run. Update configuration with the bot API token.
You can also create file by yourself with the following content.

```
{
  "botToken": "BOT_API_TOKEN_HERE"
}
```

Run organizer bot and start using it in telegram. The first person to start the bot will become admin. 
Share telegram bot with the people you want to participate. When everyone have been registered, admin can start gifting session.

## Building Executable

```
dart compile exe ./bin/gift_exchange_organizer_bot.dart 
```
