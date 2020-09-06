local utils = require("mp.utils")

local function create_chapter()
    local time_pos = mp.get_property_number("time-pos")
    local time_pos_osd = mp.get_property_osd("time-pos/full")
    local curr_chapter = mp.get_property_number("chapter")
    local chapter_count = mp.get_property_number("chapter-list/count")
    local all_chapters = mp.get_property_native("chapter-list")
    mp.osd_message(time_pos_osd, 1)

    if chapter_count == 0 then
        all_chapters[1] = {
            title = "chapter_1",
            time = time_pos
        }
        -- We just set it to zero here so when we add 1 later it ends up as 1
        -- otherwise it's probably "nil"
        curr_chapter = 0
        -- note that mpv will treat the beginning of the file as all_chapters[0] when using pageup/pagedown
        -- so we don't actually have to worry if the file doesn't start with a chapter
    else
        -- to insert a chapter we have to increase the index on all subsequent chapters
        -- otherwise we'll end up with duplicate chapter IDs which will confuse mpv
        -- +2 looks weird, but remember mpv indexes at 0 and lua indexes at 1
        -- adding two will turn "current chapter" from mpv notation into "next chapter" from lua's notation
        -- count down because these areas of memory overlap
        for i = chapter_count, curr_chapter + 2, -1 do
            all_chapters[i + 1] = all_chapters[i]
        end
        all_chapters[curr_chapter+2] = {
            title = "chapter_"..curr_chapter,
            time = time_pos
        }
    end
    mp.set_property_native("chapter-list", all_chapters)
    mp.set_property_number("chapter", curr_chapter+1)
end

local function format_time(seconds)
    local result = ""
    if seconds <= 0 then
        return "00:00:00.000";
    else
        hours = string.format("%02.f", math.floor(seconds/3600))
        mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)))
        secs = string.format("%02.f", math.floor(seconds - hours*60*60 - mins*60))
        msecs = string.format("%03.f", seconds*1000 - hours*60*60*1000 - mins*60*1000 - secs*1000)
        result = hours..":"..mins..":"..secs.."."..msecs
    end
    return result
end

local function write_chapter()
    local euid = mp.get_property_number("estimated-frame-count")
    local chapter_count = mp.get_property_number("chapter-list/count")
    local all_chapters = mp.get_property_native("chapter-list")
    local insert_chapters = ""
    local curr = nil

    for i = 1, chapter_count, 1 do
        curr = all_chapters[i]
        local time_pos = format_time(curr.time)

        if i == 1 and curr.time ~= 0 then
            local first_chapter="    <ChapterAtom>\n      <ChapterUID>"..math.random(1000, 9000).."</ChapterUID>\n      <ChapterFlagHidden>0</ChapterFlagHidden>\n      <ChapterFlagEnabled>1</ChapterFlagEnabled>\n      <ChapterDisplay>\n        <ChapterString>Prologue</ChapterString>\n        <ChapterLanguage>eng</ChapterLanguage>\n      </ChapterDisplay>\n      <ChapterTimeStart>00:00:00.000</ChapterTimeStart>\n    </ChapterAtom>\n"
            insert_chapters = insert_chapters..first_chapter
        end

        local next_chapter="      <ChapterAtom>\n        <ChapterDisplay>\n          <ChapterString>"..curr.title.."</ChapterString>\n          <ChapterLanguage>eng</ChapterLanguage>\n        </ChapterDisplay>\n        <ChapterUID>"..math.random(1000, 9000).."</ChapterUID>\n        <ChapterTimeStart>"..time_pos.."</ChapterTimeStart>\n        <ChapterFlagHidden>0</ChapterFlagHidden>\n        <ChapterFlagEnabled>1</ChapterFlagEnabled>\n      </ChapterAtom>\n"
        insert_chapters = insert_chapters..next_chapter
    end

    local chapters="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n<Chapters>\n  <EditionEntry>\n    <EditionFlagHidden>0</EditionFlagHidden>\n    <EditionFlagDefault>0</EditionFlagDefault>\n    <EditionUID>"..euid.."</EditionUID>\n"..insert_chapters.."  </EditionEntry>\n</Chapters>"

    local path = mp.get_property("path")
    dir, name_ext = utils.split_path(path)
    local name = string.sub(name_ext, 1, (string.len(name_ext)-4))
    local out_path = utils.join_path(dir, name.."_chapter.xml")
    local file = io.open(out_path, "w")
    if file == nil then
        dir = utils.getcwd()
        out_path = utils.join_path(dir, "create_chapter.xml")
        file = io.open(out_path, "w")
    end
    if file == nil then
        mp.error("Could not open chapter file for writing.")
        return
    end
    file:write(chapters)
    file:close()
    mp.osd_message("Export file to: "..out_path, 3)
end

mp.add_key_binding("C", "create_chapter", create_chapter, {repeatable=true})
mp.add_key_binding("B", "write_chapter", write_chapter, {repeatable=false})
