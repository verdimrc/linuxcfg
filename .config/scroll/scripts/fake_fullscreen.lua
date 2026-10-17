-- Co-author: Claude Sonnet 5.5

local scroll = require("scroll")

-- True when the app asked for fullscreen (container fullscreen, but not from
-- the `fullscreen` command) and the app thinks it is fullscreen.
local function requested_by_app(con)
    return scroll.container_get_fullscreen_mode(con) == "workspace"
        and scroll.container_get_fullscreen_view_mode(con) == "disabled"
        and scroll.container_get_fullscreen_app_mode(con) == "enabled"
        and scroll.container_get_fullscreen_layout_mode(con) == "disabled"
end

local function on_view_event(view, change, data)
    local con = scroll.view_get_container(view)
    if con ~= data.target then
        return
    end
    if change == "close" then
        scroll.remove_callback(data.id)
        return
    end
    if change == "fullscreen_mode" and requested_by_app(con) then
        scroll.command(cond, "fullscreen disable")
    end
end

-- The window this for_window rule matched.
local target = scroll.context_container()
if target then
    local data = { target = target }
    data.id = scroll.add_callback("ipc_view", on_view_event, data)
end
