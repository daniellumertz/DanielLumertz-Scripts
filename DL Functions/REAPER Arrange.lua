--@noindex
--version: 0.20



-----------
--------- Time / QN
-----------


---------
----- Marker / Region
---------


-----------
------ Envelopes
-----------

-----------
--------- Automation Items
-----------


-----------
------ Position
-----------

function GetCurrentPlayPosition(proj)
    local is_play = reaper.GetPlayStateEx(proj)&1 == 1 -- is playing 
    local pos = (is_play and reaper.GetPlayPositionEx( proj )) or reaper.GetCursorPositionEx(proj) -- current pos
    return pos
end