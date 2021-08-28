--[[

Author: tochonement
Email: tochonement@gmail.com

28.08.2021

--]]

-- Callback data you provide is persistent for a button
-- Callback won't be removed after button is pressed

local bot = GTelegram("1988948436", "AAEWrMo-lo_wbvKhWsfI06Dx2Vyn8o8AuiQ")
bot:SetPollRate(1)

-- InlineKeyboard
do
    local cbData = {steamId = "STEAM_0:1:62967572"}
    local message = bot:CreateMessage()
        message:SetText("Alex said a swear word")
        message:Everyone()

        local keyboard = message:CreateReplyKeyboard()
        keyboard:AddRow()

        keyboard:CreateButton()
        :SetText("Kick")
        :SetCallbackData(cbData)
        :SetCallback(function(from, data)
            RunConsoleCommand("sam", "kick", data.steamId)
        end)

        keyboard:CreateButton()
        :SetText("Ban")
        :SetCallbackData(cbData)
        :SetCallback(function(from, data)
            RunConsoleCommand("sam", "ban", data.steamId)
        end)

        keyboard:CreateButton()
        :SetText("Slap")
        :SetCallbackData(cbData)
        :SetRow(2)
        :SetCallback(function(from, data)
            RunConsoleCommand("sam", "slap", data.steamId)
        end)
    message:Send()
end

-- InlineKeyboard 2
do
    local keyword = "Cat"

    local message = bot:CreateMessage()
        message:SetText("What search engine use?")
        message:Everyone()

        local keyboard = message:CreateInlineKeyboard()

        keyboard:CreateButton()
        :SetText("Google")
        :SetUrl("http://www.google.com/search?q=" .. keyword)

        keyboard:CreateButton()
        :SetText("DuckDuckGo")
        :SetUrl("https://duckduckgo.com/?q=" .. keyword)
    message:Send()
end

-- Dice with ability to reroll
local function createDice(chat)
    local dice = bot:CreateDice()

    if chat then
        dice:AddChat(chat)
    else
        dice:Everyone()
    end

    local keyboard = dice:CreateInlineKeyboard()

    local button = keyboard:CreateButton()
    button:SetText("Try again")
    button:SetCallback(function(from, data)
        createDice(from.id)
    end)

    dice:Send()
end

-- createDice()

-- Create a timer/think hook to process bot's queries' queue
timer.Create("BotThink", 0.1, 0, function()
    bot:Think()
end)