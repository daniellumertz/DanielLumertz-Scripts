-- @noindex
reaper.Undo_BeginBlock() 
ScriptName = 'Track Snapshot' -- Use to call Extstate dont change
reaper.SetProjExtState( 0, ScriptName, 'SnapshotTable', '' )
reaper.Undo_EndBlock2(0,'Delete Snapshots On Project',-1)
