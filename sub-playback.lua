-- Usage:
--    i - interactive mode on/off
-- Note:
--    Playback will be automatically paused at the end of the fragment
--    Hotkeys will be:
--      Space - continue playback
--      a - replay current fragment without subtitles
--      A - replay current fragment with subtitle
--    If current playback position is between fragments then 'a' or 'A' will skip to the next fragment.

--------- Script Options ---------
srt_file_extensions = {".srt", ".en.srt", ".eng.srt"}

gap_between_phrases = 1.25
phrase_padding = 0.25
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
    local srt_filename = mp.get_property("working-directory") .. "/" .. mp.get_property("filename/no-ext")
    
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
      table.insert(subs, text)
      table.insert(subs_start, srt_time_to_seconds(start_time))
      table.insert(subs_end, srt_time_to_seconds(end_time))
    end

    return true
end

function convert_into_sentences()
    sentences = {}
    sentences_start = {}
    sentences_end = {}

    for i, sub_text in ipairs(subs) do
        sub_start = subs_start[i]
        sub_end = subs_end[i]
        sub_text = string.gsub(sub_text, "<[^>]+>", "")

        if sub_text:find("^- ") ~= nil and sub_text:sub(3,3) ~= sub_text:sub(3,3):upper() then
           sub_text = string.gsub(sub_text, "^- ", "")
        end

        if #sentences > 0 then
            prev_sub_start = sentences_start[#sentences]
            prev_sub_end = sentences_end[#sentences]
            prev_sub_text = sentences[#sentences]

            if (sub_start - prev_sub_end) <= 2 and sub_text:sub(1,1) ~= '-' and 
                    sub_text:sub(1,1) ~= '"' and sub_text:sub(1,1) ~= "'" and sub_text:sub(1,1) ~= '(' and
                    (prev_sub_text:sub(prev_sub_text:len()) ~= "." or prev_sub_text:sub(prev_sub_text:len()-2) == "...") and
                    prev_sub_text:sub(prev_sub_text:len()) ~= "?" and prev_sub_text:sub(prev_sub_text:len()) ~= "!" and
                    (sub_text:sub(1,1) == sub_text:sub(1,1):lower() or prev_sub_text:sub(prev_sub_text:len()) == ",") then
                local text = prev_sub_text .. " " .. sub_text
                text = string.gsub(text, "\n", "#")
                text = string.gsub(text, "%.%.%. %.%.%.", " ")
                text = string.gsub(text, "#%-", "\n-")
                text = string.gsub(text, "#", " ")
                if text:match("\n%-") ~= nil and text:match("^%-") == nil then
                    text = "- " .. text
                end
                
                sentences[#sentences] = text
                sentences_end[#sentences] = sub_end
            else
                table.insert(sentences, sub_text)
                table.insert(sentences_start, sub_start)
                table.insert(sentences_end, sub_end)    
            end
        else
            table.insert(sentences, sub_text)
            table.insert(sentences_start, sub_start)
            table.insert(sentences_end, sub_end)
        end
    end
end

function convert_into_phrases()
    phrases = {}
    phrases_start = {}
    phrases_end = {}

    for i, s_text in ipairs(sentences) do
        s_start = sentences_start[i]
        s_end = sentences_end[i]

        if #phrases > 0 and gap_between_phrases > 0 and (s_start - prev_s_end) <= gap_between_phrases then
            prev_s_text = phrases[#phrases]

            phrases[#phrases] = prev_s_text .. " " .. s_text
            phrases_end[#phrases] = s_end
        else
            table.insert(phrases, s_text)
            table.insert(phrases_start, s_start)
            table.insert(phrases_end, s_end)
        end

        prev_s_end = s_end
    end
end

function get_the_next_phrase_end()
    local pos = mp.get_property_number("time-pos")

    if pos ~= nil then
        for i, text in ipairs(phrases) do
            if phrases_end[i] > pos then
                return phrases_end[i]
            end
        end
    end

    return false
end

function update_phrase_id()
    local pos = mp.get_property_number("time-pos")

    if pos == nil then
        phrase_id = nil
        return
    end

    phrase_id = 1
    while phrase_id < #phrases and phrases_end[phrase_id] <= pos do
      phrase_id = phrase_id + 1
    end
end

function toggle_playback()
    if mp.get_property("pause") == "yes" then
        if player_state == "pause" then
            player_state = nil
            if phrase_id < #phrases then
                phrase_id = phrase_id + 1
            else
                phrase_id = nil
            end
        end
        mp.set_property("pause", "no")
    else
        mp.set_property("pause", "yes")
    end
end

function pause_playback()
    mp.set_property("pause", "yes")
end

function show_subtitles()
    mp.set_property("sub-visibility", "yes")
end

function hide_subtitles()
    mp.set_property("sub-visibility", "no")
end

function replay_phrase()
    player_state = nil
    if phrase_id ~= nil then
        player_state = "replay"        
        mp.commandv("seek", phrases_start[phrase_id] - phrase_padding, "absolute+exact")
    end
end

function replay_phrase_with_subtitles()
    player_state = nil
    if phrase_id ~= nil then
        player_state = "replay-with-subtitles"        
        mp.commandv("seek", phrases_start[phrase_id] - phrase_padding, "absolute+exact")
    end
end

function on_seek()
    if player_state ~= "replay" and player_state ~= "replay-with-subtitles" then
        player_state = nil
        update_phrase_id()
    end

    if timer_pause ~= nil then
        timer_pause:kill()
    end
end

function on_playback_restart()
    if player_state == "replay" or player_state == "replay-with-subtitles" then
        mp.set_property("pause", "no")
    end

    if player_state == "replay" then
        hide_subtitles()
    elseif player_state == "replay-with-subtitles" then
        show_subtitles()
    end
end

function interactive_mode()
    local pos = mp.get_property_number("time-pos")

    if pos ~= nil then
        if phrase_id ~= nil and player_state ~= "pause" and pos >= phrases_end[phrase_id] then
            if player_state == "replay-with-subtitles" then
                hide_subtitles()
            end

            player_state = "pause"

            local ass_start = mp.get_property_osd("osd-ass-cc/0")
            local ass_stop = mp.get_property_osd("osd-ass-cc/1")
            mp.osd_message(ass_start .. "{\\fs12}▐▐" .. ass_stop, 0.75)

            timer_pause = mp.add_timeout(phrase_padding, pause_playback)
        end
    end
end

function init_interactive_mode()
    mp.osd_message("Interactive mode: on")
    playback_interactive_mode = true

    mp.set_property("sub-visibility", "no")

    timer = mp.add_periodic_timer(0.05, interactive_mode)
    
    update_phrase_id()

    mp.add_key_binding("a", "replay-phrase", replay_phrase)
    mp.add_key_binding("A", "replay-phrase-with-subtitles", replay_phrase_with_subtitles)
    mp.add_key_binding("space", "toggle-playback", toggle_playback)

    mp.register_event("seek", on_seek)
    mp.register_event("playback-restart", on_playback_restart)
end

function release_interactive_mode()
    mp.osd_message("Interactive mode: off")
    playback_interactive_mode = false

    timer:kill()

    mp.remove_key_binding("replay-phrase")
    mp.remove_key_binding("replay-phrase-with-subtitles")
    mp.remove_key_binding("toggle-playback")

    mp.unregister_event(on_seek)
    mp.unregister_event(on_playback_restart)
end

function toggle_interactive_mode()
    if playback_interactive_mode ~= true then
        init_interactive_mode()
    else
        release_interactive_mode()
    end
end

function init()
    local ret = read_subtitles()

    if ret == false or #subs == 0 then
        return
    end
    
    convert_into_sentences()
    convert_into_phrases()

    mp.add_key_binding("i", "toggle-interactive-mode", toggle_interactive_mode)
end

mp.register_event("file-loaded", init)
