local _, ns = ...

local PREFIX = "|cff33ccffGryphonMail|r: "

-- Prints a message to the default chat frame with the addon prefix.
function ns:Print(message, ...)
    if select("#", ...) > 0 then
        message = message:format(...)
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(message))
end

-- Prints only when debug mode is enabled in the saved variables.
function ns:Debug(message, ...)
    if self.db and self.db.debug then
        self:Print("|cff999999[debug]|r " .. tostring(message), ...)
    end
end

-- Recursively copies missing default values into the target table.
function ns.ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ns.ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end
