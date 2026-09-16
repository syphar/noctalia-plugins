local url = require("./url.luau")
local M = { entries = {} }
local dir = noctalia.pluginDataDir()
local path = dir and (dir .. "/history.json")

if path then
    local raw = noctalia.readFile(path)
    local saved = raw and noctalia.json.decode(raw)
    if type(saved) == "table" then
        local seen = {}
        for _, entry in ipairs(saved) do
            if type(entry) == "string" and not seen[entry] and url.normalize(entry) == entry then
                table.insert(M.entries, entry)
                seen[entry] = true
                if #M.entries == 100 then break end
            end
        end
    end
end

function M.remember(value)
    for index = #M.entries, 1, -1 do
        if M.entries[index] == value then table.remove(M.entries, index) end
    end
    table.insert(M.entries, 1, value)
    while #M.entries > 100 do table.remove(M.entries) end

    local encoded = noctalia.json.encode(M.entries)
    -- Replace only after writing the complete history, preserving the old file on failure.
    if not path or not encoded or not noctalia.writeFile(path .. ".tmp", encoded)
        or not noctalia.renameFile(path .. ".tmp", path) then
        noctalia.notifyError("URL Opener", "Could not save URL history. Recent URLs are available for this session only.")
    end
end

return M
