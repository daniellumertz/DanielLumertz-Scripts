--@noindex
function CleanAllItemsLoop(proj, ext_pattern)
    ext_pattern = literalize(ext_pattern)
    local delete_list = {}
    for item in enumItems(proj) do
        local retval, stringNeedBig = reaper.GetSetMediaItemInfo_String( item, 'P_EXT:'..ext_pattern, '', false )
        if stringNeedBig:match(ext_pattern) then 
            table.insert(delete_list,item)
        end
    end
    for k, item in ipairs(delete_list) do
        reaper.DeleteTrackMediaItem( reaper.GetMediaItem_Track(item), item )
    end
    -- Automation Items Dont work it is only for pools
    --[[ for track in enumTracks(proj) do
        for env in enumTrackEnvelopes(track) do
            local delete_list = {}
            local cnt = reaper.CountAutomationItems(env)
            for i = 0, cnt - 1 do
                local retval, ext_state = reaper.GetSetAutomationItemInfo_String(env, i, 'P_POOL_EXT:'..ext_pattern, '', false)
                print(ext_state)
                if ext_state:match(ext_pattern) then 
                    delete_list[#delete_list+1] = i 
                end
            end
            DeleteAutomationItem(env,delete_list)
        end
    end ]]
end

function ExtStatePatterns()
    Ext_Name = 'Gen_Loops'

    Ext_RandomizeTake = 'RandTakes'    
    Ext_TakeChance = 'TakeChance'    
    Ext_MinTime = 'MinTime'    
    Ext_MaxTime = 'MaxTime'    
    Ext_QuantizeTime = 'QuantizeTime'    
    Ext_MinPitch = 'MinPitch'    
    Ext_MaxPitch = 'MaxPitch'
    Ext_QuantizePitch = 'QuantizePitch'    
    Ext_MinRate = 'MinRate'    
    Ext_MaxRate = 'MaxRate'    
    Ext_QuantizeRate = 'QuantizeRate'    
end