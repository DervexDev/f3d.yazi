--- @since 25.12.29

local M = {}

-- `fs.cha` was renamed to `fs.stat` after Yazi 26.9.1
local stat = fs.stat or fs.cha

-- f3d's default camera looks along (-1, -0.5, -1), i.e. from this far above the horizon
local DEFAULT_ELEVATION = math.deg(math.atan(0.5 / math.sqrt(2)))

local ZOOM_MIN, ZOOM_MAX = -5, 10

local function num(v, default) return tonumber(v) or default end

local function clamp(v, min, max) return math.max(min, math.min(max, v)) end

-- `--flag` is `true`, `--flag=false` (or `no`, `off`, `0`) is `false`
local function flag(v, default)
	if v == nil then
		return default
	end
	return v == true or not ({ ["false"] = true, no = true, off = true, ["0"] = true })[tostring(v):lower()]
end

-- f3d config file shipped with the plugin, used unless `--config` is given
local function config(job)
	if job.args.config then
		return job.args.config
	end

	local dir
	if rt.path then
		dir = tostring(rt.path.config_dir)
	elseif os.getenv("YAZI_CONFIG_HOME") then
		dir = os.getenv("YAZI_CONFIG_HOME")
	elseif ya.target_family() == "windows" then
		dir = (os.getenv("APPDATA") or "") .. "\\yazi\\config"
	else
		dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") or "") .. "/.config") .. "/yazi"
	end

	local path = Url(dir):join("plugins/f3d.yazi/f3d.json")
	return stat(path) and tostring(path) or nil
end

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

local function thousands(n)
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^(-?),", "%1"))
end

-- Parses the summary printed by `assimp info`
local function parse_stats(text)
	local t = {}
	for line in text:gmatch("[^\r\n]+") do
		local key, value = line:match("^(%a[%a%s%(%)%.]-):%s+(.-)%s*$")
		if not key then
			-- The bounding box lines have no colon, e.g. `Minimum point      (-1.0 -2.0 -3.0)`
			key, value = line:match("^(%a+ point)%s+(%(.-%))%s*$")
		end
		if key and t[key] == nil then
			t[key] = value
		end
	end
	if not tonumber(t.Vertices) then
		return nil
	end

	local pattern = "%(([-%d%.e+]+) ([-%d%.e+]+) ([-%d%.e+]+)%)"
	local min = { (t["Minimum point"] or ""):match(pattern) }
	local max = { (t["Maximum point"] or ""):match(pattern) }
	local size
	if #min == 3 and #max == 3 then
		size = {}
		for i = 1, 3 do
			local d = max[i] - min[i]
			size[i] = d >= 100 and thousands(d + 0.5) or (string.format("%.3g", d))
		end
		size = table.concat(size, " × ")
	end

	local num_or_0 = function(k) return tonumber(t[k]) or 0 end
	return {
		vertices = num_or_0("Vertices"),
		faces = num_or_0("Faces"),
		-- Assimp triangulates the model, so faces are triangles unless it also has points or lines
		faces_label = t["Primitive Types"] == "triangles" and "triangles" or "faces",
		meshes = num_or_0("Meshes"),
		materials = num_or_0("Materials"),
		textures = num_or_0("Textures (embed.)"),
		animations = num_or_0("Animations"),
		bones = num_or_0("Bones"),
		cameras = num_or_0("Cameras"),
		lights = num_or_0("Lights"),
		size = size,
	}
end

-- Model statistics from `assimp info`, cached next to the preview images. `nil` when unavailable.
local function stats(job)
	local cache = ya.file_cache { file = job.file, skip = 0 }
	if not cache then
		return nil
	end

	local path = tostring(cache) .. ".stats"
	local f = io.open(path, "r")
	if f then
		local text = f:read("a")
		f:close()
		return parse_stats(text)
	end

	local output = Command("assimp"):arg({ "info", tostring(job.file.path) }):stdout(Command.PIPED):stderr(Command.NULL):output()
	if not output then
		return nil -- Assimp isn't installed, try again next time
	end

	-- Keep only the summary, not the per-mesh listing; an empty file marks a format Assimp can't read
	local text = output.status.success and (output.stdout:match("^(.-\n)Meshes:%s+%(name%)") or output.stdout) or ""
	f = io.open(path, "w")
	if f then
		f:write("\n", text)
		f:close()
	end
	return parse_stats("\n" .. text)
end

local function stats_lines(s)
	local lines = {
		string.format("%s vertices · %s %s · %s meshes", thousands(s.vertices), thousands(s.faces), s.faces_label, thousands(s.meshes)),
	}

	local extra = {}
	for _, k in ipairs { "materials", "textures", "animations", "bones" } do
		if s[k] > 0 then
			extra[#extra + 1] = string.format("%s %s", thousands(s[k]), s[k] == 1 and k:sub(1, -2) or k)
		end
	end
	if #extra > 0 then
		lines[#lines + 1] = table.concat(extra, " · ")
	end
	if s.size then
		lines[#lines + 1] = "Size " .. s.size
	end
	return lines
end

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

	local s = flag(job.args.stats, true) and stats(job)
	local lines = s and stats_lines(s) or {}
	local area = job.area
	if #lines > 0 and area.h > #lines + 2 then
		area = ui.Rect { x = area.x, y = area.y, w = area.w, h = area.h - #lines - 1 }
	else
		lines = {}
	end

	ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))

	local rect, err = ya.image_show(cache, area)
	if err or #lines == 0 then
		return ya.preview_widget(job, err)
	end

	local y = (rect and rect.y + rect.h or area.y + area.h) + 1
	ya.preview_widget(job, {
		ui.Text(table.concat(lines, "\n"))
			:area(ui.Rect { x = job.area.x, y = y, w = job.area.w, h = #lines })
			:align(ui.Align.CENTER)
			:style(ui.Style():dim()),
	})
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

	local cfg = config(job)
	if cfg then
		cmd:arg("--config=" .. cfg)
	end
	if level ~= 0 then
		cmd:arg(string.format("--camera-zoom-factor=%.4f", 0.9 * 1.2 ^ level))
	end
	if job.args.up then
		cmd:arg("--up=" .. job.args.up)
	end
	if flag(job.args.transparent, true) then
		cmd:arg("--no-background")
	end
	if job.args.backend then
		cmd:arg("--rendering-backend=" .. job.args.backend)
	end

	local child, err = cmd:arg({ "--", tostring(job.file.path) }):spawn()
	if not child then
		return true, Err("Failed to start `f3d`, error: %s", err)
	end

	-- Gather the model statistics while f3d renders
	if flag(job.args.stats, true) then
		stats(job)
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

function M:spot(job)
	local rows = {}
	local s = stats(job)
	if s then
		rows = {
			ui.Row({ "Model" }):style(ui.Style():fg("green")),
			ui.Row { "  Vertices:", thousands(s.vertices) },
			ui.Row { "  " .. s.faces_label:gsub("^%l", string.upper) .. ":", thousands(s.faces) },
			ui.Row { "  Meshes:", thousands(s.meshes) },
			ui.Row { "  Materials:", thousands(s.materials) },
			ui.Row { "  Textures:", thousands(s.textures) .. " embedded" },
			ui.Row { "  Animations:", thousands(s.animations) },
			ui.Row { "  Bones:", thousands(s.bones) },
			ui.Row { "  Cameras:", thousands(s.cameras) },
			ui.Row { "  Lights:", thousands(s.lights) },
			ui.Row { "  Size:", s.size or "-" },
			ui.Row {},
		}
	end

	rows = ya.list_merge(rows, require("file"):spot_base(job))
	ya.spot_table(
		job,
		ui.Table(rows)
			:area(ui.Pos { "center", w = 60, h = math.min(#rows + 2, 30) })
			:row(1)
			:col(1)
			:col_style(th.spot.tbl_col)
			:cell_style(th.spot.tbl_cell)
			:widths { ui.Constraint.Length(14), ui.Constraint.Fill(1) }
	)
end

return M
