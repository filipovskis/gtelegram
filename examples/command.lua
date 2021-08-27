--[[

Author: tochonement
Email: tochonement@gmail.com

27.08.2021

--]]

-- Arguments are splitted by spaces and quotes
-- You can write a whole sentence as an argument, just put it in quotes
-- /ban "John Elburg" 300 "You were rude"

local bot = GTelegram("1988948436", "AAEWrMo-lo_wbvKhWsfI06Dx2Vyn8o8AuiQ")
bot:SetPollRate(1)

-- You must finish a command creation by :Validate method, otherwise it won't work
-- /announce "Hello everyone, how are you?"
bot:CreateCommand()
    :SetName("announce")
    :SetDescription("Writes a message to everyone on a server")
    :SetCallback(function(bot, from, text)
        PrintMessage(HUD_PRINTTALK, text)
    end)
:Validate()

bot:CreateCommand()
    :SetName("dice")
    :SetDescription("Throw a dice")
    :SetCallback(function(bot, from)
        bot:CreateDice()
            :AddChat(from.id)
        :Send()
    end)
:Validate()

-- Execute a SAM command on server
-- /sam kick bot
-- /sam vote "How do you like our server?" Great Ok Poop
bot:CreateCommand()
    :SetName("sam")
    :SetDescription("Executes a SAM command")
    :SetCallback(function(bot, from, command, ...)
        if from.username == "tochnonement" then
            RunConsoleCommand("sam", command, ...)

            bot:SendMessage("Executed!")
        end
    end)
:Validate()

-- You must finish a command creation by :Validate method, otherwise it won't work
-- /hello
bot:CreateCommand()
    :SetName("hello")
    :SetDescription("Let bot say hello to you")
    :AddAlias("hi")
    :AddAlias("hey")
    :SetCallback(function(bot, from)
        local firstName = from.first_name or "Stranger"

        bot:SendMessage("Hello *" .. firstName .. "*", {
            parse_mode = "MarkdownV2"
        })
    end)
:Validate()

-- Sync our command so we would have an autocompletion
bot:SyncCommands()

-- Create a timer/think hook to process bot's queries' queue
timer.Create("BotThink", 0.1, 0, function()
    bot:Think()
end)