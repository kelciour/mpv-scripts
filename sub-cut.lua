--  Usage:
-- 
--     w - set start timestamp
--     e - set end timestamp
-- 
--     ctrl+z - cut audio fragment
--     ctrl+x - cut video fragment (with softsub subtitles)
--     ctrl+c - cut video fragment with hardsub subtitles
-- 
--     ctrl+w - replay from the start timestamp
--     ctrl+e - replay the last n seconds until the end timestamp
--     ctrl+r - reset timestamps
-- 
--  Note:
--     If the end timestamp is set and ctrl+w or ctrl+e is pressed, a small circle will appear at the top-left part of the screen and
--     video will be automatically paused at the end timestamp.
--  Note:
--     Export video with softsub or hardsub subtitles requires external *.srt subtitles.
--  Note: 
--     The default video encoding preset is "ultrafast". It can be replaced with "medium" (~2 times more slower but ~2 times less filesize).
--  Note:
--     On Windows update mpv_path (and maybe ffmpeg_path) in the script options below if it isn't in the PATH environment variable,
--     for example, by replacing [[mpv]] with [[C:\Programs\mpv\mpv.exe]].
--  Note:
--     This script relies on mpv to encode audio or video (with softsub subtitles), but FFmpeg is required to be installed
--     in order to encode video with hardsub subtitles.
--        - Windows - https://ffmpeg.zeranoe.com
--        - Linux - sudo apt-get install ffmpeg (or maybe something else)
--        - macOS - install it via brew (https://brew.sh): brew install ffmpeg
-- Status:
--     Experimental.

local utils = require "mp.utils"

------- Script Options -------
mpv_path = [[mpv]]
ffmpeg_path = [[ffmpeg]]
srt_file_extensions = {".srt", ".en.srt", ".eng.srt"}
video_encoding_preset = [[ultrafast]]
last_n_seconds_to_replay = 2.25
youtube_title = true
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
    for start_time, end_time, text in string.gmatch(data, "(%d%d:%d%d:%d%d,%d%d%d) %-%-> (%d%d:%d%d:%d%d,%d%d%d)\n(.-)\n\n") do
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

function reset_timestamps()
    start_timestamp = nil
    end_timestamp = nil

    player_state = nil

    if timer ~= nil then
        timer:kill()
    end

    if periodic_timer ~= nil then
        periodic_timer:kill()
    end

    local ass_start = mp.get_property_osd("osd-ass-cc/0")
    mp.osd_message(ass_start .. "{\\1c&HE6E6E6&}●", 0.5)
end

function replay_from_the_start_timestamp()
    if start_timestamp ~= nil then
        mp.commandv("seek", start_timestamp, "absolute+exact")
        mp.set_property("pause", "no")
        player_state = "replay the first seconds"
    end
end

function replay_the_last_n_seconds()
    if end_timestamp ~= nil then
        mp.commandv("seek", end_timestamp - last_n_seconds_to_replay, "absolute+exact")
        mp.set_property("pause", "no")
        player_state = "replay the last seconds"
    end
end

function stop_playback()
    player_state = nil
    mp.set_property("pause", "yes")

    if periodic_timer ~= nil then
        periodic_timer:kill()
    end
end

function playback_osd_message()
    mp.osd_message("●", 0.25)
end

function on_pause_change(name, value)
    if player_state == "replay" then
        if value == true then
            timer:stop()
        else
            timer:resume()
        end
    end
end

function on_seek()
    if timer ~= nil then
        timer:kill()
    end

    if periodic_timer ~= nil then
        periodic_timer:kill()
    end

    if player_state == "replay the last seconds" then
        periodic_timer = mp.add_periodic_timer(0.05, playback_osd_message)
    elseif player_state == "replay the first seconds" and end_timestamp ~= nil and end_timestamp > start_timestamp then
        periodic_timer = mp.add_periodic_timer(0.05, playback_osd_message)
    else
        player_state = nil
    end
end

function on_playback_restart()
    if player_state == "replay the first seconds" and end_timestamp == nil then
        player_state = nil
    elseif player_state == "replay the first seconds" and end_timestamp ~= nil and end_timestamp > start_timestamp then
        timer = mp.add_timeout(end_timestamp - start_timestamp, stop_playback)
        player_state = "replay"
    elseif player_state == "replay the last seconds" then
        timer = mp.add_timeout(last_n_seconds_to_replay, stop_playback)
        player_state = "replay"
    end
end

function format_filename(filename)
    local valid_characters = "-_.() abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    
    local t = {}
    for i = 1, #filename do
        local c = filename:sub(i,i)
        if string.find(valid_characters, c) then
            t[#t+1] = c
        else
            t[#t+1] = "#"
        end
    end

    local str = table.concat(t, "")
    str = str:gsub("^%s*(.-)%s*$", "%1")
    str = str:gsub("^[# -]*(.-)[# ]*$", "%1")
    str = str:gsub("#", "_")
    str = str:gsub("__+", "_")

    return str
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

        aid = mp.get_property("aid")

        d = 0.2
        t = end_timestamp - start_timestamp

        if string.find(video_path, "youtube.com") then
            video_filename = string.gsub(video_filename, "watch%?v=", "")
        end

        if video_path:sub(1, 4) == "http" and youtube_title == true then
            media_title = mp.get_property("media-title")
            if string.find(video_path, "youtube.com") or string.find(video_path, "youtu.be") then
                video_filename = format_filename(media_title .. "-" .. video_filename)
            else    
                video_filename = format_filename(media_title)
            end
        end

        filename = table.concat{
            working_dir,
            "/",
            video_filename,
            ".",
            seconds_to_time_string(start_timestamp, true),
            "-",
            seconds_to_time_string(end_timestamp, true),
            ".m4a"
        }

        args = {
            mpv_path,
            video_path,
            "--start", start_timestamp,
            "--end", end_timestamp,
            "--aid", aid,
            "--video=no",
            "--af=afade=t=in:st=" .. start_timestamp .. ":d=" .. d .. ",afade=t=out:st=" .. (end_timestamp - d) .. ":d=" .. d,
            "--o=" .. filename
        }

        if video_path:sub(1, 4) == "http" and mp.get_property("ytdl-format") ~= "" then
            table.insert(args, #args, "--ytdl-format=" .. mp.get_property("ytdl-format"))
        end

        utils.subprocess_detached({ args = args, cancellable = false })
    end
end

function cut_video_fragment()
    working_dir = mp.get_property("working-directory")
    video_path = mp.get_property("path")
    video_filename = mp.get_property("filename/no-ext")

    if start_timestamp ~= nil and end_timestamp ~= nil and start_timestamp < end_timestamp then
        mp.osd_message("Encoding Video from " .. seconds_to_time_string(start_timestamp) .. " to " .. seconds_to_time_string(end_timestamp), 2)

        aid = mp.get_property("aid")

        d = 0.2
        t = end_timestamp - start_timestamp
        
        if string.find(video_path, "youtube.com") then
            video_filename = string.gsub(video_filename, "watch%?v=", "")
        end

        if video_path:sub(1, 4) == "http" and youtube_title == true then
            media_title = mp.get_property("media-title")
            if string.find(video_path, "youtube.com") or string.find(video_path, "youtu.be") then
                video_filename = format_filename(media_title .. "-" .. video_filename)
            else    
                video_filename = format_filename(media_title)
            end
        end

        filename = table.concat{
            working_dir,
            "/",
            video_filename,
            ".",
            seconds_to_time_string(start_timestamp, true),
            "-",
            seconds_to_time_string(end_timestamp, true),
            ".mp4"
        }

        args = {
            mpv_path,
            video_path,
            "--start", start_timestamp,
            "--end", end_timestamp,
            "--aid", aid,
            "--af=afade=t=in:st=" .. start_timestamp .. ":d=" .. d .. ",afade=t=out:st=" .. (end_timestamp - d) .. ":d=" .. d,
            "--ovc=libx264",
            "--ovcopts-add=preset=" .. video_encoding_preset,
            "--o=" .. filename
        }

        if video_path:sub(1, 4) == "http" and mp.get_property("ytdl-format") ~= "" then
            table.insert(args, #args, "--ytdl-format=" .. mp.get_property("ytdl-format"))
        end

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

mp.register_event("seek", on_seek)
mp.register_event("playback-restart", on_playback_restart)
mp.observe_property("pause", "bool", on_pause_change)

------------------------------

mp.add_key_binding("w", "set-start-timestamp", set_start_timestamp)
mp.add_key_binding("e", "set-end-timestamp", set_end_timestamp)

mp.add_key_binding("ctrl+w", "replay-from-the-start-timestamp", replay_from_the_start_timestamp)
mp.add_key_binding("ctrl+e", "replay-the-last-n-seconds-until-the-end-timestamp", replay_the_last_n_seconds)
mp.add_key_binding("ctrl+r", "reset-timestamps", reset_timestamps)

mp.add_key_binding("ctrl+z", "cut-audio-fragment", cut_audio_fragment)
mp.add_key_binding("ctrl+x", "cut-video-fragment", cut_video_fragment)
mp.add_key_binding("ctrl+c", "cut-video-fragment-with-subtitles", cut_video_fragment_with_subtitles)
