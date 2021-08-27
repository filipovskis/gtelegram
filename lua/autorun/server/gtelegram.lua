--[[

Author: tochonement
Email: tochonement@gmail.com

27.08.2021

--]]

if not file.Exists("gtelegram", "DATA") then
    file.CreateDir("gtelegram")
end

local function splitByQuotes(str)
    local args = {}
    local parts = {}
    local startFrom = 0

    while true do
        local quoteStart, quoteEnd= string.find(str, "[%w%p]+", startFrom)

        if quoteStart == nil then
            break
        end

        startFrom = quoteEnd + 1

        table.insert(parts, string.sub(str, quoteStart, quoteEnd))
    end

    local opened = false
    local arg = ""

    for _, part in ipairs(parts) do
        local left = part:Left(1) == "\""
        local right = part:Right(1) == "\""

        if left and right then
            table.insert(args, string.sub(part, 2, -2))
        elseif left then
            opened = true
            arg = string.sub(part, 2)
        elseif opened and right then
            arg = arg .. " " .. string.sub(part, 1, -2)
            table.insert(args, arg)
            opened = false
        elseif opened then
            arg = arg .. " " .. part
        else
            table.insert(args, part)
        end
    end

    return args
end

local function accessor(meta, key, name, type)
    name = name or (string.upper(string.Left(key, 1)) .. string.sub(key, 2))

    local function getter(panel)
        return panel[key]
    end

    meta["Get" .. name] = getter

    if type == FORCE_BOOL then
        meta["Is" .. name] = getter
    end

    meta["Set" .. name] = function(panel, value)
        panel[key] = value

        return panel
    end
end

-- SECTION Class "Message"

local MESSAGE = {}
MESSAGE.__index = MESSAGE

accessor(MESSAGE, "bot")
accessor(MESSAGE, "text")
accessor(MESSAGE, "parseMode")

function MESSAGE:AddAllChats()
    self.chats = table.Copy(self.bot.chats)
    return self
end

function MESSAGE:AddChatId(chatId)
    table.insert(self.chats, chatId)
    return self
end

function MESSAGE:RemoveChatId(chatId)
    for k, v in ipairs(self.chats) do
        if v == chatId then
            return table.remove(self.chats, k)
        end
    end
end

function MESSAGE:GetChats()
    return self.chats
end

function MESSAGE:GetTGData()
    local data = {}
    data["text"] = self.text
    data["parse_mode"] = self.parseMode

    return data
end

function MESSAGE:Send()
    local bot = self.bot

    assert(self.bot)
    assert(self.text)

    bot:Queue(function(bot, message)
        local msgData = message:GetTGData()

        for _, chatId in ipairs(message:GetChats()) do
            msgData["chat_id"] = chatId

            bot:Request("sendMessage", msgData)
        end
    end, self)
end

-- !SECTION

-- SECTION Class "Bot"

local BOT = {}
BOT.__index = BOT

accessor(BOT, "pollRate")

-- Basic

function BOT:GetPath()
    return "gtelegram/bot" .. self.id .. ".dat"
end

function BOT:GetAPI(method)
    local url = "https://api.telegram.org/bot" .. self.id .. ":" .. self.token

    if method then
        url = url .. "/" .. method
    end

    return url
end

function BOT:Queue(func, ...)
    table.insert(self.queue, {
        func = func,
        args = {...}
    })
end

function BOT:Request(method, data, func)
    data = data or {}

    for k, v in pairs(data) do
        data[k] = tostring(v)
    end

    self.busy = true

    http.Post(self:GetAPI(method), data, function(body)
        local result = util.JSONToTable(body)

        if result and result.ok then
            if func then
                func(self, result, body)
            end
        else
            print("Error occured: ", result.error_code, result.description)
        end

        self.busy = false
    end)

    self:CallHook("OnRequest", nil, method, data)
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

function BOT:ForEachChat(callback)
    for _, chatId in ipairs(self.chats) do
        callback(chatId)
    end
end

function BOT:Poll()
    self:Request("getUpdates", {
        ["offset"] = self.lastUpdate,
        ["limit"] = 10
    }, function(bot, data)
        local saveRequired = false

        for _, result in ipairs(data.result) do
            saveRequired = true

            local updateId = result["update_id"]
            local message = result["message"]

            local entities = message.entities
            local chatId = tostring(message.chat.id)

            if not bot:IsChatExists(chatId) then
                bot:AddChat(chatId)
            end

            if entities and entities[1].type == "bot_command" then
                local commandParts = splitByQuotes(message.text)
                local commandId = string.sub(commandParts[1], 2)
                local commandFunc = self.commands[commandId]

                table.remove(commandParts, 1)

                if commandFunc then
                    commandFunc(bot, message.from, unpack(commandParts))
                end
            end

            bot.lastUpdate = updateId + 1

            self:CallHook("OnUpdate", nil, result)
        end

        if saveRequired then
            bot:Save()
        end
    end)
end

function BOT:AddChat(chatId)
    table.insert(self.chats, chatId)

    self:CallHook("OnChatAdded", nil, chatId)
end

function BOT:RemoveChat(chatId)
    for index, v in ipairs(self.chats) do
        if v == chatId then
            table.remove(self.chats, index)
            self:CallHook("OnChatRemove", nil, v)
        end
    end
end

function BOT:IsChatExists(chatId)
    for _, v in ipairs(self.chats) do
        if v == chatId then
            return true
        end
    end

    return false
end

function BOT:Save()
    file.Write(self:GetPath(), util.TableToJSON({
        chats = self.chats,
        lastUpdate = self.lastUpdate
    }))

    self:CallHook("OnSave")
end

function BOT:Load()
    local path = self:GetPath()

    if file.Exists(path, "DATA") then
        local json = file.Read(path, "DATA")
        if json then
            local data = util.JSONToTable(json)

            self.chats = data.chats
            self.lastUpdate = data.lastUpdate
        end
    end
end

function BOT:AddHook(name, id, func)
    self.hooks[name] = self.hooks[name] or {}
    self.hooks[name][id] = func
end

function BOT:RemoveHook(name, id)
    self.hooks[name][id] = nil
end

function BOT:CallHook(name, ignoreDefault, ...)
    for name2, hooks in pairs(self.hooks) do
        if name2 == name then
            for _, func in pairs(hooks) do
                local value = func(self, ...)
                if value then
                    return value
                end
            end

            break
        end
    end

    if not ignoreDefault then
        return self[name](self, ...)
    end
end

-- Additional

function BOT:CreateMessage()
    local object = setmetatable({
        chats = {}
    }, MESSAGE)
    object:SetBot(self)

    return object
end

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

function BOT:AddCommand(id, callback)
    self.commands[id] = callback
end

-- Override

function BOT:OnSave()
    
end

function BOT:OnChatAdded()
    
end

function BOT:OnChatRemove()
    
end

function BOT:OnRequest()
    
end

function BOT:OnUpdate()
    
end

-- !SECTION

-- ANCHOR Functions

function GTelegram(id, token)
    local bot = setmetatable({
        queue = {},
        chats = {},
        commands = {},
        hooks = {},
        pollRate = 5,
        lastUpdate = 0,
        token = token,
        id = id
    }, BOT)

    bot:Load()

    return bot
end

-- ANCHOR Test

local bot = GTelegram("1988948436", "AAEWrMo-lo_wbvKhWsfI06Dx2Vyn8o8AuiQ")
bot:SetPollRate(5)
-- bot:SendMessage("Hello")
-- bot:SendMessage("Hello2")
-- bot:AddCommand("hello", function(self, message)
--     self:SendMessage("Hello :)")
-- end)
-- bot:AddCommand("type", function(self, message, text)
--     self:SendMessage(text)
-- end)

bot:CreateMessage()
:SetText("*Hello everyone*")
:SetParseMode("MarkdownV2")
:AddAllChats()
:Send()
-- bot:AddCommand("giveadmin", function(self, message)
--     print("HUH???")
-- end)
-- bot:AddHook("OnUpdate", "Print", function(self, update)
--     print("Update received")
--     PrintTable(update)
-- end)
-- bot:AddHook("OnRequest", "Test", function(self, method, data)
--     print(method, data)
-- end)
-- bot:SendMessage("How are you?")
-- bot:SendMessage("Nice to meet you")
-- bot:SendMessage("<b>Hello</b>", {
--     ["parse_mode"] = "HTML"
-- })
-- bot:SendMessage("*Hello*", {
--     ["parse_mode"] = "MarkdownV2"
-- })
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

hook.Run("GTelegram.OnLoaded")