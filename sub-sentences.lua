-- Usage:
--    Ctrl+t - create subtitles with sentences (and automatically select as default subtitles with visibility set to true)
-- Note: 
--	  Requires the subtitle file (*.srt) alongside with the video file.

------- Script Options -------
srt_file_extensions = {".srt", ".en.srt", ".eng.srt"}
------------------------------

function srt_time_to_seconds(time)
    local major, minor = time:match("(%d%d:%d%d:%d%d),(%d%d%d)")
    local hours, mins, secs = major:match("(%d%d):(%d%d):(%d%d)")
    return hours * 3600 + mins * 60 + secs + minor / 1000
end

function seconds_to_srt_time(time)
    local hours = math.floor(time / 3600)
    local mins = math.floor(time / 60) % 60
    local secs = math.floor(time % 60)
    local milliseconds = (time * 1000) % 1000

    return string.format("%02d:%02d:%02d,%03d", hours, mins, secs, milliseconds)
end

function open_subtitles_file(srt_file_exts)
    local srt_base_filename = mp.get_property("working-directory") .. "/" .. mp.get_property("filename/no-ext")
    
    for i, ext in ipairs(srt_file_exts) do
        local f, err = io.open(srt_base_filename .. ext, "r")
        
        if f then
            return f
        end
    end

    return false
end

function read_subtitles(srt_file_exts)
    local f = open_subtitles_file(srt_file_exts)

    if not f then
        return false
    end

    local data = f:read("*all")
    data = string.gsub(data, "\r\n", "\n")
    f:close()
    
    local subs = {}
    local subs_start = {}
    local subs_end = {}
    
    for start_time, end_time, text in string.gmatch(data, "(%d%d:%d%d:%d%d,%d%d%d) %-%-> (%d%d:%d%d:%d%d,%d%d%d)\n(.-)\n\n") do
      table.insert(subs, text)
      table.insert(subs_start, srt_time_to_seconds(start_time))
      table.insert(subs_end, srt_time_to_seconds(end_time))
    end

    return subs, subs_start, subs_end
end

function convert_into_sentences(subs, subs_start, subs_end)
    local sentences = {}
    local sentences_start = {}
    local sentences_end = {}

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

    return sentences, sentences_start, sentences_end
end

function write_subtitles(subs, subs_start, subs_end, srt_filename)
	if subs ~= nil then
        local f = assert(io.open(srt_filename, "w"))

        for i, sub_text in ipairs(subs) do
            local sub_start = subs_start[i]
            local sub_end = subs_end[i]

            f:write(i, "\n")
            f:write(seconds_to_srt_time(sub_start) .. " --> " .. seconds_to_srt_time(sub_end), "\n")
            f:write(sub_text, "\n\n")
        end

        f:close()

        return true
    end
	return false
end

function create_subtitles_with_sentences()
	local subs, subs_start, subs_end = read_subtitles(srt_file_extensions)
	local sentences, sentences_start, sentences_end = convert_into_sentences(subs, subs_start, subs_end)
    
    local srt_filename = mp.get_property("working-directory") .. "/" .. mp.get_property("filename/no-ext") .. ".sentences.srt"
    
    local ret = write_subtitles(sentences, sentences_start, sentences_end, srt_filename)
    if ret then
    	mp.commandv("sub-add", srt_filename)
        mp.set_property("sub-visibility", "yes")
    	mp.osd_message("Finished creating subtitles with sentences")
    else
    	mp.osd_message("Failed to create subtitles with sentences")
    end
end

mp.add_key_binding("ctrl+t", "create-subtitles-with-sentences", create_subtitles_with_sentences)