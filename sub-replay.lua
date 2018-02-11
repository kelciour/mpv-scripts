-- Usage:
--         a - replay previous sentence 
--         A - replay previous sentence (with subtitles visible)
--    Ctrl+a - skip to the next subtitle
-- Note:
--    Requires the subtitles (*.srt) alongside with the video file.
-- Status:
--    Experimental.

------- Script Options -------
srt_file_extensions = {".srt", ".en.srt", ".eng.srt"}
sub_start_shift = 0.25
------------------------------

function srt_time_to_seconds(time)
    local major, minor = time:match("(%d%d:%d%d:%d%d),(%d%d%d)")
    local hours, mins, secs = major:match("(%d%d):(%d%d):(%d%d)")
    return hours * 3600 + mins * 60 + secs + minor / 1000
end

function open_subtitles_file()
    local srt_base_filename = mp.get_property("working-directory") .. "/" .. mp.get_property("filename/no-ext")
    
    for i, ext in ipairs(srt_file_extensions) do
        local f, err = io.open(srt_base_filename .. ext, "r")
        
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
        local sub_start = subs_start[i]
        local sub_end = subs_end[i]
        local sub_text = string.gsub(sub_text, "<[^>]+>", "")

        if sub_text:find("^- ") ~= nil and sub_text:sub(3,3) ~= sub_text:sub(3,3):upper() then
           sub_text = string.gsub(sub_text, "^- ", "")
        end

        if #sentences > 0 then
            local prev_sub_start = sentences_start[#sentences]
            local prev_sub_end = sentences_end[#sentences]
            local prev_sub_text = sentences[#sentences]

            if (sub_start - prev_sub_end) <= 2 and sub_text:sub(1,1) ~= '-' and 
                    sub_text:sub(1,1) ~= '"' and sub_text:sub(1,1) ~= "'" and sub_text:sub(1,1) ~= '(' and
                    (prev_sub_text:sub(prev_sub_text:len()) ~= "." or prev_sub_text:sub(prev_sub_text:len()-2) == "...") and
                    prev_sub_text:sub(prev_sub_text:len()) ~= "?" and prev_sub_text:sub(prev_sub_text:len()) ~= "!" and
                    (sub_text:sub(1,1) == sub_text:sub(1,1):lower() or prev_sub_text:sub(prev_sub_text:len()) == ",") then
                
                local text = sentences[#sentences] .. " " .. sub_text
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

function get_current_sentence_id()
    local pos = mp.get_property_number("time-pos")

    if pos == nil then
        return nil
    end

    local sub_id = 1
    while sub_id < #sentences and sentences_end[sub_id] < pos do
      sub_id = sub_id + 1
    end

    return sub_id
end

function replay_previous_sentence(show_subs)
    local pos = mp.get_property_number("time-pos")
    local sub_id = get_current_sentence_id()

    if sub_id ~= nil and pos ~= nil then
        local prev_sub_id = 1 
        if sub_id > 1 then
            prev_sub_id = sub_id - 1
        end

        if sentences_start[sub_id] <= pos and pos <= sentences_end[sub_id] then
            if (pos - sentences_start[sub_id]) / (sentences_end[sub_id] - sentences_start[sub_id]) > 0.6 then
                prev_sub_id = sub_id
            end
        end

        if sub_visibility == nil then
            sub_visibility = mp.get_property("sub-visibility")
        end
        
        sub_duration = sentences_end[prev_sub_id] - sentences_start[prev_sub_id]

        if show_subs == true then
            replay_with_subtitles = true
        else
            replay_with_subtitles = false
        end

        player_state = "replay"
        mp.set_property("sub-visibility", "no")
        mp.commandv("seek", sentences_start[prev_sub_id] - sub_start_shift, "absolute+exact")
    end
end

function replay_previous_sentence_with_subtitles()
    replay_previous_sentence(true)
end

function skip_to_the_previous_subtitle()
    local pos = mp.get_property_number("time-pos")

    if pos ~= nil then
        local sub_id = 1
        while sub_id < #subs and subs_end[sub_id] < pos do
          sub_id = sub_id + 1
        end

        if sub_id > 1 then
            mp.commandv("seek", subs_start[sub_id - 1] + 0.025, "absolute+exact")
        end
    end
end

function skip_to_the_next_subtitle()
    mp.commandv("sub-seek", "1")
end

function show_subtitles()
    mp.set_property("sub-visibility", "yes")
end

function hide_subtitles()
    mp.set_property("sub-visibility", "no")
end

function on_seek()
    if player_state == "replay" then
        mp.set_property("pause", "no")
    end
end

function on_playback_restart()
    if player_state == "replay" then
        player_state = nil

        if show_timer ~= nil then
            show_timer:kill()
        end

        if hide_timer ~= nil then
            hide_timer:kill()
        end

        if replay_with_subtitles == true or sub_visibility == "yes" then
            show_timer = mp.add_timeout(sub_start_shift + 0.05, show_subtitles)
        end

        if sub_visibility == "no" then
            hide_timer = mp.add_timeout(sub_start_shift + sub_duration - 0.05, hide_subtitles)
        end
    end
end

function init()
    local ret = read_subtitles()

    if ret == false or #subs == 0 then
        return
    end
    
    convert_into_sentences()
       
    mp.register_event("seek", on_seek)
    mp.register_event("playback-restart", on_playback_restart)

    mp.add_key_binding("a", "replay-previous-sentence", replay_previous_sentence)
    mp.add_key_binding("A", "replay-previous-sentence-with-subtitles", replay_previous_sentence_with_subtitles)
    mp.add_key_binding("ctrl+a", "skip-to-the-next-subtitle", skip_to_the_next_subtitle)
    mp.add_key_binding("ctrl+left", "skip-to-the-previous-subtitle", skip_to_the_previous_subtitle)
end

mp.register_event("file-loaded", init)
