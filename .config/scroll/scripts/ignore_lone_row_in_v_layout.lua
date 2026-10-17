-- Co-author: Claude Sonnet 5.5

local args, _ = ...
local scroll = require("scroll")

local cmd = table.concat(args, " ")
local ws = scroll.focused_workspace()
local con = scroll.focused_container()

-- Block only lone row in vertical layout
if ws and con and scroll.workspace_get_layout_type(ws) == "vertical" then
    local row = scroll.container_get_parent(con) or con
    if #scroll.container_get_views(row) == 1 then
        return
    end
end

-- Everything else goes through, with the focused container as context.
local results = scroll.command(con, cmd)

-- Debug log: remove once it works
do return end   -- HAHA: comment this to enable debug
local f = io.open("/tmp/guard_width.log", "a")
if f then
    f:write(cmd, " -> ", table.concat(results or {}, ";"), "\n")
    f:close()
end
