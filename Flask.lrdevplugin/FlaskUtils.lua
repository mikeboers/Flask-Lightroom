local LrApplication = import 'LrApplication'
local LrLogger = import 'LrLogger'

local logger = LrLogger('FlaskUtils')

logger:enable("print")
logger:info("Loading module...")



local M = {}


local serializeMetadata = function(t)
    -- TODO: encode newlines.
    local k, v
    local res = ""
    for k, v in pairs(t) do
        res = res .. string.format("%d %s\n", k, v)
    end
    return res
end


local unserializeMetadata = function(res)
    local k, v
    local t = {}
    for k, v in string.gmatch(res, "(%d+) ([^\n]+)\n") do
        t[tonumber(k)] = v
    end
    return t
end


M.setServiceMetadata = function(service, photo, k, v)
    local values = {}
    local encoded = photo:getPropertyForPlugin(_PLUGIN.id, k)
    if encoded then
        values = unserializeMetadata(encoded)
    end
    values[service.localIdentifier] = v
    encoded = serializeMetadata(values)
    photo:setPropertyForPlugin(_PLUGIN, k, encoded)
end


M.getServiceMetadata = function(service, photo, k)
    local values = {}
    local encoded = photo:getPropertyForPlugin(_PLUGIN.id, k)
    if encoded then 
        values = unserializeMetadata(encoded)
    end
    return values[service.localIdentifier]
end


return M

