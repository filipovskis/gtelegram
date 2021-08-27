--[[

MIT License

Copyright (c) 2021 Aleksandrs Filipovskis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

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

-- SECTION Class "KeyboardButton"

local BUTTON = {}
BUTTON.__index = BUTTON

accessor(BUTTON, "text")
accessor(BUTTON, "url")
accessor(BUTTON, "callback")
accessor(BUTTON, "callbackData")
accessor(BUTTON, "keyboard")

function BUTTON:SetRow(index)
    local keyboard = self.keyboard
    local row = keyboard.rows[index]

    assert(index > 0, "Row index must be greater than 0")
    assert(row, "There's no row with index " .. index .. ", use keyboard:AddRow()")

    self.row = index
    self.pos = #row + 1

    row[self.pos] = self
end

function BUTTON:GetTGData()
    local cbData = {}
    cbData.buttonId = self.text

    if self.callbackData then
        table.Merge(cbData, self.callbackData)
    end

    return {
        ["text"] = self.text,
        ["url"] = self.url,
        ["callback_data"] = util.TableToJSON(cbData)
    }
end

-- !SECTION

-- SECTION Class "Keyboard"

local KEYBOARD = {}
KEYBOARD.__index = KEYBOARD

function KEYBOARD:Init()
    self.rows = {[1] = {}}
    self.buttons = {}
end

function KEYBOARD:AddRow()
    return table.insert(self.rows, {})
end

function KEYBOARD:CreateButton()
    local button = setmetatable({
        keyboard = self
    }, BUTTON)

    table.insert(self.buttons, button)

    return button
end

function KEYBOARD:GetButtons()
    return self.buttons
end

-- !SECTION

-- SECTION Class "InlineKeyboard"

local IKEYBOARD = {}
IKEYBOARD.__index = IKEYBOARD

function IKEYBOARD:GetTGData()
    local data = {}

    for index, buttons in ipairs(self.rows) do
        data[index] = {}

        for _, button in ipairs(buttons) do
            table.insert(data[index], button:GetTGData())
        end
    end

    return {["inline_keyboard"] = data}
end

-- !SECTION

-- SECTION Class "ReplyKeyboard"

local RKEYBOARD = {}
RKEYBOARD.__index = RKEYBOARD

accessor(RKEYBOARD, "oneTime")
accessor(RKEYBOARD, "placeholder")
accessor(RKEYBOARD, "resize")

function RKEYBOARD:GetTGData()
    local keyboard = {}

    for index, buttons in ipairs(self.rows) do
        keyboard[index] = {}

        for _, button in ipairs(buttons) do
            table.insert(keyboard[index], button:GetTGData())
        end
    end

    return {
        ["keyboard"] = keyboard,
        ["one_time_keyboard"] = self.oneTime,
        ["input_field_placeholder"] = self.placeholder,
        ["resize_keyboard"] = self.resize
    }
end

-- !SECTION

-- SECTION Class "Message"

local MESSAGE = {}
MESSAGE.__index = MESSAGE

accessor(MESSAGE, "bot")
accessor(MESSAGE, "text")
accessor(MESSAGE, "parseMode")
accessor(MESSAGE, "silent")
accessor(MESSAGE, "keyboard")

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

function MESSAGE:CreateInlineKeyboard()
    local keyboard = setmetatable({
        message = self
    }, {
        __index = function(tbl, key)
            return KEYBOARD[key] or IKEYBOARD[key]
        end
    })

    keyboard:Init()

    self.keyboard = keyboard

    return keyboard
end

function MESSAGE:CreateReplyKeyboard()
    local keyboard = setmetatable({
        message = self
    }, {
        __index = function(tbl, key)
            return KEYBOARD[key] or RKEYBOARD[key]
        end
    })

    keyboard:Init()

    self.keyboard = keyboard

    return keyboard
end

function MESSAGE:CloseReplyKeyboard()
    self.keyboard = {
        GetTGData = function()
            return {["remove_keyboard"] = true}
        end
    }

    return self
end

function MESSAGE:GetTGData()
    local keyboard = self.keyboard

    local data = {}
    data["text"] = self.text
    data["parse_mode"] = self.parseMode
    data["disable_notification"] = self.silent

    if keyboard then
        data["reply_markup"] = util.TableToJSON(keyboard:GetTGData())
    end

    return data
end

function MESSAGE:Send()
    local bot = self.bot
    local keyboard = self.keyboard

    assert(bot)
    assert(self.text, "Empty message can't be sent, set text!")
    assert(self.text, "You must set text")
    assert(#self.chats > 0, "Message can't be sent to nobody, add chats!")

    if keyboard and keyboard.GetButtons then
        for _, button in ipairs(keyboard:GetButtons()) do
            local buttonId = button.text
            local callback = button.callback

            if callback then
                bot:AddHook("OnCallback", buttonId, function(bot, cbData)
                    local data = util.JSONToTable(cbData.data)

                    if data and (data.buttonId == buttonId) then
                        callback(cbData.from, data)
                    end
                end)
            end
        end
    end

    bot:Queue(function(bot, message)
        local msgData = message:GetTGData()

        for _, chatId in ipairs(message:GetChats()) do
            msgData["chat_id"] = chatId

            bot:Request("sendMessage", msgData, function(bot, data)
                message.id = data["message_id"]
            end)
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
            local callback = result["callback_query"]

            if message then
                self:CallHook("OnMessage", nil, message)
            end

            if callback then
                self:CallHook("OnCallback", nil, callback)
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
        chats = {},
        buttons = {}
    }, MESSAGE)
    object:SetBot(self)

    return object
end

function BOT:SyncCommands()
    self:Queue(function(bot)
        local commands = {}

        for cmd in pairs(self.commands) do
            table.insert(commands, {
                command = cmd,
                description = "Test"
            })
        end

        self:Request("setMyCommands", {
            ["commands"] = util.TableToJSON(commands)
        })
    end)
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

function BOT:OnMessage(message)
    local entities = message.entities
    local chatId = tostring(message.chat.id)

    if not self:IsChatExists(chatId) then
        self:AddChat(chatId)
    end

    if entities and entities[1].type == "bot_command" then
        local commandParts = splitByQuotes(message.text)
        local commandId = string.sub(commandParts[1], 2)
        local commandFunc = self.commands[commandId]

        table.remove(commandParts, 1)

        if commandFunc then
            commandFunc(self, message.from, unpack(commandParts))
        end
    end
end

function BOT:OnCallback(cbData)
    self:Request("answerCallbackQuery", {
        ["callback_query_id"] = cbData.id
    })
end

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
bot:AddCommand("hello", function(self, message)
    self:SendMessage("Hello :)")
end)
bot:AddCommand("type", function(self, message, text)
    self:SendMessage(text)
end)
bot:SyncCommands()

local msg = bot:CreateMessage()
:SetText("Who would you like to *kick*?")
:SetParseMode("MarkdownV2")
:SetSilent(true)
:AddAllChats()

-- local keyboard = msg:CreateKeyboard()
-- keyboard:AddRow()
-- -- PrintTable(keyboard)

-- local button = keyboard:CreateButton()
-- button:SetText("Hello")
-- button:SetUrl("https://core.telegram.org/bots/api#sendmessage")
-- button:SetRow(1)

-- local button2 = keyboard:CreateButton()
-- button2:SetText("Hello")
-- button2:SetUrl("https://core.telegram.org/bots/api#sendmessage")
-- button2:SetRow(2)

-- local keyboard = msg:CreateKeyboard()
-- keyboard:AddButton("GitHub", {url = "https://github.com/"})
-- -- keyboard:AddButton("Google", {callbackData = {
-- --     amongus = "Hello"
-- -- }})
-- -- keyboard:AddButton("Ban", {callbackData = {
-- --     amongus = "Hello"
-- -- }})
-- local button = keyboard:CreateButton()
-- button:SetText("Ban")
-- button:SetRow(1)
-- button:SetCallbackData({
--     steamid = "STEAM_0:1:62967572"
-- })
-- button:SetCallback(function(activator, data)
--     print("Ban")
--     PrintTable(activator)
-- end)

-- local button = keyboard:CreateButton()
-- button:SetText("Kick")
-- button:SetRow(1)
-- button:SetCallbackData({
--     steamid = "STEAM_0:1:62967572"
-- })
-- button:SetCallback(function(activator, data)
--     print("Kick")
--     PrintTable(data)
-- end)

-- local keyboard = msg:CreateInlineKeyboard()

-- local button = keyboard:CreateButton()
-- button:SetText("Boom")
-- button:SetRow(1)
-- button:SetCallbackData({
--     steamid = "STEAM_0:1:62967572"
-- })
-- button:SetCallback(function(activator, data)
--     print("activated!!!")
-- end)

local keyboard = msg:CreateReplyKeyboard()
keyboard:SetOneTime(true)
keyboard:SetPlaceholder("Hello there")
keyboard:SetResize(true)

local button = keyboard:CreateButton()
button:SetText("Ban")
button:SetRow(1)
button:SetCallbackData({
    steamid = "STEAM_0:1:62967572"
})
button:SetCallback(function(activator, data)
    print("activated!!!")
    bot:RemoveReplyKeyboard()
end)

local button = keyboard:CreateButton()
button:SetText("Kick")
button:SetRow(1)
button:SetCallbackData({
    steamid = "STEAM_0:1:62967572"
})
button:SetCallback(function(activator, data)
    print("activated!!!")
    bot:RemoveReplyKeyboard()
end)

-- local rowIndex = 1
-- for index, ply in ipairs(player.GetAll()) do
--     if (index % 3) == 0 then
--         rowIndex = rowIndex + 1

--         if not keyboard.rows[rowIndex] then
--             keyboard:AddRow()
--         end
--     end

--     local btn = keyboard:CreateButton()
--     btn:SetRow(rowIndex)
--     btn:SetText(ply:Name())
--     btn:SetCallbackData({
--         userId = ply:UserID()
--     })
--     btn:SetCallback(function(activator, data)
--         local userId = data.userId

--         game.KickID(userId, "TGBot")
--     end)
-- end

msg:Send()

local msg2 = bot:CreateMessage()
msg2:SetText("Close")
msg2:CloseReplyKeyboard()
msg2:AddAllChats()
msg2:Send()

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