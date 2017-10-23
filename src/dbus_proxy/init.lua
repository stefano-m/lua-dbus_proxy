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

--[[--
  Simple API around GLib's GIO:GDBusProxy built on top of lgi.

  @license Apache License, version 2.0
  @author Stefano Mazzucco <stefano AT curso DOT re>
  @copyright 2017 Stefano Mazzucco
  @module dbus_proxy
]]

local Bus = require("dbus_proxy._bus")
local Proxy = require("dbus_proxy._proxy")
local variant = require("dbus_proxy._variant")
local monitored = require("dbus_proxy._monitored")

return {
  Proxy = Proxy,
  Bus = Bus,
  variant = variant,
  monitored = monitored,
}
