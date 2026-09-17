local neturl = require("./vendor/neturl.luau")
local M = {}

local function hostname(host, explicitScheme)
    if host:match("^[%d.]+$") then return explicitScheme end
    -- Bare words are searches; explicit schemes also allow intranet hostnames.
    if explicitScheme or host:lower() == "localhost" then return true end
    local tld = host:match("%.([^.]+)$")
    return tld ~= nil and (tld:match("^%a%a+$") ~= nil or tld:match("^xn%-%-[%w%-]+$") ~= nil)
end

function M.normalize(text)
    if type(text) ~= "string" then return nil end
    local value = text:match("^%s*(.-)%s*$")
    if value == "" or value:sub(1, 1) == "/" or value:find("[%s%c\\<>\"]") then return nil end
    local explicitScheme = value:find("^[%a][%w+.-]*://") ~= nil
    local candidate = explicitScheme and value or "https://" .. value
    local parsed = neturl.parse(candidate)
    if not parsed.authority or parsed.authority == "" or parsed.authority:find("@", 1, true) then return nil end

    local host = parsed.host
    if not host then return nil end
    if host:sub(1, 1) == "[" then
        -- IP parsing is left to neturl; IP literals require an explicit scheme.
        if not explicitScheme then return nil end
    elseif not hostname(host, explicitScheme) then
        return nil
    end
    -- Do not rebuild through neturl: its query table can reorder or collapse keys.
    if not explicitScheme and host:lower() == "localhost" then return "http://" .. value end
    return candidate
end

return M
