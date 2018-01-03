-- Usage:
--    Ctrl+b - create bilingual subtitles (and automatically select as default subtitles with visibility set to true)
-- Note: 
--    Requires the original subtitles and translated subtitles (*.srt) alongside with the video file. 
-- Status:
--    Experimental & not interested & abandoned.

------- Script Options -------
srt_original_file_extensions = {".srt", ".en.srt", ".eng.srt"}
srt_translated_file_extensions = {".ru.srt", ".rus.srt"}
------------------------------

function srt_time_to_seconds(time)
    local major, minor = time:match("(%d%d:%d%d:%d%d),(%d%d%d)")
    local hours, mins, secs = major:match("(%d%d):(%d%d):(%d%d)")
    return hours * 3600 + mins * 60 + secs + minor / 1000
end

function seconds_to_ass_time(time)
    local hours = math.floor(time / 3600)
    local mins = math.floor(time / 60) % 60
    local secs = math.floor(time % 60)
    local milliseconds = (time * 1000) % 1000

    return string.format("%d:%02d:%02d.%02d", hours, mins, secs, milliseconds / 10)
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

    local subs = {}
    local subs_start = {}
    local subs_end = {}

    if f then
        local data = f:read("*all")
        data = string.gsub(data, "\r\n", "\n")
        f:close()
        
        for start_time, end_time, text in string.gfind(data, "(%d%d:%d%d:%d%d,%d%d%d) %-%-> (%d%d:%d%d:%d%d,%d%d%d)\n(.-)\n\n") do
          table.insert(subs, text)
          table.insert(subs_start, srt_time_to_seconds(start_time))
          table.insert(subs_end, srt_time_to_seconds(end_time))
        end
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

function string.starts(s, substring)
   return string.sub(s, 1, string.len(substring)) == substring
end

function write_bilingual_subtitles(subs_original, subs_original_start, subs_original_end, subs_translated, subs_translated_start, subs_translated_end, subtitles_filename)
    if #subs_original == 0 or #subs_translated == 0 then
        return false
    end

    local f = assert(io.open(subtitles_filename, "w"))

    f:write("[Script Info]", "\n\n")
    f:write("[V4+ Styles]", "\n")
    f:write("Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding", "\n")
    f:write("Style: Russian,Arial,16,&H009DDFF1,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,1,0,2,10,10,10,1", "\n")
    f:write("Style: English,Arial,20,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,1,0.25,2,10,10,10,1", "\n")
    f:write("[Events]", "\n")
    f:write("Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text", "\n")
    
    local translated_sub_lines = {}
    
    for i, sub_text in ipairs(subs_original) do
        local sub_start = subs_original_start[i]
        local sub_end = subs_original_end[i]
        sub_text = string.gsub(sub_text, "\n", " ")

        local flag = false
        local sub_line = ""
        for j, second_sub_text in ipairs(subs_translated) do
            local second_sub_start = subs_translated_start[j]
            local second_sub_end = subs_translated_end[j]
            second_sub_text = string.gsub(second_sub_text, "\n", " ")
            second_sub_text = string.gsub(second_sub_text, "<[^>]+>", "")

            if second_sub_end > sub_start and second_sub_start < sub_end then
                local s_sub_start = second_sub_start > sub_start and second_sub_start or sub_start
                local s_sub_end = second_sub_end > sub_end and sub_end or second_sub_end
                local s_sub_length = s_sub_end - s_sub_start

                if ((second_sub_start <= sub_start and second_sub_end >= sub_end) or (second_sub_start >= sub_start and second_sub_end <= sub_end)) or 
                   (s_sub_length > 0.5) then

                    if flag then
                        sub_line = sub_line .. " "
                    end
                    sub_line = sub_line .. second_sub_text
                    flag = true
                end
            end

            if second_sub_end > sub_end then
                break
            end
        end
        
        if flag then 
            table.insert(translated_sub_lines, sub_line)
        else
            table.insert(translated_sub_lines, "")
        end
    end

    local sub_line = ""
    local sub_line_start, sub_line_end
    for i, sub_text in ipairs(subs_original) do
        local sub_start = subs_original_start[i]
        local sub_end = subs_original_end[i]
        local sub_text = string.gsub(sub_text, "\n", " ")
        
        if i == 1 then
            sub_line = sub_text
            sub_line_start = sub_start
            sub_line_end = sub_end
        else
            if (translated_sub_lines[i] == translated_sub_lines[i-1] or string.starts(translated_sub_lines[i], translated_sub_lines[i-1])) and translated_sub_lines[i] ~= "" then
                sub_line = sub_line .. " " .. sub_text
                sub_line_end = sub_end
            else
                f:write(string.format("Dialogue: 0,%s,%s,Russian,,0,0,0,,%s\n", seconds_to_ass_time(sub_line_start), seconds_to_ass_time(sub_line_end), translated_sub_lines[i-1]))
                f:write(string.format("Dialogue: 0,%s,%s,English,,0,0,0,,%s\n", seconds_to_ass_time(sub_line_start), seconds_to_ass_time(sub_line_end), sub_line))
    
                sub_line = sub_text
                sub_line_start = sub_start
                sub_line_end = sub_end
            end
        end
    end
    f:write(string.format("Dialogue: 0,%s,%s,Russian,,0,0,0,,%s\n", seconds_to_ass_time(sub_line_start), seconds_to_ass_time(sub_line_end), translated_sub_lines[#translated_sub_lines]))
    f:write(string.format("Dialogue: 0,%s,%s,English,,0,0,0,,%s\n", seconds_to_ass_time(sub_line_start), seconds_to_ass_time(sub_line_end), sub_line))

    f:close()

    return true
end

function create_bilingual_subtitles()
	local subs_translated, subs_translated_start, subs_translated_end = read_subtitles(srt_translated_file_extensions)

    local subs_original, subs_original_start, subs_original_end = read_subtitles(srt_original_file_extensions)
    local sentences_original, sentences_original_start, sentences_original_end = convert_into_sentences(subs_original, subs_original_start, subs_original_end)

    local subtitles_filename = mp.get_property("working-directory") .. "/" .. mp.get_property("filename/no-ext") .. ".ass"
    
    local ret = write_bilingual_subtitles(sentences_original, sentences_original_start, sentences_original_end, subs_translated, subs_translated_start, subs_translated_end, subtitles_filename)
    if ret then
    	mp.commandv("sub-add", subtitles_filename)
        mp.set_property("sub-visibility", "yes")
    	mp.osd_message("Finished creating bilingual subtitles")
    else
    	mp.osd_message("Failed to create bilingual subtitles")
    end
end

mp.add_key_binding("ctrl+b", "create-bilingual-subtitles", create_bilingual_subtitles)