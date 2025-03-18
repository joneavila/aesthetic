--- OrderedDict implementation
-- A dictionary that maintains insertion order of keys
local OrderedDict = {}
OrderedDict.__index = OrderedDict

--- Create a new OrderedDict instance
function OrderedDict.new()
	return setmetatable({
		_keys = {}, -- Array to maintain order
		_values = {}, -- Regular table for key-value pairs
	}, OrderedDict)
end

--- Insert a new key-value pair or update existing value
function OrderedDict:insert(key, value)
	if not self._values[key] then
		table.insert(self._keys, key)
	end
	self._values[key] = value
end

--- Get a value by key
function OrderedDict:get(key)
	return self._values[key]
end

--- Get all keys in order
function OrderedDict:keys()
	return self._keys
end

--- Get all values in order
function OrderedDict:values()
	local result = {}
	for _, key in ipairs(self._keys) do
		table.insert(result, self._values[key])
	end
	return result
end

--- Iterator function for pairs
function OrderedDict:pairs()
	local i = 0
	return function()
		i = i + 1
		local key = self._keys[i]
		if key then
			return key, self._values[key]
		end
	end
end

--- Get the number of items in the dictionary
function OrderedDict:count()
	return #self._keys
end

return OrderedDict
