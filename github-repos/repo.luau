local github = require("./github.luau")
local repositories = nil
local refreshedAt = 0
local retryAt = 0
local loading = false
local latestText = ""
local failure = nil

local function render()
    if repositories ~= nil then
        local results = github.results(repositories, noctalia.string.trim(latestText), true)
        if failure then
            table.insert(results, { id = "status", title = "Showing cached repositories",
                subtitle = failure, score = -1000000 })
        end
        if #results == 0 then
            github.message(latestText, "No matching repositories", "Search accessible, watched, and organization repositories.")
        else
            launcher.setResults(latestText, results)
        end
    elseif failure then
        github.message(latestText, "Could not load your repositories", failure)
    else
        github.message(latestText, "Loading your repositories…", "Fetching your public and private repositories.")
    end
end

local function refresh()
    loading = true
    failure = nil
    local collected = {}
    local seen = {}
    local sources = { "user/repos", "user/subscriptions", "user/orgs" }
    local sourcePriorities = { ["user/repos"] = 2, ["user/subscriptions"] = 1 }
    -- Walk every source and page, then replace the cache only after a full refresh.
    local function page(sourceIndex, number)
        local endpoint = sources[sourceIndex]
        local organizations = endpoint == "user/orgs"
        local filter = organizations and "map({login})" or "map(" .. github.fields .. ")"
        github.api(endpoint, {
            "per_page=100", "page=" .. number,
        }, filter, function(data, err)
            if err then
                loading = false
                failure = err
                retryAt = os.time() + 15
                render()
                return
            end
            for _, entry in ipairs(data) do
                if organizations then
                    if type(entry.login) == "string" and string.match(entry.login, "^[%w%-]+$") then
                        table.insert(sources, "orgs/" .. entry.login .. "/repos")
                    end
                elseif entry.id ~= nil then
                    local priority = sourcePriorities[endpoint] or 0
                    local existing = seen[entry.id]
                    if existing then
                        -- A repository can belong to several sources; keep its strongest priority.
                        existing.sourcePriority = math.max(existing.sourcePriority, priority)
                    else
                        entry.sourcePriority = priority
                        seen[entry.id] = entry
                        table.insert(collected, entry)
                    end
                end
            end
            if #data == 100 then
                page(sourceIndex, number + 1)
            elseif sourceIndex < #sources then
                page(sourceIndex + 1, 1)
            else
                repositories = collected
                refreshedAt = os.time()
                loading = false
                render()
            end
        end)
    end
    page(1, 1)
end

function onQuery(text)
    latestText = text
    if not loading and os.time() >= retryAt
        and (repositories == nil or os.time() - refreshedAt >= 24 * 60 * 60) then
        refresh()
    end
    render()
end

function onActivate(id)
    github.activate(id)
end
