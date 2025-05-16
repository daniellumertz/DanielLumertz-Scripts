-- @version 0.1.1b
-- @author Daniel Lumertz
-- @provides
--    [nomain] DL Functions/*.lua
--    [nomain] Manager Functions/*.lua
-- @changelog
--    + Initial release
-- @license MIT

-- Initialize ImGUI?
package.path = package.path..';'..reaper.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9.3' 

-- Variables
SCRIPT_NAME = 'Backup Manager'
SCRIPT_V = '0.1.1b' 
DL_version_btn = false -- if you turn this true, it will enable an >experimental< feature to limit the number of versions of each file. Seems to be working, but it is too slow, so I stopped developing it in lua.  

-- Import functions from DL functions folder
package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
require("DL Functions.General Debug")
require("DL Functions.General Files")
require("DL Functions.REAPER Enumerate")
require("DL Functions.REAPER Projects")
require('DL Functions.General Number')
require('DL Functions.General String')
require('DL Functions.ImGui')
require('DL Functions.General Table')
require('DL Functions.URL')
require('Manager Functions.Theme')
require('Manager Functions.Main GUI')
require('Manager Functions.Backup')
require('Manager Functions.Misc')

-- Debug
--local VSDEBUG = dofile("c:/Users/DSL/.vscode/extensions/antoinebalaine.reascript-docs-0.1.12/debugger/LoadDebug.lua")
--VSDEBUG = dofile("c:/Users/liane/.vscode/extensions/antoinebalaine.reascript-docs-0.1.12/debugger/LoadDebug.lua")
reaper.defer(DL_Manager.GUI)

--[[
MIT License

Copyright (c) 2025 Daniel Lumertz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]