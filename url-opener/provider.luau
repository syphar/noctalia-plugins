local url = require("./url.luau")
local history = require("./history.luau")
local visibleUrls = {}

function onQuery(text)
    local currentUrl = url.normalize(text)
    local query = noctalia.string.trim(text)
    local results = {}
    visibleUrls = {}
    if currentUrl then
        results[1] = {
            id = currentUrl,
            title = "Open in browser",
            subtitle = currentUrl,
            glyph = "world",
            score = 1000000,
        }
        visibleUrls[currentUrl] = true
    end
    local matches = {}
    if query:sub(1, 1) ~= "/" then
        for index, entry in ipairs(history.entries) do
            local score = query == "" and 0 or noctalia.fuzzyScore(query, entry)
            if entry ~= currentUrl and score ~= nil then
                table.insert(matches, { url = entry, score = score, recent = index })
            end
        end
    end
    table.sort(matches, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.recent < b.recent
    end)
    for index, match in ipairs(matches) do
        table.insert(results, {
            id = match.url,
            title = match.url,
            subtitle = "Recently opened",
            glyph = "history",
            score = -index,
        })
        visibleUrls[match.url] = true
    end
    launcher.setResults(text, results)
end

function onActivate(id)
    if not visibleUrls[id] then return end
    if not noctalia.runAsync({ "xdg-open", id }, function(result)
        if result.exitCode ~= 0 or result.timedOut then
            noctalia.notifyError("URL Opener", "Could not open the URL in your default browser.")
        else
            history.remember(id)
        end
    end) then
        noctalia.notifyError("URL Opener", "Could not start xdg-open.")
    end
end
