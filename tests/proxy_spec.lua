-- Works with the 'busted' framework.
-- http://olivinelabs.com/busted/

local b = require("busted")

local GLib = require("lgi").GLib
local GVariant = GLib.Variant

local p = require("dbus_proxy")
local Bus = p.Bus
local Proxy = p.Proxy
local variant = p.variant

b.describe("The Bus table", function ()
             b.it("does not allow to set values", function ()
                    assert.has_error(function ()
                        Bus.something = 1
                                     end, "Cannot set values")
             end)

             b.it("can get the SYSTEM bus", function ()
                    assert.equals("userdata", type(Bus.SYSTEM))
                    assert.equals("Gio.DBusConnection", Bus.SYSTEM._name)
             end)

             b.it("can get the SESSION bus", function ()
                    assert.equals("userdata", type(Bus.SESSION))
                    assert.equals("Gio.DBusConnection", Bus.SESSION._name)
             end)

             b.it("returns a nil with a wrong DBus address", function ()
                    assert.is_nil(Bus.wrong_thing)
             end)

             b.it("can get the bus from an address", function ()
                    local address = os.getenv("DBUS_SESSION_BUS_ADDRESS")
                    if address then
                      local bus = Bus[address]
                      assert.equals("userdata", type(bus))
                      assert.equals("Gio.DBusConnection", bus._name)
                    else
                      print("Address not found. Test skipped.")
                    end
             end)
end)

b.describe("Stripping GVariant of its type", function ()
             b.it("works on boolean types", function ()
                    local v = GVariant("b", true)
                    assert.is_true(variant.strip(v))
             end)

             b.it("works on byte types", function ()
                    local v = GVariant("y", 1)
                    assert.equals(1, variant.strip(v))
             end)

             b.it("works on int16 types", function ()
                    local v = GVariant("n", -32768)
                    assert.equals(-32768, variant.strip(v))
             end)

             b.it("works on uint16 types", function ()
                    local v = GVariant("q", 65535)
                    assert.equals(65535, variant.strip(v))
             end)

             b.it("works on int32 types", function ()
                    local v = GVariant("i", -2147483648)
                    assert.equals(-2147483648, variant.strip(v))
             end)

             b.it("works on uint32 types", function ()
                    local v = GVariant("u", 4294967295)
                    assert.equals(4294967295, variant.strip(v))
             end)

             b.it("works on int64 types", function ()
                    local v = GVariant("x", -14294967295)
                    assert.equals(-14294967295, variant.strip(v))
             end)

             b.it("works on uint64 types", function ()
                    local v = GVariant("t", 14294967295)
                    assert.equals(14294967295, variant.strip(v))
             end)

             b.it("works on double types", function ()
                    local v = GVariant("d", 1.54)
                    assert.equals(1.54, variant.strip(v))
             end)

             b.it("works on string types", function ()
                    local v = GVariant("s", "Hello, Lua!")
                    assert.equals("Hello, Lua!", variant.strip(v))
             end)

             b.it("works on object path types", function ()
                    local v = GVariant("o", "/some/path")
                    assert.equals("/some/path", variant.strip(v))
             end)

             b.it("works on simple variant types", function ()
                    local v = GVariant("v", GVariant("s", "in a variant"))
                    assert.equals("in a variant", variant.strip(v))
             end)

             b.it("works on simple array types", function ()
                    local v = GVariant("ai", {4, 1, 2, 3})
                    assert.same({4, 1, 2, 3}, variant.strip(v))
             end)

             b.it("works on simple nested array types", function ()
                    local v = GVariant("aai", {{1, 2, 3}, {4, 1, 2, 3}})
                    assert.same({{1, 2, 3}, {4, 1, 2, 3}}, variant.strip(v))
             end)

             b.it("works on array types of variant types", function ()
                    local v = GVariant("av",
                                       {GVariant("s", "Hello"),
                                        GVariant("i", 8383),
                                        GVariant("b", true)})
                    assert.same({"Hello", 8383, true}, variant.strip(v))
             end)

             b.it("works on simple tuple types", function ()
                    -- AKA "struct" in DBus
                    local v = GVariant("(is)", {4, "Hello"})
                    assert.same({4, "Hello"}, variant.strip(v))
             end)

             b.it("works on simple nested tuple types", function ()
                    local v = GVariant("(i(si))", {4, {"Hello", 2}})
                    assert.same({4, {"Hello", 2}}, variant.strip(v))
             end)

             b.it("works on tuple types with Variants", function ()
                    local v = GVariant("(iv)", {4, GVariant("s", "Hello")})
                    assert.same({4, "Hello"}, variant.strip(v))
             end)

             b.it("works on simple dictionary types", function ()
                    local v = GVariant("a{ss}", {one = "Hello", two = "Lua!", n = "Yes"})
                    assert.same({one = "Hello", two = "Lua!", n = "Yes"}, variant.strip(v))
             end)

             b.it("works on nested dictionary types", function ()
                    local v = GVariant("a{sa{ss}}",
                                       {one = {nested1 = "Hello"},
                                        two = {nested2 = "Lua!"}})
                    assert.same({one = {nested1 = "Hello"},
                                 two = {nested2 = "Lua!"}},
                      variant.strip(v))
             end)

             b.it("works on dictionary types with Variants", function ()
                    local v = GVariant("a{sv}", {one = GVariant("i", 123),
                                                 two = GVariant("s", "Lua!")})
                    assert.same({one = 123, two = "Lua!"}, variant.strip(v))
             end)

             b.it("works on tuples of dictionaries", function ()

                    local v = GVariant(
                      "(a{sv})",
                      {
                        {
                          one = GVariant("s", "hello"),
                          two = GVariant("i", 123)
                        }
                      }
                    )

                    local actual = variant.strip(v)

                    assert.is_true(#actual == 1)

                    assert.same(
                      {one = "hello", two = 123},
                      actual[1])
             end)

end)


b.describe("DBus Proxy objects", function ()
             b.it("can be created", function ()

                    local proxy = Proxy:new(
                      {
                        bus = Bus.SESSION,
                        name = "org.freedesktop.DBus",
                        path= "/org/freedesktop/DBus",
                        interface = "org.freedesktop.DBus"
                      }
                    )

                    assert.equals("Gio.DBusProxy", proxy._proxy._name)
                    -- g-* properties
                    assert.equals("org.freedesktop.DBus", proxy.interface)
                    assert.equals("/org/freedesktop/DBus", proxy.object_path)
                    assert.equals("org.freedesktop.DBus", proxy.name)
                    assert.equals(Bus.SESSION, proxy.connection)
                    assert.same({NONE = true}, proxy.flags)
                    assert.equals("org.freedesktop.DBus", proxy.name_owner)

                    -- generated methods
                    assert.is_function(proxy.Introspect)
                    assert.equals("<!DOCTYPE",
                                  proxy:Introspect():match("^<!DOCTYPE"))
                    assert.is_table(proxy:ListNames())

                    assert.has_error(
                      function () proxy:Hello("wrong") end,
                      "Expected 0 parameters but got 1")

                    -- See dbus-shared.h
                    local DBUS_NAME_FLAG_REPLACE_EXISTING = 2
                    assert.equals(
                      1,
                      proxy:RequestName("com.example.Test1",
                                        DBUS_NAME_FLAG_REPLACE_EXISTING)
                    )
             end)

             b.it("can access properties", function ()
                    -- This is a bit hacky, but I don't
                    -- know how to make it better.
                    local device = Proxy:new(
                      {
                        bus = Bus.SYSTEM,
                        name = "org.freedesktop.UPower",
                        interface = "org.freedesktop.UPower.Device",
                        path =
                          "/org/freedesktop/UPower/devices/battery_BAT0"
                      }
                    )

                    assert.is_number(device.Percentage)
                    assert.is_true(device.IsPresent)
                    assert.is_string(device.Model)

                    assert.has_error(
                      function () device.Percentage = 1 end,
                      "Property 'Percentage' is not writable")

             end)

             b.it("can handle signals", function ()

                    local proxy = Proxy:new(
                      {
                        bus = Bus.SESSION,
                        name = "org.freedesktop.DBus",
                        path= "/org/freedesktop/DBus",
                        interface = "org.freedesktop.DBus"
                      }
                    )

                    local ctx = GLib.MainLoop():get_context()

                    local called = false
                    local received_proxy
                    local received_params
                    local function callback(proxy_obj, params)
                      -- don't do assertions in here because a failure
                      -- would just print an "Lgi-WARNING" message
                      called = true
                      received_proxy = proxy_obj
                      received_params = params
                    end

                    -- this signal is also used when *new* owners appear
                    local signal_name = "NameOwnerChanged"
                    local sender_name = nil -- any sender
                    proxy:connect_signal(callback, signal_name, sender_name)

                    local bus_name = "com.example.Test2"
                    -- See dbus-shared.h
                    local DBUS_NAME_FLAG_REPLACE_EXISTING = 2
                    assert.equals(
                      1,
                      proxy:RequestName(bus_name,
                                        DBUS_NAME_FLAG_REPLACE_EXISTING)
                    )

                    -- Run an iteration of the loop (blocking)
                    -- to ensure that the signal is emitted.
                    assert.is_true(ctx:iteration(true))

                    assert.is_true(called)
                    assert.equals(proxy, received_proxy)
                    assert.equals(3, #received_params)
                    assert.equals(bus_name, received_params[1]) --name
                    assert.equals('', received_params[2]) -- old owner
                    assert.is_string(received_params[3]) -- new owner
             end)

             b.it("errors when connecting to an invalid signal", function ()
                    local proxy = Proxy:new(
                      {
                        bus = Bus.SESSION,
                        name = "org.freedesktop.DBus",
                        path= "/org/freedesktop/DBus",
                        interface = "org.freedesktop.DBus"
                      }
                    )

                    assert.has_error(
                      function ()
                        proxy:connect_signal(function()
                                             end, "NotValid")
                      end,
                      "Invalid signal: NotValid")

             end)
end)
