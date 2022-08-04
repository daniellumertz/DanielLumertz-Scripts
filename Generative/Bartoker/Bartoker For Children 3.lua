-- @version 0.1.2
-- @author Daniel Lumertz
-- @provides
--    [nomain] Functions/*.lua
-- @changelog
--    + Change the dofile (prev version was wind only)

--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")

-- get script path
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
-- dofile all files inside functions folder
dofile(script_path .. 'Functions/Arrange Functions.lua') -- Functions for using the markov in reaper
dofile(script_path .. 'Functions/Bartoker Functions.lua') -- Functions for using the markov in reaper
dofile(script_path .. 'Functions/Chunk Functions.lua') -- Functions for using the markov in reaper
dofile(script_path .. 'Functions/General Lua Functions.lua') -- Functions for using the markov in reaper
dofile(script_path .. 'Functions/MIDI Functions.lua') -- Functions for using the markov in reaper
dofile(script_path .. 'Functions/Saved Chunks.lua') -- Functions for using the markov in reaper

-- run mobdebug

--GetFromTableRandom({})
-- user settings:
local ppq = 960
local chord_with_scale = false
-- the scale in the first selected midi item
-- chords used: pattern is [i, IV] [i IV i] [V/III III V/III i] [i IV i] 
local i_chord = {root = 1, fix_intervals = {7}, diatonic_interval = {5}} -- diatonic interval is 1 based
local iv_chord = {root = 4, fix_intervals = {4}, diatonic_interval = {3}}
local vii_chord = {root = 7, fix_intervals = {10}, diatonic_interval = {7}} -- V/III.
local iii_chord = {root = 3, fix_intervals = {4}, diatonic_interval = {3}}
local all_chords_table = {i_chord, iv_chord, vii_chord, iii_chord}
-- chord sequences:
local chord_1 = {i_chord,iv_chord} -- i IV. root = note of the scale to build from. fix_intervals = intervals to form the chord. in semitones. will be ignored if chord_with_scale. diatonic_interval = steps form the root. will be ignored if not chord_with_scale.
local chord_2 = {i_chord,iv_chord,i_chord}
local chord_3 = {vii_chord,iii_chord,vii_chord,i_chord}
local chord_4 = {i_chord,iv_chord,i_chord}
local all_chords_sequence_table = {chord_1,chord_2,chord_3,chord_4}

-- melody 1 settings
local rhythms = {{1/8,1/8},{1/4}}
local melody_steps_pillars = {1,5,5,1}
local melody_1_possible_intervals = {0,1,2,3,4} -- in steps 0 means unison. 1 means 1 step. 2 means 2 steps. 3 means 3 steps. 4 means 4 steps. 5 means 5 steps.
local melody_1_tolerance = 2 -- in steps.
local limit_5 = 5
local random = 0.5  
local mel1_start = 1
local mel1_end = 1
local min1_vel = 40
local max1_vel = 90
local accents1 = 10
local accents1chance = 10
-- melody 2 settings
local mel2_rhythms = {{1/8,1/8},{1/4}}
local melody_2_steps_pillars = {4,3,1,2,3,2,1,1} -- two per bar
local melody_2_possible_intervals = {1} -- in steps 0 means unison. 1 means 1 step. 2 means 2 steps. 3 means 3 steps. 4 means 4 steps. 5 means 5 steps.
local melody_2_tolerance = 1 -- in steps.
local mel2_limit_5 = 5
local mel2_random = 0.9  
local mel2_start = 4
local mel2_end = 1
local min2_vel = 40
local max2_vel = 80
local accents2 = 10
local accents2chance = 10

------------------------------
-- Undo
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

--Get basic info

-- Get start position. Dont change that please! If want to change the position the music is generated change the chord items poisition. Will only use that to generate the chord items if it dont exist already.
local start_measure =  1 -- 0 based
local start_pos =  reaper.TimeMap2_beatsToTime( 0, 0, start_measure )

-- Get Scale Track
local scale_track_name = '!Scale Track'
local track = GetTrackByName(0,scale_track_name)
if not track then -- create a track and insert chunk in it
    local track_cnt = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(track_cnt, true)
    track = reaper.GetTrack(0,track_cnt)
    reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', scale_track_name, true) -- rename track
    -- Insert Items
    PasteItemChunksAtTimeAtTrack(ScaleItemChunk,'<ITEM',track,0)
end

-- Get Chord Track.
local chord_track_name = '!Chord Track'
local chord_track = GetTrackByName(0,chord_track_name)
if not chord_track then
    local track_cnt = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(track_cnt, true)
    chord_track = reaper.GetTrack(0,track_cnt)
    reaper.GetSetMediaTrackInfo_String(chord_track, 'P_NAME', chord_track_name, true) -- rename track
    -- Insert Items
    PasteItemChunksAtTimeAtTrack(ChordItemsChunk,'<ITEM',chord_track,start_pos)
end
-- get start position
local first_chord_item = reaper.GetTrackMediaItem(chord_track, 0)
local gen_item_pos = reaper.GetMediaItemInfo_Value(first_chord_item, 'D_POSITION')
-- get end position
local cnt_items = reaper.CountTrackMediaItems(chord_track)
local last_chord_item = reaper.GetTrackMediaItem(chord_track, cnt_items-1)
local last_chord_item_pos = reaper.GetMediaItemInfo_Value(last_chord_item, 'D_POSITION')
local last_chord_item_len = reaper.GetMediaItemInfo_Value(last_chord_item, 'D_LENGTH')
local last_chord_item_end = last_chord_item_pos + last_chord_item_len




--Get Generated Track
local generated_track_name = '!Generation Track'
local generated_track = GetTrackByName(0,generated_track_name)
if not generated_track then
    local track_cnt = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(track_cnt, true)
    generated_track = reaper.GetTrack(0,track_cnt)
    reaper.GetSetMediaTrackInfo_String(generated_track, 'P_NAME', generated_track_name, true) -- rename track
end

-------------
local item_scale = reaper.GetTrackMediaItem( track, 0 ) -- get scale item
-- get take
local take = reaper.GetActiveTake(item_scale)
-- get the notes
local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts( take )
--  get scale
local scale = {}
for i = 0, notecnt-1 do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    scale[#scale+1] = pitch 
end
-- Generate the chords
-- if chord_with_scale == true then change the intervals to fit the scale
if chord_with_scale == true then
    all_chords_table = ChordMakeIntervalsFromSteps(all_chords_table,scale)
end

-- create MIDI Item
local gen_item = reaper.CreateNewMIDIItemInProj(generated_track,gen_item_pos,last_chord_item_end,false)
local gen_take = reaper.GetActiveTake(gen_item)

-- input chords
GenerateChords(all_chords_sequence_table,scale,gen_take,chord_track)

-- Make Melody 1
-- Melody 1 -- length is always 2 2/4 bars for this exercise.
-- generate rhythm 
local length = 1 -- 2 2/4 bars
local mel1_rhythms = GenerateRhythm(length,rhythms)
local mel1_pitches = GeneratePitches(mel1_rhythms,scale,mel1_start,mel1_end,melody_steps_pillars,length,melody_1_possible_intervals,melody_1_tolerance,limit_5,random)

-- Create mel1 4 times.
local mel_start = {0,2,10,12}

for rep = 1,#mel_start do
    local qn = mel_start[rep] * 2  -- mel_start is in bars each bar have 2 quarter notes
    local note_start = qn * ppq
    for i, rhythm_val in pairs(mel1_rhythms) do
        local rhythm_ppq = rhythm_val * ppq * 4 -- *4 because I am using 1/4 as a quarter note and ppq is 1 quarter notes. 
        local note_end = note_start + rhythm_ppq
        local vel = SetVelocity(mel1_rhythms,min1_vel,max1_vel,i,accents1,accents1chance,rhythm_val)
        reaper.MIDI_InsertNote(gen_take, false, false, note_start, note_end, 1, mel1_pitches[i], vel, true)
        note_start = note_start+rhythm_ppq
    end
end
reaper.MIDI_Sort(gen_take)

-- Make Melody 2
-- Melody 1 -- length is always 2 2/4 bars for this exercise.
-- generate rhythm 
local length = 2 -- 4 2/4 bars
local mel2_rhythms = GenerateRhythm(length,mel2_rhythms)
mel2_rhythms[#mel2_rhythms] = mel2_rhythms[#mel2_rhythms] + 1 -- add 1 whole note to the last note. 
local mel2_pitches = GeneratePitches(mel2_rhythms,scale,mel2_start,mel2_end,melody_2_steps_pillars,length,melody_2_possible_intervals,melody_2_tolerance,mel2_limit_5,mel2_random)

-- Create mel1 4 times.
local mel_start = {4,14}

for rep = 1,#mel_start do
    local qn = mel_start[rep] * 2  -- mel_start is in bars each bar have 2 quarter notes
    local note_start = qn * ppq
    for i, rhythm_val in pairs(mel2_rhythms) do
        local rhythm_ppq = rhythm_val * ppq * 4 -- *4 because I am using 1/4 as a quarter note and ppq is 1 quarter notes. 
        local note_end = note_start + rhythm_ppq
        local vel = SetVelocity(mel2_rhythms,min2_vel,max2_vel,i,accents2,accents2chance,rhythm_val)
        reaper.MIDI_InsertNote(gen_take, false, false, note_start, note_end, 1, mel2_pitches[i], vel, true)
        note_start = note_start+rhythm_ppq
    end
end
reaper.MIDI_Sort(gen_take)

-- End undo
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock('Generate Bartok For Children nº3', -1)




--[[ This is the default settings copy this if needed to go back
-- user settings:
local ppq = 960
local chord_with_scale = false
-- the scale in the first selected midi item
-- chords used: pattern is [i, IV] [i IV i] [V/III III V/III i] [i IV i] 
local i_chord = {root = 1, fix_intervals = {7}, diatonic_interval = {5}} -- diatonic interval is 1 based
local iv_chord = {root = 4, fix_intervals = {4}, diatonic_interval = {3}}
local vii_chord = {root = 7, fix_intervals = {10}, diatonic_interval = {7}} -- V/III.
local iii_chord = {root = 3, fix_intervals = {4}, diatonic_interval = {3}}
local all_chords_table = {i_chord, iv_chord, vii_chord, iii_chord}
-- chord sequences:
local chord_1 = {i_chord,iv_chord} -- i IV. root = note of the scale to build from. fix_intervals = intervals to form the chord. in semitones. will be ignored if chord_with_scale. diatonic_interval = steps form the root. will be ignored if not chord_with_scale.
local chord_2 = {i_chord,iv_chord,i_chord}
local chord_3 = {vii_chord,iii_chord,vii_chord,i_chord}
local chord_4 = {i_chord,iv_chord,i_chord}
local all_chords_sequence_table = {chord_1,chord_2,chord_3,chord_4}

-- melody 1 settings
local rhythms = {{1/8,1/8},{1/4}}
local melody_steps_pillars = {1,5,5,1}
local melody_1_possible_intervals = {0,1,2,3,4} -- in steps 0 means unison. 1 means 1 step. 2 means 2 steps. 3 means 3 steps. 4 means 4 steps. 5 means 5 steps.
local melody_1_tolerance = 2 -- in steps.
local limit_5 = 5
local random = 0.5  
local mel1_start = 1
local mel1_end = 1
local min1_vel = 40
local max1_vel = 90
local accents1 = 10
local accents1chance = 10
-- melody 2 settings
local mel2_rhythms = {{1/8,1/8},{1/4}}
local melody_2_steps_pillars = {4,3,1,2,3,2,1,1} -- two per bar
local melody_2_possible_intervals = {1} -- in steps 0 means unison. 1 means 1 step. 2 means 2 steps. 3 means 3 steps. 4 means 4 steps. 5 means 5 steps.
local melody_2_tolerance = 1 -- in steps.
local mel2_limit_5 = 5
local mel2_random = 0.9  
local mel2_start = 4
local mel2_end = 1
local min2_vel = 40
local max2_vel = 80
local accents2 = 10
local accents2chance = 10

]]
