--[[

Author: tochonement
Email: tochonement@gmail.com

27.08.2021

--]]

-- 1988948436:AAEWrMo-lo_wbvKhWsfI06Dx2Vyn8o8AuiQ
-- The first part of token given by BotFather is an ID and the second one is an exact token
-- Use it to create a bot

-- GTelegram(<bot_id>, <bot_token>)
-- GTelegram("1988948436", "AAEWrMo-lo_wbvKhWsfI06Dx2Vyn8o8AuiQ")

local bot = GTelegram("1988948436", "AAEWrMo-lo_wbvKhWsfI06Dx2Vyn8o8AuiQ")
bot:SetPollRate(1)

-- This hook is activated when someone writes in telegram chat
bot:AddHook("OnMessage", "Print", function(bot, msgData)
    print("New message received: \"" .. msgData.text .. "\" from " .. msgData.chat.first_name)
end)

-- Send a simple message
bot:SendMessage("Hello everyone!")

-- Send an advanced message to all chats
bot:CreateMessage()
    :SetText("Hey, it's my first *message*")
    :SetParseMode("MarkdownV2")
    :SetSilent(true)
    :Everyone()
:Send()

-- Send an advanced message to a person
bot:CreateMessage()
    :SetText("Hey <b>bro</b>!")
    :SetParseMode("HTML")
    :AddChat("443322208")
:Send()

-- Send a vote (poll) with your options
bot:CreateVote()
    :SetQuestion("How are you today?")
    :AddOption("Awesome")
    :AddOption("Good")
    :AddOption("Ok")
    :AddOption("Bad")
    :SetAnonymous(false)
    :Everyone()
:Send()

-- Send a dice
bot:CreateDice()
    :ChangeEmoji("bowling")
    :Everyone()
:Send()

-- Create a timer/think hook to process bot's queries' queue
timer.Create("BotThink", 0.1, 0, function()
    bot:Think()
end)