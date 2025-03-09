local mod = dmhub.GetModLoading()

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function table.count_elements(t)
    local count = 0
    for _, _ in pairs(t) do
        count = count + 1
    end
    return count
end

function table.remove_value(t, element)
    for i=#t, 1, -1 do
        if t[i] == element then
            table.remove(t, i)
        end
    end
end

function table.empty(t)
    return next(t) == nil
end

function table.keys(t)
    local keys = {}
    for k, _ in pairs(t) do
        keys[#keys+1] = k
    end
    return keys
end

function table.values(t)
    local values = {}
    for _, v in pairs(t) do
        values[#values+1] = v
    end
    return values
end

function table.shallow_copy(t)
    local result = {}
    for k,v in pairs(t) do
        result[k] = v
    end

    return result
end

function table.append_arrays(t1, t2)
    local result = {}

    for _, v in ipairs(t1 or {}) do
        result[#result+1] = v
    end

    for _, v in ipairs(t2 or {}) do
        result[#result+1] = v
    end

    return result
end

function map(t, f)
    local result = {}
    for i, v in ipairs(t or {}) do
        result[i] = f(v)
    end
    return result
end

function filter(t, f)
    local result = {}
    for k, v in pairs(t) do
        if f(v) then
            result[k] = v
        end
    end
    return result
end

function sorted_pairs(t)
    local keys = table.keys(t)
    table.sort(keys)
    local nextKey = {}
    for i, key in ipairs(keys) do
        nextKey[key] = keys[i+1]
    end
    nextKey[0] = keys[1]
    return function(a, key)
        key = nextKey[key]
        if key ~= nil then
            local value = t[key]
            return key, value
        end
    end, t, 0
end

local next_unhidden = function(t, key)
    local val
    key, val = next(t, key)
    while val ~= nil and rawget(val, "hidden") do
        key, val = next(t, key)
    end

    return key, val
end

function unhidden_pairs(t)
    return next_unhidden, t, nil
end

---@param s string
---@return string
function string.trim(s)
    if type(s) ~= "string" then
        return s
    end
    local a = s:match('^%s*()')
    local b = s:match('()%s*$', a)
    return s:sub(a,b-1)
 end
 
function string.starts_with(String,Start)
	return string.sub(String,1,string.len(Start)) == Start
end

function string.ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

function math.clamp(x, a, b)
    if x < a then
        return a
    end

    if x > b then
        return b
    end

    return x
end

function math.clamp01(x)
    if x < 0 then
        return 0
    end

    if x > 1 then
        return 1
    end

    return x
end


function MatchesSearchRecursive(obj, search, depth)
    depth = depth or 0
    if depth > 16 then
        return false
    end
    if type(obj) == "table" then
        for k,v in pairs(obj) do
            if MatchesSearchRecursive(k, search, depth+1) or MatchesSearchRecursive(v, search, depth+1) then
                return true
            end
        end
    elseif type(obj) == "string" then
        if string.find(string.lower(obj), search) ~= nil then
            return true
        end
    end

    return false
end

function SearchTableForText(t, search)
    local results = {}
    for k,v in pairs(t) do
        if MatchesSearchRecursive(v, search) then
            results[#results+1] = k
        end
    end

    return results
end

function debug_and_return(item)
    print("DEBUG::", item)
    return item
end