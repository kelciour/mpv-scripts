-- Usage:
--    i - subtitle mode on/off
--    ↑, ↓ (Space) - mode specific shortcuts
-- Note:
--    The script is inspired by voracious.app (https://github.com/rsimmons/voracious).
--    
--    - Listening Practice:
--        "Subtitles are initially hidden. At the end of each subtitle, the video will pause automatically. 
--         Could you hear what was said? Press ↑ to replay, if necessary. 
--         Then press ↓ to reveal the subs, and check if you heard correctly.
--         Then press ↓ to unpause the video."
--    
--    - Reading Practice:
--        "At the start of each new subtitle, the video will pause automatically.
--         Try reading the sub. Then press ↓ to unpause the video, and hear it spoken.
--         Did you read it correctly?"
--    
----------------------------------

--------- Script Options ---------
srt_file_extensions = {".srt", ".en.srt", ".eng.srt"}
----------------------------------
sub_pad_start = 0.25
sub_pad_end = 0.2
----------------------------------

function srt_time_to_seconds(time)
    major, minor = time:match("(%d%d:%d%d:%d%d),(%d%d%d)")
    hours, mins, secs = major:match("(%d%d):(%d%d):(%d%d)")
    return hours * 3600 + mins * 60 + secs + minor / 1000
end

function seconds_to_srt_time(time)
    hours = math.floor(time / 3600)
    mins = math.floor(time / 60) % 60
    secs = math.floor(time % 60)
    milliseconds = (time * 1000) % 1000

    return string.format("%02d:%02d:%02d,%03d", hours, mins, secs, milliseconds)
end

function open_subtitles_file()
    local video_path = mp.get_property("path")
    local srt_filename = video_path:gsub('\\','/'):match("^(.+)/.+$") .. "/" .. mp.get_property("filename/no-ext")

    for i, ext in ipairs(srt_file_extensions) do
        local f, err = io.open(srt_filename .. ext, "r")

        if f then
            return f
        end
    end

    return false
end

function read_subtitles()
    local f = open_subtitles_file()

    if not f then
        return false
    end

    local data = f:read("*all")
    data = string.gsub(data, "\r\n", "\n")
    f:close()

    subs = {}
    subs_start = {}
    subs_end = {}
    for start_time, end_time, text in string.gmatch(data, "(%d%d:%d%d:%d%d,%d%d%d) %-%-> (%d%d:%d%d:%d%d,%d%d%d)\n(.-)\n\n") do
        if not filter_subtitles(text) then
            table.insert(subs, text)
            table.insert(subs_start, srt_time_to_seconds(start_time))
            table.insert(subs_end, srt_time_to_seconds(end_time))
        end
    end

    return true
end

function filter_subtitles(text)
    if string.match(text, "^%[(.*)%]$") then
        return true
    end

    return false
end

function adjust_subtitles()
    sub_id = 1

    while sub_id < #subs do
        if subs_start[sub_id + 1] - subs_end[sub_id] > sub_pad_end then
            subs_end[sub_id] = subs_end[sub_id] + sub_pad_end
        elseif subs_start[sub_id + 1] - subs_end[sub_id] > 0 then
            subs_end[sub_id] = subs_end[sub_id] + (subs_start[sub_id + 1] - subs_end[sub_id]) / 2
        end

        if subs_start[sub_id + 1] - subs_end[sub_id] > sub_pad_start then
            subs_start[sub_id + 1] = subs_start[sub_id + 1] - sub_pad_start
        elseif subs_start[sub_id + 1] - subs_end[sub_id] > 0 then
            subs_start[sub_id + 1] = subs_start[sub_id + 1] - (subs_start[sub_id + 1] - subs_end[sub_id]) / 2
        end

        sub_id = sub_id + 1
    end

    subs_start[1] = subs_start[1] - sub_pad_start
    subs_end[#subs] = subs_end[#subs] + sub_pad_end
end

function update_sub_id()
    local pos = mp.get_property_number("time-pos")

    if pos == nil then
        sub_id = nil
        return
    end

    sub_id = 1
    while sub_id < #subs and subs_end[sub_id] < pos do
        sub_id = sub_id + 1
    end

    if subtitle_mode == "Reading Practice" and sub_id < #subs then
        sub_id = sub_id + 1
    end
end

function replay_sub_without_subtitles()
    if sub_id ~= nil then
        player_state = "replay"
        mp.set_property("sub-visibility", "no")
        mp.commandv("seek", subs_start[sub_id], "absolute+exact")
    end
end

function on_seek()
    if player_state ~= "replay" then
        update_sub_id()
    end
end

function on_playback_restart()
    if player_state == "replay" then
        mp.set_property("pause", "no")
        player_state = nil
    end
end

function on_up_arrow_key()
    if subtitle_mode == "Listening Practice" then
        replay_sub_without_subtitles()
    end
end

function on_down_arrow_key()
    if player_state == "pause" then
        if mp.get_property("sub-visibility") == "no" then
            mp.set_property("sub-visibility", "yes")
        else
            mp.set_property("sub-visibility", "no")
            mp.set_property("pause", "no")
            player_state = nil

            if sub_id < #subs then
                sub_id = sub_id + 1
            else
                sub_id = nil
            end
        end
    end
end

function on_space_key()
    if player_state == "pause" then
        on_down_arrow_key()
    else
        mp.set_property_bool("pause", not mp.get_property_bool("pause"))
    end
end

function subtitle_mode_timer()
    local pos = mp.get_property_number("time-pos")

    if pos ~= nil then
        if sub_id ~= nil and mp.get_property("pause") ~= "yes" then
            if subtitle_mode == "Listening Practice" and pos >= subs_end[sub_id] then
                mp.set_property("pause", "yes")
                player_state = "pause"
            elseif subtitle_mode == "Reading Practice" then
                if (pos + 0.25) >= subs_start[sub_id] then
                    mp.set_property("sub-visibility", "yes")
                end
                    
                if pos >= subs_start[sub_id] then
                    mp.set_property("pause", "yes")
                    player_state = "pause"
                end
            end
        end
    end
end

function init_subtitle_mode()
    default_sub_visibility = mp.get_property("sub-visibility")

    mp.set_property("sub-visibility", "no")

    timer = mp.add_periodic_timer(0.05, subtitle_mode_timer)

    update_sub_id()

    mp.add_key_binding("up", "up-arrow-key", on_up_arrow_key)
    mp.add_key_binding("down", "down-arrow-key", on_down_arrow_key)
    mp.add_key_binding("space", "space-arrow-key", on_space_key)

    mp.register_event("seek", on_seek)
    mp.register_event("playback-restart", on_playback_restart)
end

function release_subtitle_mode()
    mp.set_property("sub-visibility", default_sub_visibility)

    timer:kill()

    mp.remove_key_binding("up-arrow-key")
    mp.remove_key_binding("down-arrow-key")
    mp.remove_key_binding("space-arrow-key")

    mp.unregister_event(on_seek)
    mp.unregister_event(on_playback_restart)
end

function toggle_subtitle_mode()
    if subtitle_mode == nil then
        subtitle_mode = "Listening Practice"
        mp.set_property("sub-delay", sub_pad_end + 0.25)
    elseif subtitle_mode == "Listening Practice" then
        subtitle_mode = "Reading Practice"
        mp.set_property("sub-delay", -sub_pad_start - 0.25)
    else
        mp.set_property("sub-delay", 0)
        subtitle_mode = nil
    end

    if subtitle_mode ~= nil then
        mp.osd_message("Subtitle Mode: " .. subtitle_mode)
        init_subtitle_mode()
    else
        mp.osd_message("Subtitle Mode: " .. "Off")
        release_subtitle_mode()
    end
end

function init()
    local ret = read_subtitles()

    if ret == false or #subs == 0 then
        return
    end

    adjust_subtitles()

    mp.add_key_binding("i", "toggle-interactive-mode", toggle_subtitle_mode)
end

mp.register_event("file-loaded", init)