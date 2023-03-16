 require("os")

cjson = require("cjson")
io = require("io")
math = require("math")

local api = vim.api
local buf, win
local position = 0

function decode_json(raw)
	return cjson.decode(raw)
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function table.shallow_copy(t)
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end

function convert_json_to_gostruct(json_table, result_agregator, level, path)
	-- print("convert_json_to_gostruct")
	-- root call - initialize variables
	if json_table == nil then
		local path = {}
		local text = get_visual_selection()
		-- print("selection:", text, type(text))
		local s_buf, s_row, s_col, _ = unpack(vim.fn.getpos("'<"))
		local _, e_row, e_col, _ = unpack(vim.fn.getpos("'>"))

		local json_table = decode_json(text)
		-- print("0. json_table:", json_table, type(json_table), dump(json_table))
		local result_agregator = {}

		-- insert struct header
		table.insert(result_agregator, "type Autogenerated struct {")

		convert_json_to_gostruct(json_table, result_agregator, 1, path)

		table.insert(result_agregator, "}")

		-- print("s_row, s_col: ", s_row, s_col, "\ne_row, e_col: ", e_row, e_col)
		-- Keeps trailing visual selection
		vim.api.nvim_buf_set_lines(s_buf, s_row - 1, e_row, false, result_agregator)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<esc>', true, false, true), 'x', false)
		return
	end
	-- running nodes parser
	local prefix = (" "):rep(level * 4)
	-- print("processing json_table: ", type(json_table), json_table, " result_agregator: ", type(result_agregator), result_agregator)
	-- print("path: ", dump(path))
	local max_name_len = 6
	local max_type_len = 13 -- []interface{}
	for key, val in pairs(json_table) do
		-- print("processing ", key, val)
		local name = to_camel_case(key)
		local composed, array, typ = get_data_type(val, name)
		-- print("composed", composed, "array", array, "typ", typ)
		if #name > max_name_len then max_name_len = #name end
		if #typ > max_type_len then max_type_len = #typ end
	end
	local fmt = string.format("%%-%ds    %%-%ds    `json:\"%%s\"`", max_name_len, max_type_len)
	local fmt_composed = string.format("%%-%ds    %%-%ds {", max_name_len, max_type_len)

	for key, value in pairs(json_table) do
		-- print("key: ", key, "value: ", value)
		local name = to_camel_case(key)
		local composed, array, typ = get_data_type(value, name)
		-- print("composed:", composed, "array:", array, "typ:", typ)
		if options ~= nil then
			if meta ~= nil then
			end
		end
		if composed then
			table.insert(
				result_agregator,
				prefix .. string.format(
					fmt_composed, name, typ))

			local currentPath = table.shallow_copy(path)
			table.insert(currentPath, name)
			if array then 
				table.insert(currentPath, "[]")
				if #value > 0 then
					if type(value[1]) == "table" then
						convert_json_to_gostruct(
							value[1], result_agregator, level + 1, currentPath)
					else
						table.insert(
							result_agregator,
							prefix .. string.format(
								fmt, name, "[]".. typ, key))
					end
				else
					table.insert(
						result_agregator,
						prefix .. string.format(
							fmt, name, "[]interface{}", key))
				end
			else
				convert_json_to_gostruct(
					value, result_agregator, level + 1, currentPath)
			end


			table.insert(result_agregator,
				prefix .. string.format("}    `json:\"%s\"`", key))
		else
			table.insert(
				result_agregator, 
				prefix .. string.format(
					fmt, name, typ, key))
		end

	end
end

local types_map = {}
function init_types_map()
	types_map["userdata"] = {false, false, "interface{}"}
	types_map[type("")] = {false, false, "string"}
	types_map[type(true)] = {false, false, "boolean"}
	types_map["number"] = function(n, name)
		if n ~= math.floor(n) then
			return {false, false, "float64"}
		else
			return {false, false, "int64"}
		end
	end
	types_map["table"] = function(t, name)
		if #t > 0 then
			-- processing array
			return {true, true, "[]struct"}
		else
			-- processing obj
			return {true, false,  "struct"}
		end
	end
end
init_types_map()

function get_data_type(obj, name)
	-- print("calculating type of obj: ", type(obj), obj, "name: ", name)
	if obj == nil then return false, false, "interface{}" end
	local item = types_map[type(obj)]

	-- print("calculated type of " .. type(obj) .. " = ", item)
	if type(item) == "function" then
		item = item(obj, name)
		return item[1], item[2], item[3]

	else
		return item[1], item[2], item[3]
	end
end

function to_camel_case(key)
	local patterns = {
		{
			pattern = "__+([a-z])",
	func = function(str, p, s, e, m) return str:gsub(p, m:upper()) end
		},
		{
			pattern = "_+([a-z])",
			func = function(str, p, s, e, m) return str:gsub(p, m:upper()) end
		},
		{
			pattern = "__+([A-Z])",
			func = function(str, p, s, e, m) return str:gsub(p, m) end
		},
		{
			pattern = "_+([A-Z])",
			func = function(str, p, s, e, m) return str:gsub(p, m) end
		},
		{
			pattern = "^([a-z])",
			func = function(str, p, s, e, m) return str:gsub(p, m:upper()) end
		},
		{
			pattern = "^([_\\-0-9])",
			func = function(str, p, s, e, m) return str:gsub(p, "F_" .. m) end
		}
	}
	for _, pattern in ipairs(patterns) do
		while true do
			local s, e, match = key:find(pattern.pattern)
			-- print("key before: ", key)
			-- print("pattern: ", pattern.pattern, "s: ", s, "e: ", e, "match: ", match)
			if match == nil then break end
			key = pattern.func(key, pattern.pattern, s, e, match)
			-- print("key after: ", key)
		end
	end
	return key
end

function get_visual_selection()
  -- print("get_visual_selection endtered")
  local s_start = vim.fn.getpos("'<")
  local s_end = vim.fn.getpos("'>")
  local n_lines = math.abs(s_end[2] - s_start[2]) + 1
  -- print("n_lines = ", n_lines)
  local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, s_end[2], false)
  lines[1] = string.sub(lines[1], s_start[3], -1)
  if n_lines == 1 then
    lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3] - s_start[3] + 1)
  else
    lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3])
  end
  return table.concat(lines, '\n')
end

return {
	Json2GoStruct = convert_json_to_gostruct,
	Json2GoStructExt = function(params)
		print(params)
	end
}
