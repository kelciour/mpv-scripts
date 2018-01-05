--  Usage:
--     Ctrl+b - create new bookmark.
--  Note:
--     File *.bookmarks.txt will be written after closing the video file.

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

function round(number, precision)
    return math.floor(number / precision + 0.5) * precision
end

function add_bookmark()
    local pos = round(mp.get_property_number("time-pos"), 0.01)
    local text = string.gsub(mp.get_property("sub-text"), "\n", " ")

    bookmarks[pos] = text

    mp.osd_message("●")
end

function table_length(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

function get_sorted_keys(t)
    local keys = {}
    for key in pairs(t) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

function write_bookmarks()
    if table_length(bookmarks) ~= 0 then
        local f_txt = assert(io.open(txt_bookmarks_filename, "w"))

        local keys = get_sorted_keys(bookmarks)

        for _, key in ipairs(keys) do
            f_txt:write(seconds_to_srt_time(key) .. "\t" .. bookmarks[key], '\n')
        end
        
        f_txt:close()
    end
end

function load_bookmarks()
    bookmarks = {}
    local f, err = io.open(txt_bookmarks_filename, "r")
    if f then
        for line in f:lines() do
            pos, text = line:match("^(.-)\t(.-)$")
            bookmarks[srt_time_to_seconds(pos)] = text
        end
    end
end

function init()
    txt_bookmarks_filename = mp.get_property("working-directory") .. "/" .. mp.get_property("filename/no-ext") .. ".bookmarks.txt"

    load_bookmarks()
end

mp.register_event("file-loaded", init)
mp.register_event("end-file", write_bookmarks)

mp.add_key_binding("ctrl+b", "add-bookmark", add_bookmark)
