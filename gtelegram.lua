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

local function mix(data, mt, baseMt)
    return setmetatable(data, {
        __index = function(tbl, key)
            return mt[key] or baseMt[key]
        end
    })
end

local function createContentClass(method, parameters)
    local mt = {}
    mt.__index = mt
    mt.method = method

    for key in pairs(parameters) do
        accessor(mt, key)
    end

    function mt:ExpandTGData(data)
        for key, parameter in pairs(parameters) do
            local value

            if parameter.json then
                value = util.TableToJSON(self[key])
            else
                value = self[key]
            end

            data[(parameter.telegram or key)] = value
        end
    end

    function mt:Validate()
        for key, parameter in pairs(parameters) do
            if not parameter.optional then
                assert(self[key], "\"" .. key .. "\" is required!")
            end
        end
    end

    return mt
end

local function addObjectCreation(mt, name, objMt, baseMt)
    mt[name] = function(self)
        local object = mix({
            chats = {},
            buttons = {}
        }, objMt, baseMt)

        object:Init()
        object:SetBot(self)

        return object
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

    return {
        ["inline_keyboard"] = data
    }
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

-- SECTION Class "Command"

local COMMAND = {}
COMMAND.__index = COMMAND

accessor(COMMAND, "bot")
accessor(COMMAND, "name")
accessor(COMMAND, "description")
accessor(COMMAND, "callback")
accessor(COMMAND, "aliases")

function COMMAND:Init()
    self.aliases = {}
end

function COMMAND:AddAlias(name)
    table.insert(self.aliases, name)
    return self
end

function COMMAND:Validate()
    assert(self.name, "You must provide a name!")
    assert(self.callback, "You must provide a callback!")

    self.validated = true
end

function COMMAND:IsValidated()
    return self.validated
end

-- !SECTION

-- SECTION Class "Content"

local CONTENT = {}
CONTENT.__index = CONTENT

accessor(CONTENT, "bot")
accessor(CONTENT, "silent")
accessor(CONTENT, "keyboard")

function CONTENT:Init()
    
end

function CONTENT:Everyone()
    self.chats = table.Copy(self.bot.chats)
    return self
end

function CONTENT:AddChat(chatId)
    table.insert(self.chats, chatId)
    return self
end

function CONTENT:RemoveChat(chatId)
    for k, v in ipairs(self.chats) do
        if v == chatId then
            return table.remove(self.chats, k)
        end
    end
end

function CONTENT:GetChats()
    return self.chats
end

function CONTENT:CreateKeyboard(meta)
    local keyboard = mix({
        message = self
    }, meta, KEYBOARD)

    keyboard:Init()

    self.keyboard = keyboard

    return keyboard
end

function CONTENT:CreateInlineKeyboard()
    return self:CreateKeyboard(IKEYBOARD)
end

function CONTENT:CreateReplyKeyboard()
    return self:CreateKeyboard(RKEYBOARD)
end

function CONTENT:CloseReplyKeyboard()
    self.keyboard = {
        GetTGData = function()
            return {["remove_keyboard"] = true}
        end
    }

    return self
end

function CONTENT:GetTGData()
    local keyboard = self.keyboard

    local data = {}
    data["parse_mode"] = self.parseMode
    data["disable_notification"] = self.silent

    if keyboard then
        data["reply_markup"] = util.TableToJSON(keyboard:GetTGData())
    end

    self:ExpandTGData(data)

    return data
end

function CONTENT:PrepareCallbacks()
    local bot = self.bot
    local keyboard = self.keyboard

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
end

function CONTENT:Send()
    local bot = self.bot

    assert(bot)
    assert(#self.chats > 0, "Message can't be sent to nobody, add chats!")

    self:Validate()
    self:PrepareCallbacks()

    bot:Queue(function(bot, message)
        local msgData = message:GetTGData()

        for _, chatId in ipairs(message:GetChats()) do
            msgData["chat_id"] = tostring(chatId)

            bot:Request(self.method, msgData)
        end
    end, self)
end

function CONTENT:Validate(data)
    
end

function CONTENT:ExpandTGData(data)
    
end

-- !SECTION

-- SECTION Content Subclasses

local MESSAGE = createContentClass("sendmessage", {
    ["text"] = {},
    ["parseMode"] = {
        optional = true,
        telegram = "parse_mode"
    }
})

local DICE = createContentClass("sendDice", {
    ["emoji"] = {
        optional = true
    }
})

do
    local emojiReference = {
        ["basketball"] = "🏀",
        ["darts"] = "🎯",
        ["footbal"] = "⚽",
        ["bowling"] = "🎳",
        ["casino"] = "🎰",
        ["dice"] = "🎲"
    }

    function DICE:ChangeEmoji(name)
        local found = emojiReference[name]

        assert(found, "Incorrect emoji name!")

        self.emoji = found

        return self
    end
end

local VOTE = createContentClass("sendPoll", {
    ["question"] = {},
    ["options"] = {
        json = true
    },
    ["anonymous"] = {
        optional = true,
        telegram = "is_anonymous"
    },
    ["multipleAnswers"] = {
        optional = true,
        telegram = "allows_multiple_answers"
    },
    ["closed"] = {
        optional = true,
        telegram = "is_closed"
    },
    ["lifeTime"] = {
        optional = true,
        telegram = "open_period"
    },
    ["closeDate"] = {
        optional = true,
        telegram = "close_date"
    }
})

function VOTE:Init()
    self.options = {}
end

function VOTE:AddOption(option)
    table.insert(self.options, option)
    return self
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

addObjectCreation(BOT, "CreateMessage", MESSAGE, CONTENT)
addObjectCreation(BOT, "CreateDice", DICE, CONTENT)
addObjectCreation(BOT, "CreateVote", VOTE, CONTENT)

function BOT:SyncCommands()
    self:Queue(function(bot)
        local commands = {}

        for _, command in pairs(self.commands) do
            if not command:IsValidated() then
                goto skip
            end

            local description = command:GetDescription() or "Unknown"
            local aliasDesc = "Alias of \"/" .. command:GetName() .. "\""

            table.insert(commands, {
                command = command:GetName(),
                description = description
            })

            for _, alias in ipairs(command:GetAliases()) do
                table.insert(commands, {
                    command = alias,
                    description = aliasDesc
                })
            end

            ::skip::
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

function BOT:CreateCommand()
    local command = setmetatable({
        bot = self
    }, COMMAND)
    command:Init()

    table.insert(self.commands, command)

    return command
end

function BOT:FindCommand(name)
    for _, command in ipairs(self.commands) do
        if not command:IsValidated() then
            goto skip
        end

        if command:GetName() == name then
            return command
        end

        for _, alias in ipairs(command:GetAliases()) do
            if alias == name then
                return command
            end
        end

        ::skip::
    end
end

-- Override

function BOT:OnMessage(message)
    local entities = message.entities
    local chatId = tostring(message.chat.id)

    if not self:IsChatExists(chatId) then
        self:AddChat(chatId)
    end

    if entities and entities[1].type == "bot_command" then
        local cmdParts = splitByQuotes(message.text)
        local cmdName = string.sub(cmdParts[1], 2)
        local cmdObject = self:FindCommand(cmdName)

        table.remove(cmdParts, 1)

        if cmdObject then
            local callback = cmdObject:GetCallback()

            assert(callback, "No callback for command \"" .. cmdName .. "\"")

            callback(self, message.from, unpack(cmdParts))
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

hook.Run("GTelegram.OnLoaded")