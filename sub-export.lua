--  Usage:
--     Select subtitles and press Shift + X. 
-- 
--  Note:
--     Requires FFmpeg in PATH environment variable or edit ffmpeg_path in the script options,
--     for example, by replacing [[ffmpeg]] with [[C:\Programs\ffmpeg\bin\ffmpeg.exe]]
--  Note: 
--     A small circle at the top-right corner is a sign that export is happenning now.
--  Note:
--     The exported subtitles will be automatically selected with visibility set to true. 
--  Note: 
--     It could take ~1-5 minutes to export subtitles.

utils = require 'mp.utils'

---- Script Options ----
ffmpeg_path = [[ffmpeg]]
------------------------

function export_selected_subtitles()
    local i = 0
    local tracks_count = mp.get_property_number("track-list/count")
    while i < tracks_count do
        local track_type = mp.get_property(string.format("track-list/%d/type", i))
        local track_index = mp.get_property_number(string.format("track-list/%d/ff-index", i))
        local track_selected = mp.get_property(string.format("track-list/%d/selected", i))
        local track_lang = mp.get_property(string.format("track-list/%d/lang", i))
        local track_external = mp.get_property(string.format("track-list/%d/external", i))
        local track_codec = mp.get_property(string.format("track-list/%d/codec", i))

        if track_type == "sub" and track_selected == "yes" then
            if track_external == "yes" then
                mp.osd_message("Error: external subtitles have been selected", 2)
                return
            end

            local video_file = mp.get_property("working-directory") .. "/" .. mp.get_property("filename")

            local subtitles_ext = ".srt"
            if track_codec == "ass" then
                subtitles_ext = ".ass"
            end

            if track_lang ~= nil then
                subtitles_ext = "." .. track_lang .. subtitles_ext
            end
            
            subtitles_file = mp.get_property("working-directory") .. "/" .. mp.get_property("filename/no-ext") .. subtitles_ext

            mp.osd_message("Exporting selected subtitles")

            args = {ffmpeg_path, '-y', '-hide_banner', '-loglevel', 'error', '-i', video_file, "-map", string.format("0:%d", track_index), subtitles_file}

            mp.add_timeout(mp.get_property_number("osd-duration") * 0.001, process)

            break
        end

        i = i + 1
    end
end

function process()
    local screenx, screeny, aspect = mp.get_osd_size()

    mp.set_osd_ass(screenx, screeny, "{\\an9}● ")
    local res = utils.subprocess({ args = args })
    mp.set_osd_ass(screenx, screeny, "")

    if res.status == 0 then
        mp.osd_message("Finished exporting subtitles")
        mp.commandv("sub-add", subtitles_file)
        mp.set_property("sub-visibility", "yes")
    else
        mp.osd_message("Failed to export subtitles")
    end
end

mp.add_key_binding("X", "export-selected-subtitles", export_selected_subtitles)
