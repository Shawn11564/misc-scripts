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

-- Helper function to parse item and count from args
local function parseItemAndCount(args)
    if not args then
        return nil, nil
    end
    
    -- Match first word as item and second word as count
    local item, count = args:match("^(%S+)%s+(%d+)$")
    
    -- If no count provided, just get the item
    if not item then
        item = args:match("^(%S+)$")
        count = 1  -- Default to 1 if no count specified
    else
        count = tonumber(count)  -- Convert count to number
    end
    
    return item, count
end

-- Command handlers with privilege flags
local commandHandlers = {
    count = {
        privileged = true,
        handler = function(username, args)
            local item = args
            if not item then
                return "Usage: !count <item>"
            end

            local rsItem = rs.getItem({ name = item })
            if rsItem ~= nil then
                local count = rsItem.amount
                return "There are " .. count .. " " .. item .. " stored."
            else
                return "There are no " .. item .. " stored."
            end
        end
    },

    craft = {
        privileged = true,
        handler = function(username, args)
            local item, count = parseItemAndCount(args)
            
            if not item or not count then
                return "Usage: !craft <item> <count>"
            end

            if not rs.isItemCraftable({ name = item }) then
                return "There is no recipe for " .. item .. "."
            end

            local craftingStatus = rs.craftItem({ name = item, count = count })
            if craftingStatus == false then
                return "There was an error crafting " .. item .. "."
            else
                return "Crafting " .. count .. "x " .. item .. "."
            end
        end
    },

    status = {
        privileged = false,
        handler = function(username)
            if rs then
                return "System is running normally. RS Bridge connected."
            else
                return "System is running, but RS Bridge is not connected!"
            end
        end
    },

    help = {
        privileged = false,
        handler = function(username)
            local public = {}
            local privileged = {}
            
            for cmd, info in pairs(commandHandlers) do
                if info.privileged then
                    table.insert(privileged, CONFIG.COMMAND_PREFIX .. cmd)
                else
                    table.insert(public, CONFIG.COMMAND_PREFIX .. cmd)
                end
            end
            
            table.sort(public)
            table.sort(privileged)
            
            local response = "Public commands: " .. table.concat(public, ", ")
            if ALLOWED_USERS[username] then
                response = response .. "\nPrivileged commands: " .. table.concat(privileged, ", ")
            end
            return response
        end
    }
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
    local command, args = parseCommand(message)
    if not command then
        return
    end
    
    local commandInfo = commandHandlers[command]
    if not commandInfo then
        chat.sendMessage(string.format("Unknown command '%s'. Use %shelp to see available commands.",
            command, CONFIG.COMMAND_PREFIX))
        return
    end
    
    -- Check privileges
    if commandInfo.privileged and not ALLOWED_USERS[username] then
        chat.sendMessage("You don't have permission to use this command.")
        return
    end
    
    local status, response = pcall(commandInfo.handler, username, args)
    if not status then
        chat.sendMessage("Error executing command: " .. tostring(response))
        return
    end
    
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