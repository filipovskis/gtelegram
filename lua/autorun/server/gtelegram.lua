--[[

Author: tochonement
Email: tochonement@gmail.com

27.08.2021

--]]

local gtelegram = {}
_G.gtelegram = gtelegram

-- ANCHOR Class "Bot"

local BOT = {}
BOT.__index = BOT

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

        if result.ok then
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

    if query then
        query.func(self, unpack(query.args))

        table.remove(self.queue, 1)
    end
end

function BOT:GetAPI(method)
    local url = "https://api.telegram.org/bot" .. self.id .. ":" .. self.token

    if method then
        url = url .. "/" .. method
    end

    return url
end

-- Additional

function BOT:Poll()
    self:Queue(function(bot)
        bot:Request("getUpdates", {}, function(bot, jsonData)
            bot.chats = getChats(jsonData)
        end)
    end)
end

function BOT:ForEachChat(callback)
    for _, chatId in ipairs(self.chats) do
        callback(chatId)
    end
end

function BOT:SendMessage(text, _data)
    _data = _data or {}
    _data.text = text

    self:Queue(function(bot, data)
        if data.chatId then
            bot:Request("sendMessage", data)
        else
            for _, chatId in ipairs(bot.chats) do
                data["chat_id"] = chatId

                bot:Request("sendMessage", data)
            end
        end
    end, _data)
end

-- ANCHOR Functions

function gtelegram.CreateBot(id, token)
    local bot = setmetatable({
        queue = {},
        chats = {},
        token = token,
        id = id
    }, BOT)

    bot:Poll()

    return bot
end

-- ANCHOR Test

local bot = gtelegram.CreateBot("1964975924", "AAGjxnVjq8Z359xYcuHWRbBTgVJxY0kenD0")
bot:SendMessage("Hello")
bot:SendMessage("How are you?")
bot:SendMessage("Nice to meet you")

timer.Create("Test", 0.1, 0, function()
    bot:Think()
end)