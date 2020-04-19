--[[
    @file: Awair.lua (Awair.fqa)
    @author: SuSu Daddy (inganyoyo@me.com)
    @created date: 2020.04.16.
]]
if dofile then
    dofile("fibaroapiHC3.lua")
    local cr = loadfile("credentials.lua")
    if cr then
        cr()
    end
    require("mobdebug").coro()
end
--[[
    set awairChildDevice
]]
awairChildDevice = {}
awairChildDevice["Awair_temp"] = {["type"] = "AwairTemperature", ["unit"] = "℃"}
awairChildDevice["Awair_co2"] = {["type"] = "AwairMultilevelSensor", ["unit"] = "ppm"}
awairChildDevice["Awair_voc"] = {["type"] = "AwairMultilevelSensor", ["unit"] = "ppm"}
awairChildDevice["Awair_pm25"] = {["type"] = "AwairMultilevelSensor", ["unit"] = "㎍/㎥"}
awairChildDevice["Awair_score"] = {["type"] = "AwairMultilevelSensor", ["unit"] = ""}
awairChildDevice["Awair_humid"] = {["type"] = "AwairHumiditySensor", ["unit"] = "%"}
AWAIR_IP = nil
AWAIR_INTERVAL = nil

--[[
  Parent Device 
]]
awairLoopKey = nil
errs = 0
function QuickApp:turnOn()
    self:updateProperty("value", true)
    post({type = "polling"})
end
function QuickApp:turnOff()
    self:updateProperty("value", false)
    clearTimeout(awairLoopKey)
    awairLoopKey = nil
end

function post(ev, t)
    awairLoopKey =
        setTimeout(
        function()
            event(ev)
        end,
        t or 0
    )
end
function httpCall(sucess, error)
    url = "http://" .. AWAIR_IP .. "/air-data/latest"
    net.HTTPClient():request(
        url,
        {
            success = function(resp)
                post({type = sucess, value = resp})
            end,
            error = function(resp)
                post({type = error, value = resp})
            end,
            options = {
                method = "GET"
            }
        }
    )
end

function event(e)
    ({
        ["polling"] = function(e)
            httpCall("success", "error")
        end,
        ["success"] = function(e)
            local data = json.decode(e.value.data)
            for id, device in pairs(quickSelf.childDevices) do
                userDesc = nil
                if dofile then
                  userDesc = api.get("/devices/"..id).properties.userDescription
                else
                  userDesc = device.properties.userDescription
                end
                
                awairChildDevice[userDesc].value =
                    data[split(userDesc, "_")[2]]
                device:setData(json.encode(awairChildDevice[userDesc]))
            end
            quickSelf:updateProperty("log", os.date("%m-%d %X"))
            post({type = "polling"}, AWAIR_INTERVAL * 1000)
            errs = 0
        end,
        ["error"] = function(e)
            Logging(LOG.error, "ERROR: %s", json.encode(e))
            quickSelf:updateProperty("log", json.encode(e))
            errs = errs + 1
            if errs > 3 then
                self:turnOff()
            end
            post({type = "polling"}, errs * AWAIR_INTERVAL * 1000)
        end
    })[e.type](e)
end

function QuickApp:installChildDevice()
    self:initChildDevices(
        {
            ["com.fibaro.temperatureSensor"] = AwairTemperature,
            ["com.fibaro.multilevelSensor"] = AwairMultilevelSensor,
            ["com.fibaro.humiditySensor"] = AwairHumiditySensor
        }
    )
    -- set device Id
    for id, device in pairs(self.childDevices) do
        userDesc = nil
        if dofile then
          userDesc = api.get("/devices/"..id).properties.userDescription
        else
          userDesc = device.properties.userDescription
        end
        if awairChildDevice[userDesc] ~= nil then
            awairChildDevice[userDesc].deviceId = id
        end
    end

    Logging(LOG.debug, "---- create device ----")
    for name, deviceInfo in pairs(awairChildDevice) do
        if self.childDevices[deviceInfo.deviceId] == nil then
            createChild[deviceInfo.type](name)
        end
    end
    Logging(LOG.debug, "-----------------------")

    Logging(LOG.debug, "---- remove device ----")
    for id, device in pairs(self.childDevices) do
        userDesc = nil
        if dofile then
          userDesc = api.get("/devices/"..id).properties.userDescription
        else
          userDesc = device.properties.userDescription
        end
        if awairChildDevice[userDesc] == nil then
            Logging(LOG.debug, userDesc)
            plugin.deleteDevice(id)
        end
    end
    Logging(LOG.debug, "-----------------------")

    Logging(LOG.debug, "---- child device ----")
    for id, device in pairs(self.childDevices) do
        Logging(LOG.debug, "[%s]: %s", id, device.name)
    end
    Logging(LOG.debug, "-----------------------")
end

--[[ 
  Children 
]]
class "AwairTemperature"(QuickAppChild)
class "AwairMultilevelSensor"(QuickAppChild)
class "AwairHumiditySensor"(QuickAppChild)
createChild = {
    ["AwairTemperature"] = function(name)
        return quickSelf:createChildDevice(
            {
                name = name,
                type = "com.fibaro.temperatureSensor",
                initialProperties = {
                    userDescription = name
                }
            },
            AwairTemperature
        )
    end,
    ["AwairMultilevelSensor"] = function(name)
        return quickSelf:createChildDevice(
            {
                name = name,
                type = "com.fibaro.multilevelSensor",
                initialProperties = {
                    userDescription = name
                }
            },
            AwairMultilevelSensor
        )
    end,
    ["AwairHumiditySensor"] = function(name)
        return quickSelf:createChildDevice(
            {
                name = name,
                type = "com.fibaro.humiditySensor",
                initialProperties = {
                    userDescription = name
                }
            },
            AwairHumiditySensor
        )
    end
}

--[[
  function of children
]]
function AwairTemperature:__init(device)
    QuickAppChild.__init(self, device)
end
function AwairTemperature:setValue(value)
    self:updateProperty("value", value)
end
function AwairTemperature:setData(deviceInfo)
    data = json.decode(deviceInfo)
    self:updateProperty("unit", data.unit)
    self:updateProperty("value", data.value)
end

function AwairMultilevelSensor:__init(device)
    QuickAppChild.__init(self, device)
end
function AwairMultilevelSensor:setValue(value)
    self:updateProperty("value", value)
end
function AwairMultilevelSensor:setData(deviceInfo)
    data = json.decode(deviceInfo)
    self:updateProperty("unit", data.unit)
    self:updateProperty("value", data.value)
end
function AwairHumiditySensor:__init(device)
    QuickAppChild.__init(self, device)
end
function AwairHumiditySensor:setValue(value)
    self:updateProperty("value", value)
end
function AwairHumiditySensor:setData(deviceInfo)
    data = json.decode(deviceInfo)
    self:updateProperty("unit", data.unit)
    self:updateProperty("value", data.value)
end
function QuickApp:onInit()
    Utilities(self)
    quickSelf = self
    if self:getVariable("AWAIR_IP") == "" or self:getVariable("AWAIR_IP")  == nil then 
      self:setVariable("AWAIR_IP","127.0.0.1")
      Logging(LOG.warning, "check variable: AWAIR_IP")
    end
    if self:getVariable("AWAIR_INTERVAL") == "" or self:getVariable("AWAIR_INTERVAL")  == nil then
      self:setVariable("AWAIR_INTERVAL", "300")
      Logging(LOG.warning, "check variable: AWAIR_INTERVAL (seconds)")
    end
    if not checkVariable then
      return
    end
    AWAIR_IP = self:getVariable("AWAIR_IP")
    AWAIR_INTERVAL = self:getVariable("AWAIR_INTERVAL")
    Logging(LOG.debug, "AWAIR_INTERVAL %s (s)", AWAIR_INTERVAL)
    self:installChildDevice()
    self:turnOn()
end

--[[
  Utilities 
]]
function Utilities()
    logFlag = {debug = true, warning = true, trace = true, error = true}
    LOG = {debug = "debug", warning = "warning", trace = "trace", error = "error"}
    function Logging(tp, ...)
        if tp == "debug" then
            if logFlag.debug then
                quickSelf:debug(string.format(...))
            end
        elseif tp == "warning" then
            if logFlag.warning then
                quickSelf:warning(string.format(...))
            end
        elseif tp == "trace" then
            if logFlag.trace then
                quickSelf:trace(string.format(...))
            end
        elseif tp == "error" then
            if logFlag.error then
                quickSelf:error(string.format(...))
            end
        end
    end
    function split(s, sep)
        local fields = {}
        sep = sep or " "
        local pattern = string.format("([^%s]+)", sep)
        string.gsub(
            s,
            pattern,
            function(c)
                fields[#fields + 1] = c
            end
        )
        return fields
    end
end

if dofile then
    hc3_emulator.start {
        --id = 249,
        name = "Awair", -- Name of QA
        type = "com.fibaro.binarySwitch",
        proxy = true,
        poll = 2000 -- Poll HC3 for triggers every 2000ms
    }
    hc3_emulator.offline = true
end
