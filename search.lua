--[[
Usage:
    Open REPL (https://github.com/rossy/mpv-repl), print 'script-message search <word>' or 'script-message search "<phrase>"' and press ENTER.
--]] 

local srt_file_extensions = {".srt", ".en.srt", ".eng.srt"}

function srt_time_to_seconds(time)
    major, minor = time:match("(%d%d:%d%d:%d%d),(%d%d%d)")
    hours, mins, secs = major:match("(%d%d):(%d%d):(%d%d)")
    return hours * 3600 + mins * 60 + secs + minor / 1000
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

function load_subtitles_file()
    local f = open_subtitles_file()

    if not f then
        return false
    end

    data = f:read("*all")
    data = string.gsub(data, "\r\n", "\n")
    data = string.gsub(data, "\n\n", "\0")
    f:close()

    return true
end

-- https://www.lua.org/pil/20.4.html
function nocase(s)
    s = string.gsub(s, "%a", function (c)
        return string.format("[%s%s]", string.lower(c), string.upper(c))
      end)
    return s
end

function search(phrase)
    if data == nil then
        local ret = load_subtitles_file()
        if ret ~= true then
            mp.osd_message("Can't find external subtitles.")
            return
        end
    end

    local time_pos = mp.get_property_number("time-pos")
    if prev_phrase ~= nil and prev_phrase == phrase then
        search_idx = (search_idx % #search_results) + 1
    else
        idx = 0
        search_idx = 0
        search_results = {}
        prev_phrase = phrase
        for start_time, end_time, text in string.gfind(data, "(%d%d:%d%d:%d%d,%d%d%d) %-%-> (%d%d:%d%d:%d%d,%d%d%d)\n([^%z]-" .. nocase(phrase) .. "[^%z]-)") do
            idx = idx + 1
            
            start_time = srt_time_to_seconds(start_time)            
            if start_time >= time_pos and search_idx == 0 then
                search_idx = idx
            end

            table.insert(search_results, start_time)
        end

        if search_idx == 0 then
            search_idx = 1
        end
    end

    if #search_results ~= 0 then
        mp.commandv("seek", search_results[search_idx], "absolute+exact")
        print(string.format("%s [%s/%s]", phrase, search_idx, #search_results))
    else
        print(string.format("%s [0/0]", phrase))
    end
end

mp.register_script_message("search", search)
