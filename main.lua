--- @since 25.12.29

local M = {}

-- `fs.cha` was renamed to `fs.stat` after Yazi 26.9.1
local stat = fs.stat or fs.cha

-- f3d's default camera looks along (-1, -0.5, -1), i.e. from this far above the horizon
local DEFAULT_ELEVATION = math.deg(math.atan(0.5 / math.sqrt(2)))

local ZOOM_MIN, ZOOM_MAX = -5, 10

local function num(v, default) return tonumber(v) or default end

local function clamp(v, min, max) return math.max(min, math.min(max, v)) end

-- Number of distinct camera positions in a full turn
local function positions(job)
	local step = math.abs(num(job.args.step, 45))
	return step > 0 and math.max(1, math.floor(360 / step)) or 1
end

-- The preview's `skip` holds both the orbit position and the zoom level: `zoom * positions + orbit`.
-- The zoom level is zigzag-encoded (0, 1, -1, 2, -2, …) so that a `skip` of 0 is the default view.
local function encode(orbit, zoom, n)
	return (zoom > 0 and zoom * 2 - 1 or -zoom * 2) * n + orbit
end

local function decode(skip, n)
	local z = skip // n
	return skip % n, z % 2 == 1 and (z + 1) // 2 or -(z // 2)
end

-- Camera direction for the given orbit position, rotating around the world's up axis so the horizon stays level.
-- f3d's own `--camera-azimuth-angle` rotates around the camera's view-up instead, which rolls an elevated camera.
local function direction(job, orbit)
	local a = math.rad(num(job.args.azimuth, 0) + orbit * num(job.args.step, 45))
	local e = math.rad(clamp(num(job.args.elevation, DEFAULT_ELEVATION), -89, 89))

	local up = (job.args.up or "+Y"):upper()
	local axis = ({ X = 1, Y = 2, Z = 3 })[up:sub(-1)] or 2
	local sign = up:sub(1, 1) == "-" and -1 or 1

	local dir = {}
	dir[axis] = -sign * math.sin(e)
	dir[axis % 3 + 1] = math.cos(e) * (math.sin(a) - math.cos(a)) / math.sqrt(2)
	dir[(axis + 1) % 3 + 1] = math.cos(e) * -(math.cos(a) + math.sin(a)) / math.sqrt(2)
	return string.format("%.6f,%.6f,%.6f", dir[1], dir[2], dir[3])
end

-- `seek` and `entry` don't receive the `run` arguments, so `peek` shares what they need
local share = ya.sync(function(st, url, n) st.url, st.positions = url, n end)

local zoom = ya.sync(function(st, delta)
	-- `cx.active` was renamed to `cx.tab` after Yazi 26.9.1
	local tab = cx.tab or cx.active
	local h = tab.current.hovered
	if not h or tostring(h.url) ~= st.url then
		return false
	end

	local orbit, level = decode(tab.preview.skip, st.positions)
	local new = clamp(level + delta, ZOOM_MIN, ZOOM_MAX)
	if new ~= level then
		ya.emit("peek", { encode(orbit, new, st.positions), only_if = h.url })
	end
	return true
end)

function M:peek(job)
	local start, cache = os.clock(), ya.file_cache(job)
	if not cache then
		return
	end

	local n = positions(job)
	share(tostring(job.file.url), n)

	local orbit, level = decode(job.skip, n)
	if level ~= clamp(level, ZOOM_MIN, ZOOM_MAX) then
		return ya.emit("peek", { encode(orbit, clamp(level, ZOOM_MIN, ZOOM_MAX), n), only_if = job.file.url })
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
	local tab = cx.tab or cx.active
	local h = tab.current.hovered
	if not h or h.url ~= job.file.url then
		return
	end

	local n = self.positions or positions { args = {} }
	if n <= 1 then
		return
	end

	local orbit, level = decode(tab.preview.skip, n)
	local units = job.units > 0 and 1 or -1
	ya.emit("peek", {
		encode((orbit + units) % n, level, n),
		only_if = job.file.url,
		tab = job.tab,
	})
end

-- `plugin f3d 1` / `plugin f3d -1` zooms the hovered model in or out.
-- Any other file is handed over to zoom.yazi, so the same keys can zoom images too.
function M:entry(job)
	local delta = num(job.args[1], 0)
	if not zoom(delta) then
		ya.emit("plugin", { "zoom", tostring(delta) })
	end
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

	local orbit, level = decode(job.skip, positions(job))
	-- The preloader and the previewer can render the same file at the same time, so give each run its own output
	local tmp = Url(string.format("%s.%d%04d.png", cache, os.time(), math.random(0, 9999)))

	-- stylua: ignore
	local cmd = Command("f3d")
		:stdout(Command.NULL)
		:stderr(Command.PIPED)
		:arg {
			"--load-plugins=" .. (job.args.plugins or "assimp"),
			"--resolution=" .. rt.preview.max_width .. "," .. rt.preview.max_height,
			"--camera-direction=" .. direction(job, orbit),
			"--output=" .. tostring(tmp),
		}

	if level ~= 0 then
		cmd:arg(string.format("--camera-zoom-factor=%.4f", 0.9 * 1.2 ^ level))
	end
	if job.args.up then
		cmd:arg("--up=" .. job.args.up)
	end
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
