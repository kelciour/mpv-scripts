--------- Installation ---------
-- 1. Install Anki (https://apps.ankiweb.net) & mpv (https://mpv.io) video player (or IINA for macOS).
-- 2. Install FFmpeg.
--      FFmpeg for Windows can be downloaded from http://ffmpeg.zeranoe.com
--      FFmpeg for macOS can be installed using brew (https://brew.sh): brew install ffmpeg --with-libvpx --with-opus
-- 3. Install Python 2.7 (it's probably already installed in macOS & Linux) and 'requests' module using pip: pip install requests
-- 3. Install Anki Connect add-on - https://ankiweb.net/shared/info/2055492159
-- 4. Import subs2srs-sample.apkg in Anki.
-- 5. Copy this file (subs2srs.lua) and subs2srs.py in the 'scripts' subdirectory of the mpv configuration directory.
--      Default path:
--      - Linux & macOS: ~/.config/mpv/scripts
--      - Windows: {mpv installation folder}/scripts (create it if it doesn't exist)
-- 6. And update at least the following settings:
--      LUA_SCRIPTS_DIRECTORY
--      COLLECTION_MEDIA_DIR
--    For Windows also update these settings if python.exe and ffmpeg.exe aren't in PATH environment variable:
--      FFMPEG_PATH
--      PYTHON_PATH
--------------------------------

------------ Usage -------------
-- 1. Open Anki.
-- 2. Open any video file with .srt subtitles alongside it in mpv video player.
-- 3. Navigate to the scene with subtitles.
-- 4. Press 'b' to add new card in Anki.
--------------------------------

-------- Sample Deck -----------
-- It contains two note types (subs2srs and subs2srs-video) and 3 types of cards (audio, cloze, video).
-- Audio & Video card template is from substudy (http://www.randomhacks.net/substudy), except there's no subtitles in the native language.

-- Note: subs2srs-video note type requires Anki Beta, NOTE_TYPE updated, EXPORT_VIDEO to be set to true.
-- By default video tag in subs2srs-video card template doesn't contain controls attribute and the video can be replayed only by 
-- clicking inside the card (setting focus) and presssing Shift + R or Ctrl + R.
-- That's why it's better to install "Refocus Card when Reviewing" Anki add-on, but Anki Beta won't install it from AnkiWeb.
-- So download it using a stable version of Anki or using this link - https://gist.github.com/kelciour/a3329225d2f7fce48bf24af92af5f4fe
-- and install it using this manual - https://apps.ankiweb.net/docs/addons21.html#single-.py-add-ons-need-their-own-folder
--------------------------------

------- Default Hotkeys --------
-- b - add new card (using current subtitle timing or start & end time if they are set)
-- w - set start time (and automatically set end time if it's not set)
-- e - set end time (and automatically set start time if it's not set)
-- Ctrl + w - preview the card (and set start & end time if it's necessary)
-- Ctrl + e - replay the last n seconds of the card (and set start & end time if it's necessary)
-- Ctrl + b - reset start & end time to the current subtitle timing

-- To change default script hotkeys update the bottom of this script.

-- Some of mpv default keybindings:
--   Left and Right - seek backward/forward 5 seconds.
--   Shift + Left and Shift + Right - seek backward/forward 1 second.
--   , and . - step backward/forward 1 frame (probably works only if current keyboard layout is English).
-- For more info: https://mpv.io/manual/master/#keyboard-control
--------------------------------

------- Script Settings --------
-- Subtitles in the target language.
SRT_FILE_EXTENSIONS = {".srt", ".en.srt", ".eng.srt"}

-- Path to the mpv 'scripts' folder. Default: ~/.config/mpv/scripts
LUA_SCRIPTS_DIRECTORY = [[C:\Programs\mpv\scripts]]

-- Path to the subs2srs.py.
PYTHON_HELPER_PATH = LUA_SCRIPTS_DIRECTORY .. "/" .. "subs2srs.py"

-- Pad the start and end times when generating an audio clip.
-- For example, setting the padding to 0.25 means that the audio clip 
-- will start 250 milliseconds sooner and will end 250 milliseconds later than it would normally.
AUDIO_CLIP_PADDING = 1.25

-- Fade the start and the end of the audio when generating an audio clip.
AUDIO_CLIP_FADE = 0.2

-- It's better to set it false in case of non-latin subtitles.
JOIN_SUBTITLES_INTO_SENTENCES = true

-- Replay the last n seconds of the anki card.
REPLAY_TIME = 1.5
--------------------------------

-------- Anki Settings ---------
-- Path to the collection.media folder. How to find it - https://apps.ankiweb.net/docs/manual.html#files
COLLECTION_MEDIA_DIR = [[C:\Users\Nickolay\AppData\Roaming\Anki2\subs2srs\collection.media]]

-- Name of the note type that contains fields Sound, Time, Source, Image, Target: line, Target: line before, Target: line after.
NOTE_TYPE = [[subs2srs]]

-- Name of the deck where cards will be added. If the deck doesn't exist it will be created.
DEFAULT_DECK = [[subs2srs]]

-- If this option is true then cards will be added in the subdeck with the same name as the name of the video.
CREATE_SUBDECKS_FOR_CARDS = true
--------------------------------

-------- Image Settings --------
-- Width and Height of the generated snapshots (in pixels).
-- To keep the aspect ratio specify only one component, either width or height, and set the other component to -1.
-- If both width and height set to -1 the generated snapshots won't be resized.
IMAGE_WIDTH = 400
IMAGE_HEIGHT = -1
--------------------------------

-------- Video Settings --------
VIDEO_WIDTH = 480
VIDEO_HEIGHT = -2

VIDEO_FORMAT_HTML5 = true

EXPORT_VIDEO = false
--------------------------------

-------- Other Settings --------
-- For Windows either update PATH environment variable or replace with
-- the absolute path to the ffmpeg.exe and python.exe, for example, [[C:\Programs\ffmpeg\bin\ffmpeg.exe]]
FFMPEG_PATH = [[ffmpeg]]
PYTHON_PATH = [[python]]
--------------------------------

utils = require 'mp.utils'

function srt_time_to_seconds(time)
    major, minor = time:match("(%d%d:%d%d:%d%d),(%d%d%d)")
    hours, mins, secs = major:match("(%d%d):(%d%d):(%d%d)")
    return hours * 3600 + mins * 60 + secs + minor / 1000
end

function seconds_to_time(time, delimiter)
    hours = math.floor(time / 3600)
    mins = math.floor(time / 60) % 60
    secs = math.floor(time % 60)
    milliseconds = (time * 1000) % 1000

    return string.format("%02d:%02d:%02d%s%03d", hours, mins, secs, delimiter, milliseconds)
end

function seconds_to_ffmpeg_time(time)
    return seconds_to_time(time, '.')
end

function set_start_timestamp()
    start_timestamp = mp.get_property_number("time-pos") + AUDIO_CLIP_PADDING

    if end_timestamp == nil then
        local sub_start, sub_end = get_current_sub_timing()
        end_timestamp = sub_end + AUDIO_CLIP_PADDING
    end

    mp.osd_message("Start: " .. seconds_to_ffmpeg_time(start_timestamp))
end

function set_end_timestamp()
    end_timestamp = mp.get_property_number("time-pos") - AUDIO_CLIP_PADDING
    
    if start_timestamp == nil then
        local sub_start, sub_end = get_current_sub_timing()
        start_timestamp = sub_start - AUDIO_CLIP_PADDING
    end

    mp.osd_message("End: " .. seconds_to_ffmpeg_time(end_timestamp))
end

function get_current_sub_timing()
    local time_pos = mp.get_property_number("time-pos")

    local sub_start, sub_end
    for i, sub_text in ipairs(sentences) do
        sub_start = sentences_start[i]
        sub_end = sentences_end[i]

        if sub_start <= time_pos and time_pos <= sub_end then
            break
        end

        if sentences_start[i] > time_pos then
            break
        end
    end

    return sub_start, sub_end
end

function set_start_end_timestamps()
    local time_pos = mp.get_property_number("time-pos")

    for i, sub_text in ipairs(sentences) do
        start_timestamp = sentences_start[i]
        end_timestamp = sentences_end[i]

        if i < #sentences and sentences_start[i+1] > time_pos then
            break
        end
    end

    mp.osd_message(string.format("%s - %s", seconds_to_ffmpeg_time(start_timestamp), seconds_to_ffmpeg_time(end_timestamp)))
end

function pause_player()
    mp.set_property("pause", "yes")
end

function replay_anki_card()
    if start_timestamp == nil and end_timestamp == nil then
        local subtitles_fragment, subtitles_fragment_start_time, subtitles_fragment_end_time, subtitles_fragment_prev, subtitles_fragment_next = get_subtitles_fragment(sentences, sentences_start, sentences_end)
    
        if subtitles_fragment == "" then
            mp.osd_message("no text")
            return
        else
            start_timestamp = subtitles_fragment_start_time
            end_timestamp = subtitles_fragment_end_time
        end
    end

    mp.commandv("seek", start_timestamp - AUDIO_CLIP_PADDING, "absolute+exact")
    mp.set_property("pause", "no")
    player_state = "replay from the start"
end

function replay_the_last_seconds_of_anki_card()
    if start_timestamp == nil and end_timestamp == nil then
        local subtitles_fragment, subtitles_fragment_start_time, subtitles_fragment_end_time, subtitles_fragment_prev, subtitles_fragment_next = get_subtitles_fragment(sentences, sentences_start, sentences_end)
    
        if subtitles_fragment == "" then
            mp.osd_message("no text")
            return
        else
            start_timestamp = subtitles_fragment_start_time
            end_timestamp = subtitles_fragment_end_time
        end
    end

    mp.commandv("seek", end_timestamp - REPLAY_TIME, "absolute+exact")
    mp.set_property("pause", "no")
    player_state = "replay from the end"
end

function on_playback_restart()
    if timer ~= nil then
        timer:kill()
    end

    if player_state == "replay from the end" then
        timer = mp.add_timeout(REPLAY_TIME + AUDIO_CLIP_PADDING, pause_player)
        player_state = nil
    elseif player_state == "replay from the start" then
        timer = mp.add_timeout(end_timestamp - start_timestamp + 2 * AUDIO_CLIP_PADDING, pause_player)
        player_state = nil
    end
end

function open_subtitles_file(srt_file_exts)
    local srt_filename = mp.get_property("working-directory") .. "/" .. mp.get_property("filename/no-ext")
    
    for i, ext in ipairs(srt_file_exts) do
        local f, err = io.open(srt_filename .. ext, "r")
        
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

            if JOIN_SUBTITLES_INTO_SENTENCES and (sub_start - prev_sub_end) <= 2 and sub_text:sub(1,1) ~= '-' and 
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

function export_video_fragment(start_timestamp, end_timestamp)
    if EXPORT_VIDEO == false then
        return ""
    end

    local video_input = mp.get_property("working-directory") .. "/" .. mp.get_property("filename")
    local video_filename = mp.get_property("filename/no-ext")

    local ff_aid = 0
    local tracks_count = mp.get_property_number("track-list/count")
    for i = 1, tracks_count do
        local track_type = mp.get_property(string.format("track-list/%d/type", i))
        local track_index = mp.get_property_number(string.format("track-list/%d/ff-index", i))
        local track_selected = mp.get_property(string.format("track-list/%d/selected", i))

        if track_type == "audio" and track_selected == "yes" then
            ff_aid = track_index - 1
            break
        end
    end

    start_timestamp = start_timestamp - AUDIO_CLIP_PADDING
    end_timestamp = end_timestamp + AUDIO_CLIP_PADDING

    d = AUDIO_CLIP_FADE
    t = end_timestamp - start_timestamp

    local clip_filename = table.concat{
        video_filename,
        "_",
        string.format("%.3f", start_timestamp),
        "-",
        string.format("%.3f", end_timestamp)
    }

    local clip_output, args
    if VIDEO_FORMAT_HTML5 ~= true then
        clip_filename = clip_filename .. ".mp4"
        clip_output = COLLECTION_MEDIA_DIR .. "/" .. clip_filename
        args = {
            FFMPEG_PATH,
            "-y",
            "-ss", start_timestamp,
            "-i", video_input,
            "-t", string.format("%.3f", t),
            "-map", "0:v:0",
            "-map", string.format("0:a:%d", ff_aid),
            "-af", string.format("afade=t=in:curve=ipar:st=%.3f:d=%.3f,afade=t=out:curve=ipar:st=%.3f:d=%.3f", 0, d, t - d, d),
            "-c:v", "libx264",
            "-preset", "medium",
            "-c:a", "aac",
            "-ac", "2",
            clip_output
        }
    else
        clip_filename = clip_filename .. ".webm"
        clip_output = COLLECTION_MEDIA_DIR .. "/" .. clip_filename
        args = {
            FFMPEG_PATH,
            "-y",
            "-ss", start_timestamp,
            "-i", video_input,
            "-t", string.format("%.3f", t),
            "-map", "0:v:0",
            "-map", string.format("0:a:%d", ff_aid),
            "-af", string.format("afade=t=in:curve=ipar:st=%.3f:d=%.3f,afade=t=out:curve=ipar:st=%.3f:d=%.3f", 0, d, t - d, d),
            "-c:v", "libvpx-vp9",
            "-b:v", "1400K",
            "-threads", "8",
            "-speed", "2",
            "-crf", "23",
            "-c:a", "libopus",
            "-b:a", "64k",
            "-ac", "2",
            clip_output
        }
    end

    if VIDEO_WIDTH == -1 then VIDEO_WIDTH = -2 end
    if VIDEO_HEIGHT == -1 then VIDEO_HEIGHT = -2 end

    if VIDEO_WIDTH ~= -2 or VIDEO_HEIGHT ~= -2 then
        table.insert(args, #args, "-vf")
        table.insert(args, #args, string.format('scale=%d:%d', VIDEO_WIDTH, VIDEO_HEIGHT))
    end

    utils.subprocess_detached({ args = args })

    return clip_filename
end


function export_audio_fragment(start_timestamp, end_timestamp)
    local video_input = mp.get_property("working-directory") .. "/" .. mp.get_property("filename")
    local video_filename = mp.get_property("filename/no-ext")

    local ff_aid = 0
    local tracks_count = mp.get_property_number("track-list/count")
    for i = 1, tracks_count do
        local track_type = mp.get_property(string.format("track-list/%d/type", i))
        local track_index = mp.get_property_number(string.format("track-list/%d/ff-index", i))
        local track_selected = mp.get_property(string.format("track-list/%d/selected", i))

        if track_type == "audio" and track_selected == "yes" then
            ff_aid = track_index - 1
            break
        end
    end

    start_timestamp = start_timestamp - AUDIO_CLIP_PADDING
    end_timestamp = end_timestamp + AUDIO_CLIP_PADDING

    d = AUDIO_CLIP_FADE
    t = end_timestamp - start_timestamp

    local audio_filename = table.concat{
        video_filename,
        "_",
        string.format("%.3f", start_timestamp),
        "-",
        string.format("%.3f", end_timestamp),
        ".mp3"
    }

    local audio_output = COLLECTION_MEDIA_DIR .. "/" .. audio_filename

    local args = {
        FFMPEG_PATH,
        "-y",
        "-ss", start_timestamp,
        "-i", video_input,
        "-t", string.format("%.3f", t),
        "-map", string.format("0:a:%d", ff_aid),
        "-af", string.format("afade=t=in:curve=ipar:st=%.3f:d=%.3f,afade=t=out:curve=ipar:st=%.3f:d=%.3f", 0, d, t - d, d),
        audio_output
    }

    utils.subprocess_detached({ args = args })

    return audio_filename
end

function export_screenshot()
    local time_pos = mp.get_property_number("time-pos")
    
    local video_input = mp.get_property("working-directory") .. "/" .. mp.get_property("filename")
    
    local image_filename = string.format("%s_%.3f.jpg", mp.get_property("filename/no-ext"), time_pos)
    local image_output = COLLECTION_MEDIA_DIR .. "/" .. image_filename

    local args = {FFMPEG_PATH, '-y', '-ss', seconds_to_ffmpeg_time(time_pos), '-i', video_input, "-vframes", "1", "-q:v", "2", image_output}
    
    if IMAGE_WIDTH ~= -1 or IMAGE_HEIGHT ~= -1 then
        table.insert(args, #args, "-vf")
        table.insert(args, #args, string.format('scale=%d:%d', IMAGE_WIDTH, IMAGE_HEIGHT))
    end

    utils.subprocess_detached({args = args})

    return image_filename
end

function get_subtitles_fragment(subtitles, subtitles_start, subtitles_end)
    local time_pos = mp.get_property_number("time-pos")

    local subtitles_fragment = {}
    local subtitles_fragment_start_time = nil
    local subtitles_fragment_end_time = nil
    local subtitles_fragment_prev = " "
    local subtitles_fragment_next = " "

    if start_timestamp ~= nil then
        start_timestamp = start_timestamp - AUDIO_CLIP_PADDING
        end_timestamp = end_timestamp + AUDIO_CLIP_PADDING
    end

    for i, sub_text in ipairs(subtitles) do
        local sub_start = subtitles_start[i]
        local sub_end = subtitles_end[i]

        if (start_timestamp ~= nil and (start_timestamp <= sub_start and sub_end <= end_timestamp)) or
            (start_timestamp == nil and (sub_start <= time_pos and time_pos <= sub_end))
        then
            table.insert(subtitles_fragment, sub_text)

            if subtitles_fragment_start_time == nil then
                subtitles_fragment_start_time = sub_start
                
                if i ~= 1 then
                    subtitles_fragment_prev = subtitles[i-1]
                end
            end

            subtitles_fragment_end_time = sub_end

            if i ~= #subtitles then
                subtitles_fragment_next = subtitles[i+1]
            end
        end

        if end_timestamp ~= nil then
            if sub_start > end_timestamp then
                break
            end
        elseif sub_start > time_pos then
            break
        end
    end

    if start_timestamp ~= nil then
        start_timestamp = start_timestamp + AUDIO_CLIP_PADDING
        end_timestamp = end_timestamp - AUDIO_CLIP_PADDING
    end

    if start_timestamp ~= nil then
        subtitles_fragment_start_time = start_timestamp
        subtitles_fragment_end_time = end_timestamp
    end

    return table.concat(subtitles_fragment, "<br />"), subtitles_fragment_start_time, subtitles_fragment_end_time, subtitles_fragment_prev, subtitles_fragment_next
end

function create_anki_card()
    local subtitles_fragment, subtitles_fragment_start_time, subtitles_fragment_end_time, subtitles_fragment_prev, subtitles_fragment_next = get_subtitles_fragment(sentences, sentences_start, sentences_end)
    
    if subtitles_fragment == "" then
        mp.osd_message("no text")
        return
    end

    local video_filename = mp.get_property("filename/no-ext")
    local audio_filename = export_audio_fragment(subtitles_fragment_start_time, subtitles_fragment_end_time)
    local clip_filename = export_video_fragment(subtitles_fragment_start_time, subtitles_fragment_end_time)
    local image_filename = export_screenshot()


    local deck = DEFAULT_DECK
    if CREATE_SUBDECKS_FOR_CARDS then
        deck = deck .. "::" .. video_filename
    end

    local sound = "[sound:" .. audio_filename .. "]"
    local video = clip_filename
    local time = seconds_to_ffmpeg_time(subtitles_fragment_start_time)
    local source = video_filename
    local image = "<img src=\"" .. image_filename .. "\" />"
    local target_line = subtitles_fragment
    local target_line_before = subtitles_fragment_prev
    local target_line_after = subtitles_fragment_next

    local fields = {}
    fields["Sound"] = sound
    fields["Time"] = time
    fields["Source"] = source
    fields["Image"] = image
    fields["Target: line"] = target_line
    fields["Target: line before"] = target_line_before
    fields["Target: line after"] = target_line_after
    if EXPORT_VIDEO then
        fields["Video"] = video
    end

    local args = {PYTHON_PATH, PYTHON_HELPER_PATH, deck, NOTE_TYPE, utils.format_json(fields)}

    ret = utils.subprocess({args = args})

    if ret["status"] == 0 then
        mp.osd_message("✔")
    else
        mp.osd_message("error")
    end

    player_state = nil
    start_timestamp = nil
    end_timestamp = nil
end

function init()
    ret = read_subtitles(SRT_FILE_EXTENSIONS)

    if ret == false or #subs == 0 then
        return
    end
    
    convert_into_sentences()

    mp.add_key_binding("b", "create-anki-card", create_anki_card)
    mp.add_key_binding("w", "set-start-timestamp", set_start_timestamp)
    mp.add_key_binding("e", "set-end-timestamp", set_end_timestamp)
    mp.add_key_binding("ctrl+w", "replay_anki_card", replay_anki_card)
    mp.add_key_binding("ctrl+e", "replay-the-last-seconds-of-anki-card", replay_the_last_seconds_of_anki_card)
    mp.add_key_binding("ctrl+b", "set-start-end-timestamps", set_start_end_timestamps)

    mp.register_event("playback-restart", on_playback_restart)
end

mp.register_event("file-loaded", init)
