# gtelegram
A simple yet powerful Telegram bot API wrapper for Garry's Mod

[Check Wiki](https://github.com/tochnonement/gtelegram/wiki)

# Features
- Optimized message delivery
- Hook system
- Commands
- Inline keyboards with callbacks
- Sentence support as an argument
- Polls, dice and etc.
- Only one file

# Example
```lua
local bot = GTelegram("1988948436", "AAEWrMo-lo_wbvKhWsfI06Dx2Vyn8o8AuiQ")

bot:CreateMessage()
    :SetText("Hey, it's my first *message*")
    :SetParseMode("MarkdownV2")
    :SetSilent(true)
    :Everyone()
:Send()

timer.Create("BotThink", 0.1, 0, function()
    bot:Think()
end)
```