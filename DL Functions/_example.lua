package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
require('General Debug')
require('General Number')
require('REAPER Checker')
require('ImGui')
require('General Table')
require('REAPER Enumerate')
require('REAPER Projects')
require('MIDI')
require('MIDI IO')

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9.1'
local demo = require 'ReaImGui_Demo'

local ctx = ImGui.CreateContext('My script')
local vals = {10,50,70}
local slider = 10
local font = ImGui.CreateFont('sans', 12)
local knob = 50
local knob2 = 50
local knob3 = 50
local knob4 = 50
local knob5 = 50
local proj = 0
local midi_table = {}
FLT_MIN = ImGui.NumericLimits_Float()
ImGui.Attach(ctx, font)

local function loop()
    ImGui.PushFont(ctx, font)
    local visible, open = ImGui.Begin(ctx, 'My window', true)
    DL.imgui.SWSPassKeys(ctx, false)
    if visible then
        demo.PushStyle(ctx)
        demo.ShowDemoWindow(ctx)

        print(FLT_MIN)
        ImGui.Button(ctx, '0', -0.1)
        ImGui.Button(ctx, 'FLT', -FLT_MIN)
        ImGui.Button(ctx, '-1', -1)
        local midi_input = DL.midi_io.GetInput()
        DL.imgui.MIDILearn(ctx, midi_table, midi_input)
        
        for proj in DL.enum.Projects() do
            ImGui.Text(ctx, DL.proj.GetFullPath(proj))
        end

        demo.PopStyle(ctx)
        ImGui.End(ctx)
    end
    ImGui.PopFont(ctx)
    if open then
        reaper.defer(loop)
    end
end

reaper.defer(loop)
