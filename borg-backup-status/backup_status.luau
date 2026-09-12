-- Compact Pika/Borg state indicator.

local requestGeneration = 0
local displayedState = "unknown"

local STATES = {
	current = { glyph = "archive-restore", text = "Backup current" },
	running = { glyph = "rotate-cw", text = "Backup running" },
	failed = { glyph = "triangle-alert", text = "Backup failed" },
	unavailable = { glyph = "hard-drive-off", text = "Disk unavailable" },
	unknown = { glyph = "circle-help", text = "Backup not configured" },
}

local function trim(value: string): string
	return noctalia.string.trim(value)
end

local function quote(value: string): string
	return "'" .. value:gsub("'", "'\\\"'\\\"'") .. "'"
end

local function configString(key: string): string
	local value = noctalia.getConfig(key)
	return type(value) == "string" and trim(value) or ""
end

local function render(state: string)
	local appearance = STATES[state] or STATES.unknown
	displayedState = state
	barWidget.setGlyph(appearance.glyph)
	barWidget.setText("")
	barWidget.setTooltip(appearance.text)
end

local function parseState(output: string): string
	local state = trim(output):lower():match("^([a-z]+)")
	return STATES[state or ""] and state or "failed"
end

local function probeCommand(repository: string, mountPath: string, maxAgeHours: number): string?
	local pluginDir = noctalia.pluginDir()
	if not pluginDir then
		noctalia.log("borg-backup-status: plugin directory is unavailable")
		return nil
	end

	return quote(pluginDir .. "/borg-probe.sh")
		.. " " .. quote(repository)
		.. " " .. quote(mountPath)
		.. " " .. quote(tostring(maxAgeHours))
end

local function refresh()
	requestGeneration += 1
	local generation = requestGeneration
	local repository = configString("repository")
	local mountPath = configString("mount_path")
	local maxAge = noctalia.getConfig("max_age_hours")
	local maxAgeHours = type(maxAge) == "number" and math.max(1, maxAge) or 168

	if repository == "" then
		render("unknown")
		return
	end

	local command = probeCommand(repository, mountPath, maxAgeHours)
	if not command then
		render("failed")
		return
	end
	noctalia.runAsync(command, function(result)
		if generation ~= requestGeneration then
			return
		end
		if result.exitCode ~= 0 then
			render("failed")
			return
		end
		render(parseState(result.stdout or ""))
	end)
end

function update()
	-- A minute is responsive enough for starting/finishing a backup without
	-- repeatedly waking remote Borg repositories.
	noctalia.setUpdateInterval(60000)
	refresh()
end

function onClick()
	local command = configString("open_command")
	if command ~= "" then
		noctalia.runAsync(command)
	end
end

function onIpc(event: string)
	if event == "refresh" then
		refresh()
	elseif event == "status" then
		noctalia.notify("Borg Backup Status", STATES[displayedState].text)
	end
end
