--@noindex
function LearnMarkov(t, order) -- Learn markov from a table 't'
    local nothing = '*'
    local separetor = ';'
    local last_val = {}
    for i = 0, order-1 do
        table.insert(last_val,nothing)
    end

    local markov_table = {}

    for key, value in ipairs(t) do
        -- Create a string version of the last values
        markov_table = AddInsideMarkovTable(markov_table,last_val,value,separetor)

        -- Add current value to last_val list and remove the oldest
        table.subs(last_val,value)    
        -- Just once add nothing with the values at the end of the list
        if key == #t then
            markov_table = AddInsideMarkovTable(markov_table,last_val,nothing,separetor)
        end
    end

    markov_table['###source'] = {TableCopy(t)} 
    return markov_table
end
---Learn Markov from table 't' and add the keys to t_markov. Return the new t_markov
---@param t table table to learn markov
---@param t_markov table markov table that receives the new keys
---@param order number order num
---@return table markov table
function AddLearnMarkov(t,t_markov,order)
    local temp_markov = LearnMarkov(t, order) 
    return TablesCombineKeys(temp_markov,t_markov) 
end

function AddInsideMarkovTable(markov_table,last_val,value,separetor) -- Checks if markov_table haves last_val (as string) key if it does add 'value' to it. Else create this key as a table and add the value to it
    local last_val_string = table.concat(last_val,separetor)
    if not markov_table[last_val_string] then 
        markov_table[last_val_string] = {}
    end
    table.insert(markov_table[last_val_string],value)
    return markov_table
end

----------
---- Get/Apply Functions
----------

function MarkovGetValue(t_markov, last_val_string) -- Low level 
    local random_n = math.random(#t_markov[last_val_string])
    return t_markov[last_val_string][random_n]
end

function MarkovTableFilterNothingSymbol(t_markov,nothing)
    for key, table_results in pairs(t_markov) do
        if not string.match(key,'^###') then
            for key2,result in ipairs(table_results) do
                if result == nothing then
                    table_results[key2] = nil
                end
            end
            -- If I remove all values from the table_results, remove this key from t_markov
            if #table_results == 0 then 
                t_markov[key] = nil
            end
        end
    end
    return t_markov
end

function MarkovTableGetRandomKeyVal(t)
    local r_number = math.random(TableLen(t)-1) -- -1 to desconsider ###source.  to genarilize it remove -1
    local cnt = 1
    for key, value in pairs(t) do
        if not string.match(key,'^###') then -- Disconsider ###source
            if cnt == r_number then return key,value end
            cnt = cnt + 1
        end
    end
end

-- Alternative Markov Functions, they are used in the main function to try lower orders faster than remaking markov tables. 

function Markov2AddToList(markov_table, value)
    local separetor = ';'
    local nothing = '*'
    if type(value) =="table" then
        value = table.concat(value,separetor) -- Will add at the last one ???
    elseif type(value) ~= "string" then
        value = tostring(value)        
    end
    value = nothing..separetor..value..separetor..nothing

    table.insert(markov_table,value)
    return markov_table
end

--- @param markov_table table table with courpuse as strings
--- @param wanted table table or string of previous values 
--- @param filter_nothing boolean if true will rule out results that are 'nothing_symbol' 
function Markov2MakeOptionsList(markov_table, wanted, filter_nothing)
    local separetor = ';'
    local nothing = '*'
    if type(wanted) == 'table' then
        wanted = table.concat(wanted,separetor)
    end
    -- Small correction with the string
    if not string.match(wanted,separetor..'$') then -- If not end with separetor
        wanted = wanted..separetor --
    end
    wanted = DeleteRepetitionsOfNothing(wanted, nothing , separetor)
    wanted = literalize(wanted)
    separetor = literalize(separetor)

    -- wanted looks like : valX;valY;
    local options = {}
    for key, value in pairs(markov_table) do
        value = value..separetor -- Need to add to catch the last one
        for string_match in SubString(value,wanted..'(.-)'..separetor) do --Catch all the substring
            local temp_result_Val
            for val in string.gmatch(string_match,'(.-)'..separetor) do -- Catch only the result
                temp_result_Val = val
            end
            if not filter_nothing or (filter_nothing and temp_result_Val ~= nothing) then  -- filter nothing is on it will filter results that would be nothing_symbol
                table.insert(options,temp_result_Val)
            end
        end 
    end
    return options
end

-- Utility
function DeleteRepetitionsOfNothing(str, nothing , separetor) -- delete repetitions of nothing in start and end of a sequence like *;*;1;2 or 1,2,*,*
    -- test with print(DeleteRepetitionsOfNothing('*;*;*;1;2;*;*;*;*;', '*' , ';') )
    nothing = literalize(nothing)
    separetor = literalize(separetor)
    -- start    
    while string.match(str,'^'..nothing..separetor..nothing) do
        str = string.match(str,'^'..nothing..separetor..'('..nothing..'.+)')
    end
    -- end    
    while string.match(str,nothing..separetor..nothing..separetor..'$') do
        str = string.match(str,'(.+'..nothing..separetor..')'..nothing..separetor..'$')
    end
    return str
end

---------------------------------------------------------------------------------------------------------------------

-- Lower/Change Order

---@param t_markov table --Markov table
---@param last_val table --table with last values
---@return table -- withreturn a table with possible results
function MarkovSearchSourceForLowerOrder(t_markov , last_val, filter_nothing) -- will reduce order in last_val list until find it in the corpous or return false.
    -- First make a table with all source as a big string. {1,5,6} will become '*;1;5;6;*'
    local source_markov_string = {}
    for _, source in pairs(t_markov['###source']) do
        source_markov_string = Markov2AddToList(source_markov_string, source)  --source_markov_string table each value is the pased markov source table as string.
    end
    local result = LowerOrderAndSearch(source_markov_string,last_val,filter_nothing) -- Try to find in the strings inside source_markov_string results that match the previous last_val
    return result 
end

---@param source_markov_string table table with sources as strings as {source1_string,source2_string} 
---@param last_val table table contaning last values as {'c','d'}
---@param filter_nothing boolean filter results that are nothing_symbol.
---@return any return table with values or false if dont find any.
function LowerOrderAndSearch(source_markov_string,last_val,filter_nothing) -- Reduce last_val table until find some instances of it in source_markov_string table
    local temp_last_val =  TableCopy(last_val)
    table.remove(temp_last_val,1)
    if #temp_last_val == 0 then return false end --Cant go to order 0 Here. Stop recursive if tries to reduce too much
    local results = Markov2MakeOptionsList(source_markov_string,temp_last_val,filter_nothing)
    if #results > 0 then
        return results
    else
        return LowerOrderAndSearch(source_markov_string, temp_last_val, filter_nothing)
    end
end

--- Tries to reduce the order, if fail will try to get in the t_markov the key with more matches, if none will get any key (order = 0). Return a table with the new options!
function ChangeOrder(t_markov,last_val,last_val_string,filter_nothing,separetor)
    ---------------
    -- Reduce Order 
    -- The methods used here looks in the source as strings and try to find a match for last_value. Probably faster then construc markov tables and then looking at them. 
    -- OBS this method hava the limitation that the result is always as string, even if the source was made by numbers. Maybe I should rebuild the markov table and look using this method.
    ---------------
    local results = MarkovSearchSourceForLowerOrder(t_markov, last_val, filter_nothing) -- Uses alternative method for Markov Chain: look for a piece of string in the corpuse as string 
    if results then
        -- Will return here instead of substituing the variables (like the other solutions bellow)
        return results
    end
    ---------------
    --Get something similar (same items different order) 
    --(will never happen because if the last value in last_val is in t_markov sequence it will use Reduce Order.) Only way is putting this up in hierarchy. 
    ---------------
    --[[         for key, _ in pairs(t_markov) do
                if string.match(key,'^###')  then goto continue end
                local test_table_no_order = {}
                local key_sep = key..separetor -- to get the last value
                for val in string.gmatch(key_sep,'(.-)'..separetor) do
                    table.insert(test_table_no_order,val)
                end
                if TableValuesCompareNoOrder(test_table_no_order,last_val) then -- Check if both tables have the same items. 
                    last_val_string = key
                    goto found
                end
                ::continue::      
            end ]]
    ---------------
    --Select markov key with more matches -- Not tested
    ---------------
    local possible_keys = {} -- Will save keys that have highest matches.
    local max = 0
    for key, _ in pairs(t_markov) do
        if string.match(key,'^###')  then goto continue end
        local test_count_table = {}

        local key_sep = key..separetor -- to get the last value
        for val in string.gmatch(key_sep,'(.-)'..separetor) do
            table.insert(test_count_table,val)
        end
        local cnt = TableValuesCompareCount(test_count_table,last_val)
        if cnt > 0 and cnt > max then -- Found a bigger key match
            possible_keys = {}
            max = cnt
            table.insert(possible_keys,key)
        elseif cnt > 0 and cnt == max then -- Found same value key match
            table.insert(possible_keys,key)               
        end
        ::continue::
    end
    if #possible_keys > 0 then
        last_val_string = possible_keys[math.random(#possible_keys)]
    end
    ---------------
    --Get Any key
    ---------------
    last_val_string = MarkovTableGetRandomKeyVal(t_markov)
    return t_markov[last_val_string]
end

-- Apply Markov

--- @param original_t_markov table --Markov table
--- @param last_val table -- Last values inside a table
--- @param filter_nothing boolean -- if on it will remove all occurances of nothing_symbol in t_markov. Will never result in a nothing Symbol.
--- @param raise_error boolean -- if on will raise a error if it got no key with last_val info. if off will try to find a result lowering the order, searching markov key values with more matches, get a random value. 
--- @return table -- table with the sequece in the values
function ApplyMarkov(original_t_markov, last_val, filter_nothing, raise_error) -- Do more fancy stuff before calling MarkovGetValue using last_Val table chose a random value with that key in the t_markov. Maybe have a order min and order max and the function tries to bend between them
    local nothing = '*'
    local separetor = ';'
    local last_val_string = table.concat(last_val,separetor)

    local t_markov = TableCopy(original_t_markov)
        
    --Filter results = nothing_symbol in t_markov
    if filter_nothing then
        t_markov = MarkovTableFilterNothingSymbol(t_markov,nothing)
    end

    -- What will happen if there is not that key in the markov table. Options == 0 
    if not t_markov[last_val_string] and not raise_error then
        local t = ChangeOrder(t_markov,last_val,last_val_string,filter_nothing,separetor) -- Return table with all possible values
        return t[math.random(#t)]
    end

    if not t_markov[last_val_string] then
        return false
    end

    --Change the order based on number of options (optional). User specifiy an ideal min and max number of options. Too much options it can be random like.  Too little it can copy the source. 

    return MarkovGetValue(t_markov, last_val_string) 
end


--- @param t_markov table --Markov table
--- @param len number -- length of the generated sequence. The generated sequence table will start with the same indexes as start table (or markov_order indexes of nothing symbol) then the generated sequence that the length will be  = len
--- @param order number -- set the order used in markov, if nil will use ###ordeer in t_markov
--- @param start table -- hardcode the start of the sequence. if set to nil or a blank table. it will create the start using nothing symbols 
--- @param filter_nothing boolean -- if on it will remove all occurances that generates nothing_symbol in t_markov
--- @param break_on_nothing boolean -- if sequence is generate a '*' it will stop the sequence
--- @return table -- table with the sequece in the values
function GenerateMarkovSequence(t_markov,len,order,start,filter_nothing,break_on_nothing) -- TODO Filter nothing option add order. 
    local nothing = '*'
    local separetor = ';'
    if not order then order = #t_markov end
    local last_val = start
    -- If nothing is nil then fill last_val with nothing symbol order times.
    if not last_val or #last_val == 0 then 
        last_val = {}
        for i = 1, order do
            table.insert(last_val,nothing)
        end
    end
    -- Generate Sequence
    local sequence = TableCopy(last_val)
    for i = 1, len do
        --local result = ApplyMarkov(t_markov, last_val, true, false)
        local result = ApplyMarkovWeighted(t_markov, last_val, true, pos_weight_table)
        table.insert(sequence,result)
        table.subs(last_val, result)
        if break_on_nothing and result == nothing then break end
    end
    return sequence
end

---Fill a last value tables with the nothing symbol. Using Order length as the numbers or nothing
---@param last_val table table contaning last values
---@param order number markov order to be used
---@param nothing string string symbol of nothing.
function FillLastValTableWithNothing(last_val,order,nothing)
    for i = 1, order do
        table.insert(last_val,nothing)
    end
end

--------
-- New Markov Get/Apply with Weights and flotat chances
-- the Markov table will still be learned with the same mathods. because I need to gather all the possibilities first anyway, and then calculate the chances
-- Transform the selected markov table happens only when applying. 
-- markov_table = {['1;3'] = {4,1,4},['4;2'] = {5,5,5,3}} if will use the '1;3' key then it will become:
-- new_t = { 4 = {chance = 2}, 1 = {chance = 1}} 

---Apply Markov using original_t_markov markov table. And table last_val as the last values to search. 
---@param original_t_markov table --Markov table
---@param last_val table -- Last values inside a table
---@param filter_nothing boolean -- if on it will remove all occurances of nothing_symbol in t_markov. Will never result in a nothing Symbol.
---@param weight_table table -- table with the weight to be used = {w = int, type = 'specific', max_distance = 127, w_values = {{w = integer, val = integer}, {w = integer, val = integer} , {w = integer, val = integer}}}. Have tables inside with the weight(w) for the value(val). It haves 3 type = 'specific', type = 'distance', type = 'closest distance'(default if nil). if specific type it will only weight that value. if 'closest distance'  it  weighted based on the distance of the closest value, if 'distance' it will weight all values   !!!Important :if distance or closest_distance it NEED max_distance variable. for distance  weight_table.linear == integer it will use a exponential function beaing weight_table.linear^(-distance)
---@return unknown
function ApplyMarkovWeighted(original_t_markov, last_val, filter_nothing, ...)
    local function make_chance_table(options_t) 
        local new_t = {}
        for key, value in pairs(options_t) do
            if new_t[value] then -- increase the value chance
                new_t[value].chance = new_t[value].chance + 1
            else -- add the value
                new_t[value] = {chance = 1, val = value}
            end
        end
        return new_t
    end

    local function choose_random_from_options(chance_table)
        local sum = 0
        local divider = {} -- table contaning the the tables inside chance_table and the sum of the chances after they are added. ex = chance_table = {val1 = {chance = 2}, val2 = {chance = 1}}  divider = {{table = chance_table.val1, sum = 2}, {table = chance_table.val2, sum = 3}}
        for new_val, val_tab in pairs(chance_table) do
            sum = sum + chance_table[new_val].chance
            divider[#divider+1] = {table = chance_table[new_val], sum = sum}
        end
    
        local new_val
        local random = RandomNumberFloat(0, sum, false)
        for idx, div_table in ipairs(divider) do
            if div_table.sum > random then
                new_val = div_table.table.val
                break
            end
        end
        return new_val
    end

    local nothing = '*'
    local separetor = ';'
    local last_val_string = table.concat(last_val,separetor)

    local t_markov = TableCopy(original_t_markov)
    local options -- selected table with the possibilities for next event
        
    --Filter results = nothing_symbol in t_markov
    if filter_nothing then
        t_markov = MarkovTableFilterNothingSymbol(t_markov,nothing)
    end

    -- Set the options table
    if not t_markov[last_val_string] then
        -- What will happen if there is not that key in the markov table. Options == 0 
        --Change the order based on number of options (optional). User specifiy an ideal min and max number of options. Too much options it can be random like.  Too little it can copy the source. 
        local t = ChangeOrder(t_markov,last_val,last_val_string,filter_nothing,separetor) -- Return table with all possible values
        options = t
    else 
        options = t_markov[last_val_string]
    end

    --- Get chance table
    local chance_table = make_chance_table(options) 

    --- Weight the table. Linear
    local weight_tables = {...}
    if weight_tables and #weight_tables > 0 then
        for index, weight_table in pairs(weight_tables) do
            for val_key, value_table in pairs(chance_table) do -- value_table = {chance = x, val = y} val is also the key
                if weight_table.type == 'specific' then
                    for w_key, w_value in ipairs(weight_table.w_values) do
                        local val = tonumber(MidiParametersSeparate(value_table.val)[1]) -- the first event val
                        local w_val_num = tonumber(MidiParametersSeparate(w_value.val)[1]) -- the first event val
                        if val == w_val_num then 
                            value_table.chance = value_table.chance * (w_value.w) -- other options is (weight_table.w*w_value.w). But I am already using weight_table.w to scale w_value.w
                            break
                        end
                    end
                elseif weight_table.type == 'closest distance' or not weight_table.type then-- 'closest distance'  find the closest distance of value_table.val at weight table weight according to it
                    local closest_distance = math.huge
                    local weight -- save the weight 
                    -- get closest distace
                    for w_key, w_value in ipairs(weight_table.w_values) do
                        local val = MidiParametersSeparate(value_table.val)[1] -- the first event val
                        local distance = math.abs(val - w_value.val)
                        if distance < closest_distance then 
                            closest_distance = distance
                            weight = w_value.w
                        elseif closest_distance == distance then -- if it have a tie then get the medium
                            weight = (weight + w_value.w)/2
                        end
                    end
                    --local propotional_distance = closest_distance / weight_table.max_distance -- number from (0-1) distance = 0 and distance = max_distance
                    local multiply_w = weight_table.linear^(-closest_distance) -- number from 1(distance  =0) to 0(distance = inf). weight_table.linear change
                    if weight < 1 then -- nerfing chance with weight and multiply_w is nerfing the weight
                        value_table.chance = value_table.chance * ((weight)/multiply_w)
                    elseif weight > 1 then -- buffing chance with weight and multiply_w is buffing the weight
                        value_table.chance = value_table.chance * ((weight)*multiply_w)
                    end
                elseif weight_table.type == 'distance'  then -- use all values of weight_table weight.
                    for w_key, w_value in ipairs(weight_table.w_values) do
                        local val = MidiParametersSeparate(value_table.val)[1] -- the first event val
                        local distance = math.abs(value_table.val - w_value.val)
                        local propotional_distance = distance / weight_table.max_distance -- number from (0-1) distance = 0 and distance = max_distance
                        local multiply_w = LimitNumber(1 - propotional_distance,0.001) -- have to limit to not exclude this 
                        value_table.chance = value_table.chance * ((w_value.w)*multiply_w) --- Maybe I should just calculate to the closest this way every weight value is weighning
                    end
                end
            end
        end
    end
    --- Choose from chance table (put in a local(?) function)
    local new_val = choose_random_from_options(chance_table)

    return new_val
end

function GenerateMarkovWeighted()
    

end

--- Utility
--[[
    local propotional_distance = closest_distance / weight_table.max_distance -- number from (0-1) distance = 0 and distance = max_distance
    if weight_table.linear == 'linear' then
        local multiply_w = LimitNumber(1 - propotional_distance,0.001) -- have to limit to not exclude this 
        value_table.chance = value_table.chance * ((weight)*multiply_w)
    else -- exponencial
        local multiply_w = weight_table.linear^(-propotional_distance)
        value_table.chance = value_table.chance * ((weight)*multiply_w)
    end
]]