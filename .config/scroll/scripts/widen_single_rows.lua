-- Co-Author: Claude Sonnet 5.5

local scroll = require ("scroll")

-- Make every lone window in a row becomes full width.
local function widen_single_rows(workspace)
    for _, row in ipairs(scroll.workspace_get_tiling(workspace)) do
        local views = scroll.container_get_views(row)
        if #views == 1 then
            local con = scroll.view_get_container(views[1])
            local fraction = scroll.container_get_width_fraction(con) or 1.0
            if con and fraction < 0.99 then
                scroll.command(con, "fit_size h all equal")
            end
        end
    end
end

-- A window is closing: if exactly one window remains in its row, widen it.
-- The closing window is still in the row at this point, so skip it.
local function widen_survivor(closing)
    local row = scroll.container_get_parent(closing)
    if not row then
        return
    end
    local remaining = {}
    for _,v in ipairs(scroll.container_get_views(row)) do
        local c = scroll.view_get_container(v)
        if c ~= closing then
            table.insert(remaining, c)
        end
    end
    if #remaining == 1 then
        scroll.command(remaining[1], "set_size h 1.0", { commit = false})
    end
end

local function on_view_event(view, change, _)
    if change ~= "move" and change ~= "close"  then
        return
    end
    local con = scroll.view_get_container(view)
    if not con then
        return
    end
    local ws = scroll.container_get_workspace(con)
    if not ws or scroll.workspace_get_layout_type(ws) ~= "vertical" then
        return
    end
    if change == "move" then
        widen_single_rows(ws)
    else
        widen_survivor(con)
    end
end

scroll.add_callback("ipc_view", on_view_event, nil)
