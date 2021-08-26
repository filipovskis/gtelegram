--[[

Author: tochonement
Email: tochonement@gmail.com

27.08.2021

--]]

local gtelegram = {}
_G.gtelegram = gtelegram

-- SECTION Class "Bot"

local BOT = {}
BOT.__index = BOT

AccessorFunc(BOT, "pollRate", "PollRate")

-- Local

local function getChats(json)
    local chats = {}

    for _, result in pairs(json.result) do
        local userId = tostring(result.message.chat.id)

        if not table.HasValue(chats, userId) then
            table.insert(chats, userId)
        end
    end

    return chats
end

-- Basic

function BOT:Queue(func, ...)
    table.insert(self.queue, {
        func = func,
        args = {...}
    })
end

function BOT:Request(method, data, func)
    data = data or {}

    self.busy = true

    http.Post(self:GetAPI(method), data, function(body)
        local result = util.JSONToTable(body)

        if result and result.ok then
            if func then
                func(self, result, body)
            end
        else
            print("Error occured: ", data.error_code, data.description)
        end

        self.busy = false
    end)
end

function BOT:Think()
    local query = self.queue[1]

    if self.busy then
        return
    end

    if (self.nextPoll or 0) <= CurTime() then
        self:Poll()

        self.nextPoll = CurTime() + self.pollRate
    else
        if query then
            query.func(self, unpack(query.args))

            table.remove(self.queue, 1)
        end
    end
end

function BOT:GetAPI(method)
    local url = "https://api.telegram.org/bot" .. self.id .. ":" .. self.token

    if method then
        url = url .. "/" .. method
    end

    return url
end

function BOT:ForEachChat(callback)
    for _, chatId in ipairs(self.chats) do
        callback(chatId)
    end
end

function BOT:Poll()
    self:Request("getUpdates", {}, function(bot, jsonData)
        bot.chats = getChats(jsonData)
    end)
end

-- Additional

function BOT:SendMessage(text, _data)
    _data = _data or {}
    _data.text = text

    self:Queue(function(bot, data)
        if data.chatId then
            bot:Request("sendMessage", data)
        else
            bot:ForEachChat(function(chatId)
                data["chat_id"] = chatId

                bot:Request("sendMessage", data)
            end)
        end
    end, _data)
end

function BOT:AddCommand()
    
end

-- !SECTION

-- ANCHOR Functions

function gtelegram.CreateBot(id, token)
    local bot = setmetatable({
        queue = {},
        chats = {},
        token = token,
        id = id,
        pollRate = 5
    }, BOT)

    return bot
end

-- ANCHOR Test

local bot = gtelegram.CreateBot("1964975924", "AAGjxnVjq8Z359xYcuHWRbBTgVJxY0kenD0")
bot:SetPollRate(1)
bot:SendMessage("Hello")
bot:SendMessage("How are you?")
bot:SendMessage("Nice to meet you")
bot:SendMessage("<b>Hello</b>", {
    ["parse_mode"] = "HTML"
})
bot:SendMessage("*Hello*", {
    ["parse_mode"] = "MarkdownV2"
})
-- bot:Queue(function(bot)
--     bot:ForEachChat(function(chatId)
--         bot:Request("sendChatAction", {
--             ["chat_id"] = chatId,
--             ["action"] = "Thinking..."
--         })
--     end)
-- end)

timer.Create("Test", 0.1, 0, function()
    bot:Think()
end)