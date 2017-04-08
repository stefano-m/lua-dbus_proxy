--[[
  Copyright 2017 Stefano Mazzucco

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
]]

---  @submodule dbus_proxy

local VariantType = require("lgi").GLib.VariantType

local variant = {}

--[[-- Strip an `lgi.GLib.VariantType` object of its types

@param[type=lgi.GLib.VariantType] v an `lgi.GLib.VariantType` object

@return simple lua data (nested structures will be stripped too). The C to lua
type correspondence is straightforward:

  - numeric types will be returned as lua numbers
  - booleans are preserved
  -  string are preserved,
  - object paths (e.g. `/org/freedesktop/DBus`) will be returned as strings too
  - arrays (homogeneous types, signature `a`) and tuples (mixed types, signature `()`) will be returned as lua arrays
  - dictionaries (signature `{}`) will be returned as lua tables

@usage
GVariant = require("lgi").GLib.VariantType

-- strip a nested variant
v1 = GVariant("v", GVariant("s", "in a variant"))
stripped1 = variant.strip(v1)
-- "in a variant"

-- strip a dictionary of variants
v2 = GVariant("a{sv}", {one = GVariant("i", 123),
                              two = GVariant("s", "Lua!")})
stripped2 = variant.strip(v2)
-- {one = 123, two = "Lua!"}

-- strip a nested array
v3 = GVariant("aai", {{1, 2, 3}, {4, 1, 2, 3}})
stripped3 = variant.strip(v3)
-- {{1, 2, 3}, {4, 1, 2, 3}, n=2}
]]
function variant.strip(v)
  if type(v) ~= "userdata" then
    -- FIXME: Won't work if there's userdata inside a variant
    return v
  end

  if v:is_of_type(VariantType.DICTIONARY) then
    local out = {}
    for key, val in v:pairs() do
      out[key] = variant.strip(val)
    end
    return out
  elseif v:is_of_type(VariantType.TUPLE)
      or v:is_of_type(VariantType.ARRAY) then
    local out = {}
    for idx, val in v:ipairs() do
      if type(val) == "table" then
        -- This is hacky, but nested tuples don't
        -- carry their type, so I have to manually
        -- strip the 'n'
        val.n = nil
      end
      out[idx] = variant.strip(val)
    end
    return out
  else
    return variant.strip(v.value)
  end

end

return variant
