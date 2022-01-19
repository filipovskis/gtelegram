# gtelegram
Create your own **telegram bots** in **simple** and elegant way. Also there's a **rich documentation** provided, so it will be also **easy** and fun to do!

[Wiki](https://github.com/tochnonement/gtelegram/wiki)

[Examples](https://github.com/tochnonement/gtelegram/tree/master/examples)

### 💡 Features
- Optimized message delivery
- Hook system
- Commands
- Inline keyboards with callbacks
- Sentence support as an argument
- Polls, dice and etc.
- Only one file

### ✍️ Example
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

### ⚖ Credits
- [Dash](https://github.com/SuperiorServers/dash) - function to explode text by quotes
