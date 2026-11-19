-- batch_replays.lua (REFramework, Street Fighter 6)
-- Plays a queue of replays by replay ID, one at a time, driven by batch_record.py.
-- Ideas from rkaganda/sf6_replays_data (flow_control.lua / auto_replay_capture.lua):
--   * the current screen is read from app.UIFlowManager (top flow name)
--   * the replay-ID search is submitted directly with TextInputDialogWidget:InvokeResultEvent
--   * menu keys are injected by hooking app.InputDeviceStateKeyboard.GetDigital
-- Runs next to capture_replay.lua, which saves reframework/data/<replayid>.json at match end.
--
-- Files (reframework/data/sf6_batch/):
--   command.json  written by batch_record.py: {"seq": 3, "action": "play", "replay_id": "ABC123XYZ"}
--                 action "idle" stops all key presses.
--   status.json   written here every 10 frames: seq, phase, top_flow, fight_st, replay_id, note
--   config.json   optional overrides for the key sequences below (same shape as DEFAULT_CFG)
--   flows.json    every top flow (screen) name seen, in order (for calibrating the sequences)
--
-- Phases: idle -> to_search -> searching -> opening -> playing -> ending -> done (or error)

local DIR = "sf6_batch/"
local SEARCH_FLOW  = "app.UICFNReplayTopTabSearchChildSearchId.FlowParam"
local RESULT_FLOW  = "app.UICFNReplaySearchResult.FlowParam"
local INFO_FLOW    = "app.UICFNReplayInfoOnline.FlowParam"

-- A sequence is a list of {key, frames}: key held for that many frames ("" = no key).
-- Key names are via.hid.KeyboardKey names (F, S, Escape, Return, Back ...).
local DEFAULT_CFG = {
    -- from wherever we are after a replay (or the replay menu) to the Search-by-ID box
    to_search   = { {"Escape", 3}, {"", 30}, {"S", 3}, {"", 15}, {"S", 3}, {"", 15}, {"F", 3}, {"", 30}, {"Return", 3}, {"", 30} },
    -- on the search result list: pick the first result and open it
    on_results  = { {"", 30}, {"S", 3}, {"", 15}, {"F", 3}, {"", 30} },
    -- on the replay info screen: start watching
    on_info     = { {"", 30}, {"F", 3}, {"", 30} },
    -- after the match ends: move to "End Replay" (bottom of the menu) and confirm
    on_end      = { {"", 240}, {"S", 40}, {"", 15}, {"F", 3}, {"", 60} },
    retry_frames  = 240,    -- repeat a screen's sequence if the screen hasn't changed after this
    timeout_frames = 5400,  -- give up on a phase after 90 s
}

local cfg = DEFAULT_CFG
do
    local ok, user = pcall(json.load_file, DIR .. "config.json")
    if ok and type(user) == "table" then for k, v in pairs(user) do cfg[k] = v end end
end

-- ---------------------------------------------------------------- helpers
local function enum(typename)
    local t = sdk.find_type_definition(typename); local e = {}
    if not t then return e end
    for _, f in ipairs(t:get_fields()) do if f:is_static() then
        local ok, v = pcall(function() return f:get_data(nil) end)
        if ok and v ~= nil then e[v] = f:get_name() end end end
    return e
end
local KEYS = enum("via.hid.KeyboardKey")

local state = { seq = -1, phase = "idle", replay_id = nil, note = "", top_flow = "", fight_st = 0,
                phase_frames = 0, seq_pos = 0, seq_name = nil, seq_frame = 0, last_flow_change = 0, frame = 0, saw_fight = false }
local held = {}            -- key name -> true while a sequence step holds it
local update_frame = 0
local seen_flows = {}

local function log_flow(name)
    if seen_flows[name] then return end
    seen_flows[name] = true
    local ok, lines = pcall(json.load_file, DIR .. "flows.json")
    lines = (ok and type(lines) == "table") and lines or {}
    table.insert(lines, name); json.dump_file(DIR .. "flows.json", lines)
end

local function set_phase(p, note)
    if state.phase ~= p then state.phase = p; state.phase_frames = 0; state.seq_name = nil end
    if note then state.note = note end
end

-- start (or keep running) a key sequence by name
local function run_seq(name)
    if state.seq_name ~= name then state.seq_name = name; state.seq_pos = 1; state.seq_frame = 0 end
end

local function step_seq()
    held = {}
    local seqd = state.seq_name and cfg[state.seq_name]
    if not seqd then return end
    local st = seqd[state.seq_pos]
    if not st then state.seq_name = nil; return end   -- finished
    if st[1] ~= "" then held[st[1]] = true end
    state.seq_frame = state.seq_frame + 1
    if state.seq_frame >= st[2] then state.seq_pos = state.seq_pos + 1; state.seq_frame = 0 end
end

local function flow_items()
    local m = sdk.get_managed_singleton("app.UIFlowManager"); if not m then return nil end
    local h = m._Handles; return h and h._items
end

local function top_flow_name(items)
    local ok, n = pcall(function() return items[0]:get_field("<Param>k__BackingField"):get_type_definition():get_full_name() end)
    return ok and n or ""
end

local function find_flow(items, name)
    for i = 0, #items - 1 do
        local it = items[i]; if it == nil then return nil end
        local ok, p = pcall(function() return it:get_field("<Param>k__BackingField") end)
        if ok and p and p:get_type_definition():get_full_name() == name then return p end
    end
end

local function invoke_search(items, text)
    local f = find_flow(items, SEARCH_FLOW); if not f then return false end
    local w = f:get_field("<TextInputDialogWidget>k__BackingField"); if not w then return false end
    return pcall(function() w:InvokeResultEvent(text) end)
end

local function fight_state()
    local ok, v = pcall(function() return sdk.find_type_definition("gBattle"):get_field("Game"):get_data(nil).fight_st end)
    return ok and v or 0
end

local function capture_saved(id)
    local ok, d = pcall(json.load_file, id .. ".json")
    return ok and d ~= nil
end

-- ---------------------------------------------------------------- main loop
local function read_command()
    local ok, c = pcall(json.load_file, DIR .. "command.json")
    if not ok or type(c) ~= "table" or c.seq == nil or c.seq == state.seq then return end
    state.seq = c.seq
    if c.action == "play" and c.replay_id then
        state.replay_id = c.replay_id; state.saw_fight = false; set_phase("to_search", "new job")
    else
        state.replay_id = nil; set_phase("idle", "idle"); held = {}
    end
end

local function tick()
    state.frame = state.frame + 1; state.phase_frames = state.phase_frames + 1
    if state.frame % 30 == 0 then read_command() end
    local items = flow_items(); if not items then return end
    local top = top_flow_name(items)
    if top ~= state.top_flow then state.top_flow = top; state.last_flow_change = state.frame; log_flow(top) end
    state.fight_st = fight_state()
    local p = state.phase

    if p == "idle" or p == "done" or p == "error" then held = {}; return end
    if p ~= "playing" and p ~= "ending" and state.phase_frames > cfg.timeout_frames then
        set_phase("error", "timed out in phase " .. p .. " on screen " .. top); held = {}; return end

    if p == "to_search" then
        if find_flow(items, SEARCH_FLOW) and invoke_search(items, state.replay_id) then
            set_phase("searching", "search submitted")
        else
            run_seq("to_search")
            if state.seq_name == nil and state.phase_frames > 30 then run_seq("to_search") end  -- loop until the box opens
        end
    elseif p == "searching" or p == "opening" then
        if state.fight_st ~= 0 then set_phase("playing", "replay started"); held = {}; return end
        if top == RESULT_FLOW then set_phase("opening"); run_seq("on_results")
        elseif top == INFO_FLOW then set_phase("opening"); run_seq("on_info") end
        if state.seq_name == nil and state.frame - state.last_flow_change > cfg.retry_frames then
            state.last_flow_change = state.frame   -- same screen for too long: run its sequence again
            if top == RESULT_FLOW then run_seq("on_results") elseif top == INFO_FLOW then run_seq("on_info") end
        end
    elseif p == "playing" then
        held = {}
        if state.fight_st ~= 0 then state.saw_fight = true end
        if state.fight_st == 7 and capture_saved(state.replay_id) then set_phase("ending", "match over, capture saved") end
        if state.phase_frames > 60 * 60 * 15 then set_phase("error", "replay ran over 15 minutes") end
    elseif p == "ending" then
        run_seq("on_end")
        if state.fight_st == 0 and state.phase_frames > 120 then set_phase("done", "replay closed") end
        if state.phase_frames > cfg.timeout_frames then set_phase("done", "end menu not confirmed (check the screen)") end
    end
    step_seq()
end

local function write_status()
    json.dump_file(DIR .. "status.json", { seq = state.seq, phase = state.phase, replay_id = state.replay_id, note = state.note,
        top_flow = state.top_flow, fight_st = state.fight_st, held = held, frame = state.frame })
end

-- ---------------------------------------------------------------- key injection
-- Marks a held key as pressed when the game asks the keyboard for it (same trick as rkaganda's flow_control.lua).
local function inject(key)
    if key and held[KEYS[key.Value]] then key.Flags = 11; key.TriggerFrame = update_frame end
end
-- also press held keys directly in the keyboard state each frame (flow_control.lua does both)
local function press_held()
    local im = sdk.get_managed_singleton("app.InputManager"); if not im then return end
    local ks = im._State and im._State._Keyboard and im._State._Keyboard._Keys; if not ks then return end
    for _, key in pairs(ks) do if key then inject(key) end end
end

re.on_frame(function()
    local ok, err = pcall(tick)
    if next(held) then pcall(press_held) end
    if not ok then state.note = "lua error: " .. tostring(err) end
    if state.frame % 10 == 0 then pcall(write_status) end
end)

re.on_draw_ui(function()
    if imgui.tree_node("Batch replays") then
        imgui.text("Phase: " .. state.phase .. "  ID: " .. tostring(state.replay_id))
        imgui.text("Screen: " .. state.top_flow)
        imgui.text("Note: " .. state.note)
        if imgui.button("Stop") then set_phase("idle", "stopped from the REFramework menu"); held = {} end
        imgui.tree_pop()
    end
end)

local kb = sdk.find_type_definition("app.InputDeviceStateKeyboard")
if kb then
    sdk.hook(kb:get_method("GetDigital"), function(args) end, function(retval)
        local addr = sdk.to_int64(retval)
        if addr ~= 0 then pcall(inject, sdk.to_managed_object(retval)) end
        return retval
    end)
end
local ist = sdk.find_type_definition("app.InputState")
if ist then
    sdk.hook(ist:get_method("Update"), function(args) update_frame = sdk.to_int64(args[4]) end, function(r) return r end)
end
