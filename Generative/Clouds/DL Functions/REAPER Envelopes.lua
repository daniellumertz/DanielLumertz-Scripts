--@noindex
--version: 0.0

DL = DL or {}
DL.env = {}

---Get The Envelope by the GUID. Search at tracks and/or items
---@param proj ReaProject|0|nil
---@param guid string GUID to search, with {}.
---@param is_track number 0 = just items, 1 just tracks, 2 both
---@return TrackEnvelope?
function DL.env.GetByGUID(proj, guid, is_track)
    if is_track == 1 or is_track == 2 then
        for track in DL.enum.Tracks(proj) do
            local env = reaper.GetTrackEnvelopeByChunkName( track, guid )
            if env then
                return env
            end
        end
    end

    if is_track == 0 or is_track == 2 then
        for item in DL.enum.Items(proj) do
            for take in DL.enum.Takes(item) do
                for env in  DL.enum.TakeEnvelopes(take) do
                    if guid == DL.env.GetGUID(env) then
                        return env
                    end
                end
            end
        end
    end
end

---Return the GUID of a envelope.
---@param env TrackEnvelope Envelope 
---@return string? guid Guid
function DL.env.GetGUID(env)
    local retval, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
    return DL.chunk.GetVal(chunk,'EGUID')
end

---Return if the envelope bypass. 
---@param env TrackEnvelope Envelope
---@return boolean is_passing false = bypass, true = not bypass
function DL.env.IsBypass(env)
    local retval, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
    return DL.chunk.GetVal(chunk,'ACT'):match('^%d+') == '1'
end

---Get an envelope and return min, max, center. By Cfillion
---@param env TrackEnvelope
---@return number min
---@return number max
---@return number center
function DL.env.GetRange(env)
  local ranges = {
    ['PARMENV'] = function(chunk)
      local min, max = chunk:match('^[^%s]+ [^%s]+ ([^%s]+) ([^%s]+)')
      local min, max = tonumber(min), tonumber(max)
      return min, max, (max - min)/2
    end,
    ['VOLENV']   = function()
      local range = reaper.SNM_GetIntConfigVar('volenvrange', 0)
      local maxs = {
        [3]=1,  [1]=1,
        [2]=2,  [0]=2,
        [6]=4,  [4]=4,
        [7]=16, [5]=16,
      }
      return 0, maxs[range] or 2, 1
    end,
    ['PANENV']   = { -1, 1, 0 },
    ['WIDTHENV'] = { -1, 1, 0 },
    ['MUTEENV']  = { 0, 1, 0.5 },
    ['SPEEDENV'] = { 0.1, 4, 1 },
    ['PITCHENV'] = function()
      local range = reaper.SNM_GetIntConfigVar('pitchenvrange', 0) & 0x0F
      return -range, range, 0
    end,
    ['TEMPOENV'] = function()
      local min = reaper.SNM_GetIntConfigVar('tempoenvmin', 0)
      local max = reaper.SNM_GetIntConfigVar('tempoenvmax', 0)
      return min,max, (max + min)/2
    end,
  }
  
  local ok, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
  assert(ok, 'failed to read envelope state chunk')

  local envType = chunk:match('<([^%s]+)')
  for matchType, range in pairs(ranges) do
    if envType:find(matchType) then
      if type(range) == 'function' then
        return range(chunk)
      end
      return table.unpack(range)
    end
  end
  
  error('unknown envelope type')
end

---Higher level function over reaper.Envelope_Evaluate. Return same values but if is an item adjust position for reaper.Envelope_Evaluate. If is at an item and position is out of bounds, return false.
---@param envelope TrackEnvelope
---@param pos number
---@param samplerate number
---@param samplesRequested number
---@return number|boolean retval
---@return number? value
---@return number? dVdS
---@return number? ddVdS
---@return number? dddVdS
function DL.env.Evaluate(envelope, pos, samplerate, samplesRequested)
    local item = reaper.GetEnvelopeInfo_Value( envelope, 'P_ITEM' )
    local is_at_item = item ~= 0 and true or false
    if is_at_item then -- Trim the envelope input to the item length
        local item_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
        local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
        if pos < item_pos or pos > item_pos+item_len then return false end
        pos = pos - item_pos
    end
    local retval, value, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(envelope, pos, samplerate, samplesRequested)
    return retval, value, dVdS, ddVdS, dddVdS
end