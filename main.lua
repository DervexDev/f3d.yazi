--- @since 25.12.29

local M = {}

-- `fs.cha` was renamed to `fs.stat` after Yazi 26.9.1
local stat = fs.stat or fs.cha

local function num(v, default)
	return tonumber(v) or default
end

-- Number of distinct camera positions in a full turn
local function positions(job)
	local step = math.abs(num(job.args.step, 45))
	return step > 0 and math.max(1, math.floor(360 / step)) or 1
end

-- `seek` doesn't receive the `run` arguments, so `peek` shares the number of positions with it
local set_positions = ya.sync(function(st, n) st.positions = n end)

function M:peek(job)
	local start, cache = os.clock(), ya.file_cache(job)
	if not cache then
		return
	end

	local n = positions(job)
	set_positions(n)
	if job.skip >= n then
		return ya.emit("peek", { job.skip % n, only_if = job.file.url, tab = job.tab })
	end

	local ok, err = self:preload(job)
	if not ok or err then
		return ya.preview_widget(job, err)
	end

	ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))

	local _, err = ya.image_show(cache, job.area)
	ya.preview_widget(job, err)
end

function M:seek(job)
	-- `cx.active` was renamed to `cx.tab` after Yazi 26.9.1
	local tab = cx.tab or cx.active
	local h = tab.current.hovered
	if not h or h.url ~= job.file.url then
		return
	end

	local n = self.positions or positions { args = {} }
	if n <= 1 then
		return
	end

	local units = job.units > 0 and 1 or -1
	ya.emit("peek", {
		(tab.preview.skip + units) % n,
		only_if = job.file.url,
		tab = job.tab,
	})
end

function M:preload(job)
	local cache = ya.file_cache(job)
	if not cache then
		return true
	end

	local cached = stat(cache)
	if cached and cached.len > 0 then
		return true
	end

	local azimuth = num(job.args.azimuth, 0) + (job.skip % positions(job)) * num(job.args.step, 45)
	-- The preloader and the previewer can render the same file at the same time, so give each run its own output
	local tmp = Url(string.format("%s.%d%04d.png", cache, os.time(), math.random(0, 9999)))

	-- stylua: ignore
	local cmd = Command("f3d")
		:stdout(Command.NULL)
		:stderr(Command.PIPED)
		:arg {
			"--load-plugins=" .. (job.args.plugins or "assimp"),
			"--resolution=" .. rt.preview.max_width .. "," .. rt.preview.max_height,
			"--camera-azimuth-angle=" .. azimuth,
			"--camera-elevation-angle=" .. num(job.args.elevation, 0),
			"--output=" .. tostring(tmp),
		}

	if job.args.transparent then
		cmd:arg("--no-background")
	end
	if job.args.backend then
		cmd:arg("--rendering-backend=" .. job.args.backend)
	end

	local child, err = cmd:arg({ "--", tostring(job.file.path) }):spawn()
	if not child then
		return true, Err("Failed to start `f3d`, error: %s", err)
	end

	-- Unlike other previewers, `Command:memory()` can't be used here: it limits the
	-- address space, and OpenGL drivers reserve far more of it than they actually use.
	-- Watch the resident memory instead.
	local status
	while rt.tasks.image_alloc > 0 and not status do
		ya.sleep(0.2)

		status, err = child:try_wait()
		if err then
			return true, Err("Error while running `f3d`: %s", err)
		elseif status then
			break
		end

		local id, mem = child:id(), nil
		if id then
			mem = ya.proc_info(id).mem_resident
		end
		if mem and mem > rt.tasks.image_alloc then
			child:start_kill()
			child:wait()
			fs.remove("file", tmp)
			return true, Err("`f3d` exceeded the memory limit, pid: %s, memory: %s", id, mem)
		end
	end

	local output, err = child:wait_with_output()
	if not output then
		return true, Err("Error while running `f3d`: %s", err)
	end

	local tmp_stat = stat(tmp)
	if not output.status.success or not tmp_stat or tmp_stat.len == 0 then
		fs.remove("file", tmp)
		cached = stat(cache)
		if cached and cached.len > 0 then
			return true
		end

		local msg = output.stderr:gsub("\27%[[%d;]*m", ""):match("^%s*(.-)%s*$")
		if msg == "" then
			msg = output.status.code and ("exit code " .. output.status.code) or "terminated by a signal"
		end
		return false, Err("`f3d` failed to render the model: %s", msg)
	end

	local ok, err = fs.rename(tmp, cache)
	if not ok then
		fs.remove("file", tmp)
		return true, Err("Failed to move the rendered image into the cache: %s", err)
	end
	return true
end

function M:spot(job) require("file"):spot(job) end

return M
