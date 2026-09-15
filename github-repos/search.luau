local github = require("./github.luau")
local latestText = ""
local loading = false
local cachedQuery = nil
local cachedData = nil
local cachedAt = 0

local function render(text, data)
    local results = github.results(data.items, "", false)
    if data.incomplete_results then
        table.insert(results, { id = "status", title = "GitHub returned partial results", score = -1000000 })
    end
    if #results == 0 then
        github.message(text, "No matching repositories", "Try another name or GitHub search qualifier.")
    else
        launcher.setResults(text, results)
    end
end

local search
search = function(text)
    local query = noctalia.string.trim(text)
    if query == "" then
        github.message(text, "Search repositories across GitHub", "Type a name or qualifiers such as language:rust stars:>100.")
        return
    end
    if query == cachedQuery and os.time() - cachedAt < 60 then
        render(text, cachedData)
        return
    end
    github.message(text, "Searching GitHub…")
    -- One request at a time; a completed old query triggers only the newest query.
    if loading then return end
    loading = true
    github.api("search/repositories", { "q=" .. query, "per_page=50" },
        "{incomplete_results, items: [.items[] | " .. github.fields .. "]}", function(data, err)
            loading = false
            if data and type(data.items) ~= "table" then
                data = nil
                err = "GitHub returned an invalid search response. Try again."
            end
            if data then
                cachedQuery, cachedData, cachedAt = query, data, os.time()
            end
            if noctalia.string.trim(latestText) ~= query then
                search(latestText)
            elseif err then
                github.message(latestText, "Could not search GitHub", err)
            else
                render(latestText, data)
            end
        end)
end

function onQuery(text)
    latestText = text
    search(text)
end

function onActivate(id)
    github.activate(id)
end
