-- Configuration
local CONFIG = {
    CHAT_PERIPHERAL_SIDE = "left",
    COMMAND_PREFIX = "!"
}

local ALLOWED_USERS = {
    ["DonCheadle"] = true,
    ["DaMorgo"] = true
}

-- Initialize peripherals
local chat = peripheral.wrap(CONFIG.CHAT_PERIPHERAL_SIDE)
local rs = peripheral.find("rsBridge")
if not chat then
    error("Chat peripheral not found on " .. CONFIG.CHAT_PERIPHERAL_SIDE .. " side")
end

-- Command handlers
local commandHandlers = {
    count = function(username, args)
        if not args then
            return "Usage: !count <item>"
        end

        local item = rs.getItem({ name = args })
        if item ~= nil then
            local count = item.amount
            return "There are " .. count .. " " .. args .. " stored."
        else
            return "There are no " .. args .. " stored."
        end
    end,

    craft = function(username, args)
        if not args then
            return "Usage: !craft <item> <count>"
        end

        -- split item and count args
        local item = args:match("^(%S+)")
        local toCraft = args:match("^%S+%s+(%d+)$")
        
        if not item or not toCraft then
            return "Usage: !craft <item> <count>"
        end

        if not rs.isItemCraftable({ name = args }) then
            return "There is no recipe for " .. args .. "."
        end

        local craftingStatus = rs.craftItem({ name = args, count = toCraft })
        if craftingStatus == false then
            return "There was an error crafting " .. args .. "."
        else
            return "Crafting " .. args .. " (" .. toCraft .. ")."
        end
    end,

    -- Example of a command that doesn't need args
    status = function(username)
        return "System is running normally"
    end,

    -- Example of a command with multiple arguments
    ping = function(username, args)
        return "Pong! " .. (args or "")
    end
}

-- Parse command and arguments from a message
local function parseCommand(message)
    if not message:match("^" .. CONFIG.COMMAND_PREFIX) then
        return nil
    end

    local withoutPrefix = message:sub(#CONFIG.COMMAND_PREFIX + 1)
    local command = withoutPrefix:match("^(%S+)")
    if not command then
        return nil
    end

    local args = withoutPrefix:match("^%S+%s+(.+)$")
    return command:lower(), args
end

-- Handle a chat message
local function handleMessage(username, message)
    if not ALLOWED_USERS[username] then
        return
    end

    local command, args = parseCommand(message)
    if not command then
        return
    end

    local handler = commandHandlers[command]
    if not handler then
        local availableCommands = {}
        for cmd in pairs(commandHandlers) do
            table.insert(availableCommands, CONFIG.COMMAND_PREFIX .. cmd)
        end
        chat.sendMessage(string.format("Unknown command '%s'. Available commands: %s",
            command,
            table.concat(availableCommands, ", ")))
        return
    end

    local response = handler(username, args)
    if response then
        chat.sendMessage(response)
    end
end

-- Main event loop
local function listen()
    while true do
        local event, username, message, uuid, isHidden = os.pullEvent("chat")
        local status, err = pcall(handleMessage, username, message)
        if not status then
            chat.sendMessage("Error processing command: " .. tostring(err))
        end
    end
end

-- Start the program
listen()
