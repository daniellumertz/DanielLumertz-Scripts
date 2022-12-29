--@noindex

---Get an envelope and return min, max, center. By Cfillion
---@param env Envelope
---@return number min
---@return number max
---@return number center
local function getEnvelopeRange(env)
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
