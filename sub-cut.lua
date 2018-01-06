--  Usage:
--     ctrl+w - set start timestamp
--     ctrl+e - set end timestamp
--     ctrl+z - cut audio fragment
--     ctrl+x - cut video fragment (with softsub subtitles)
--     ctrl+c - cut video fragment with hardsub subtitles
--  Note:
--     Export video with softsub or hardsub subtitles requires external *.srt subtitles.
--  Note: 
--     The default video encoding preset is "ultrafast". It can be replaced with "medium" (~2 times more slower but ~2 times less filesize).
--  Note:
--     This script requires FFmpeg to be installed:
--        - Windows - https://ffmpeg.zeranoe.com
--        - Linux - google it
--        - macOS - install it via brew (https://brew.sh): brew install ffmpeg
--     (For Windows) Update ffmpeg_path in the script options if ffmpeg isn't in PATH environment variable,
--        for example, by replacing [[ffmpeg]] with [[C:\Programs\ffmpeg\bin\ffmpeg.exe]]
-- Status:
--     Experimental.

local utils = require "mp.utils"

------- Script Options -------
ffmpeg_path = [[ffmpeg]]
srt_file_extensions = {".srt", ".en.srt", ".eng.srt"}
video_encoding_preset = [[ultrafast]]
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

function seconds_to_time_string(duration, flag)
    local hours = math.floor(duration / 3600)
    local minutes = math.floor(duration / 60 % 60)
    local seconds = math.floor(duration % 60)
    local milliseconds = (duration * 1000) % 1000
    if not flag then
        return string.format("%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    else
        return string.format("%02d.%02d.%02d", hours, minutes, seconds)
    end
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
    for start_time, end_time, text in string.gfind(data, "(%d%d:%d%d:%d%d,%d%d%d) %-%-> (%d%d:%d%d:%d%d,%d%d%d)\n(.-)\n\n") do
      table.insert(subs, text)
      table.insert(subs_start, srt_time_to_seconds(start_time))
      table.insert(subs_end, srt_time_to_seconds(end_time))
    end

    return true
end

function set_start_timestamp()
    start_timestamp = mp.get_property_number("time-pos")
    mp.osd_message("Start: " .. seconds_to_time_string(start_timestamp), 1)
end

function set_end_timestamp()
    end_timestamp = mp.get_property_number("time-pos")
    mp.osd_message("End: " .. seconds_to_time_string(end_timestamp), 1)
end

function write_subtitles_fragment(srt_filename, clip_start, clip_end)
    ret = read_subtitles()
    if ret == false or #subs == 0 then
        return
    end

    local i = 1
    local f = assert(io.open(srt_filename, "w"))
    for idx, sub_content in ipairs(subs) do
        sub_start = subs_start[idx]
        sub_end = subs_end[idx]
        
        if sub_end > clip_start and sub_start < clip_end then
            f:write(i, "\n")
            f:write(seconds_to_srt_time(sub_start - clip_start) .. " --> " .. seconds_to_srt_time(sub_end - clip_start), "\n")
            f:write(sub_content, "\n\n")

            i = i + 1
        end

        if sub_start > clip_end then
            break
        end
    end

    f:close()
end

function cut_audio_fragment()
    working_dir = mp.get_property("working-directory")
    video_path = mp.get_property("path")
    video_filename = mp.get_property("filename/no-ext")

    if start_timestamp ~= nil and end_timestamp ~= nil and start_timestamp < end_timestamp then
        mp.osd_message("Encoding Audio from " .. seconds_to_time_string(start_timestamp) .. " to " .. seconds_to_time_string(end_timestamp), 2)

        local i = 0
        local ff_aid = 0
        local tracks_count = mp.get_property_number("track-list/count")
        while i < tracks_count do
            local track_type = mp.get_property(string.format("track-list/%d/type", i))
            local track_index = mp.get_property_number(string.format("track-list/%d/ff-index", i))
            local track_selected = mp.get_property(string.format("track-list/%d/selected", i))
            local track_lang = mp.get_property(string.format("track-list/%d/lang", i))
            local track_external = mp.get_property(string.format("track-list/%d/external", i))

            if track_type == "audio" and track_selected == "yes" then
                ff_aid = track_index - 1
                break
            end

            i = i + 1
        end

        d = 0.2
        t = end_timestamp - start_timestamp

        filename = table.concat{
            working_dir,
            "/",
            video_filename,
            ".",
            seconds_to_time_string(start_timestamp, true),
            "-",
            seconds_to_time_string(end_timestamp, true),
            ".mp3"
        }

        args = {
            ffmpeg_path,
            "-y",
            "-ss", start_timestamp,
            "-i", video_path,
            "-t", t,
            "-map", "0:a:" .. ff_aid,
            "-af", "afade=t=in:st=0:d=" .. d .. ",afade=t=out:st=" .. (t - d) .. ":d=" .. d,
            filename
        }

        utils.subprocess_detached({ args = args, cancellable = false })
    end
end

function cut_video_fragment()
    working_dir = mp.get_property("working-directory")
    video_path = mp.get_property("path")
    video_file = mp.get_property("filename")
    video_filename = mp.get_property("filename/no-ext")

    if start_timestamp ~= nil and end_timestamp ~= nil and start_timestamp < end_timestamp then
        mp.osd_message("Encoding Video from " .. seconds_to_time_string(start_timestamp) .. " to " .. seconds_to_time_string(end_timestamp), 2)

        local i = 0
        local ff_aid = 0
        local tracks_count = mp.get_property_number("track-list/count")
        while i < tracks_count do
            local track_type = mp.get_property(string.format("track-list/%d/type", i))
            local track_index = mp.get_property_number(string.format("track-list/%d/ff-index", i))
            local track_selected = mp.get_property(string.format("track-list/%d/selected", i))
            local track_lang = mp.get_property(string.format("track-list/%d/lang", i))
            local track_external = mp.get_property(string.format("track-list/%d/external", i))

            if track_type == "audio" and track_selected == "yes" then
                ff_aid = track_index - 1
                break
            end

            i = i + 1
        end

        d = 0.2
        t = end_timestamp - start_timestamp
        
        video_absolute_path = working_dir .. "/" .. video_file

        filename = table.concat{
            working_dir,
            "/",
            video_filename,
            ".",
            seconds_to_time_string(start_timestamp, true),
            "-",
            seconds_to_time_string(end_timestamp, true)
        }

        args = {
            ffmpeg_path,
            "-y",
            "-ss", start_timestamp,
            "-i", video_absolute_path,
            "-t", t,
            "-map", "0:v:0",
            "-map", "0:a:" .. ff_aid,
            "-af", "afade=t=in:st=0:d=" .. d .. ",afade=t=out:st=" .. (t - d) .. ":d=" .. d,
            "-c:v", "libx264",
            "-preset", video_encoding_preset,
            "-c:a", "aac",
            "-ac", "2",
            filename .. ".mp4"
        }

        utils.subprocess_detached({ args = args, cancellable = false })

        write_subtitles_fragment(filename .. ".srt", start_timestamp, end_timestamp)
    end
end

function cut_video_fragment_with_subtitles()
    working_dir = mp.get_property("working-directory")
    video_path = mp.get_property("path")
    video_file = mp.get_property("filename")
    video_filename = mp.get_property("filename/no-ext")

    if start_timestamp ~= nil and end_timestamp ~= nil and start_timestamp < end_timestamp then
        mp.osd_message("Encoding Video with Subtitles from " .. seconds_to_time_string(start_timestamp) .. " to " .. seconds_to_time_string(end_timestamp), 2)

        local i = 0
        local ff_aid = 0
        local tracks_count = mp.get_property_number("track-list/count")
        while i < tracks_count do
            local track_type = mp.get_property(string.format("track-list/%d/type", i))
            local track_index = mp.get_property_number(string.format("track-list/%d/ff-index", i))
            local track_selected = mp.get_property(string.format("track-list/%d/selected", i))
            local track_lang = mp.get_property(string.format("track-list/%d/lang", i))
            local track_external = mp.get_property(string.format("track-list/%d/external", i))

            if track_type == "audio" and track_selected == "yes" then
                ff_aid = track_index - 1
                break
            end

            i = i + 1
        end

        d = 0.2
        t = end_timestamp - start_timestamp
        
        subtitle_filename = working_dir .. "/" .. video_filename

        for i, ext in ipairs(srt_file_extensions) do
            f = io.open(subtitle_filename .. ext, "r")
            if f ~= nil then
                subtitle_filename = subtitle_filename .. ext
                io.close(f)
                break
            end
        end
        
        if f == nil then
            mp.osd_message("Encoding Failed", 2)
            return
        end
        
        if subtitle_filename:sub(2,2) == ":" then
            subtitle_filename = string.gsub(subtitle_filename, "\\", "\\\\\\\\")
            subtitle_filename = string.gsub(subtitle_filename, ":", "\\\\:")
            subtitle_filename = string.gsub(subtitle_filename, ",", "\\\\\\,")
            subtitle_filename = string.gsub(subtitle_filename, "'", "\\\\\\'")
        end

        video_absolute_path = working_dir .. "/" .. video_file

        filename = table.concat{
            working_dir,
            "/",
            video_filename,
            ".",
            seconds_to_time_string(start_timestamp, true),
            "-",
            seconds_to_time_string(end_timestamp, true),
            ".sub.mp4"
        }

        vf = "subtitles=" .. subtitle_filename .. ":force_style=\'FontName=Arial,FontSize=22\',setpts=PTS-STARTPTS"
        af = "afade=t=in:st=" .. start_timestamp .. ":d=" .. d .. ",afade=t=out:st=" .. (end_timestamp - d) .. ":d=" .. d .. ",asetpts=PTS-STARTPTS"

        args = {
            ffmpeg_path,
            "-y",
            "-ss", start_timestamp,
            "-i", video_absolute_path,
            "-t", t,
            "-map", "0:v:0",
            "-map", "0:a:" .. ff_aid,
            "-c:v", "libx264",
            "-preset", video_encoding_preset,
            "-c:a", "aac",
            "-ac", "2",
            "-vf", vf,
            "-af", af,
            "-copyts",
            filename
        }

        utils.subprocess_detached({ args = args, cancellable = false })
    end
end

mp.add_key_binding("ctrl+w", "set-start-timestamp", set_start_timestamp)
mp.add_key_binding("ctrl+e", "set-end-timestamp", set_end_timestamp)
mp.add_key_binding("ctrl+z", "cut-audio-fragment", cut_audio_fragment)
mp.add_key_binding("ctrl+x", "cut-video-fragment", cut_video_fragment)
mp.add_key_binding("ctrl+c", "cut-video-fragment-with-subtitles", cut_video_fragment_with_subtitles)
