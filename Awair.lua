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

_APP = {version = "v0.1", name = "Awair", logLevel = "debug"}
APP2DEV = {AwairTemperature = {}, AwairMultilevelSensor = {}, AwairHumiditySensor = {}}
APP2DEV = {
  AwairTemperature = {temp = {}},
  AwairMultilevelSensor = {co2 = {}, voc = {}, pm25 = {}, score = {}},
  AwairHumiditySensor = {humid = {}}
}
DEV2APP = {}
unitMap = {co2 = "ppm", voc = "ppm", pm25 = "㎍/㎥", score = ""}

-- Base class method new
local function newAwair(ip, interval)
  local self = {}
  local aInt = nil
  local URL = string.format("http://%s/air-data/latest", ip)
  local INTERVAL = interval * 1000
  function post(ev, t) awairLoopKey = setTimeout(function() events(ev) end, t or 0) end
  function httpCall(sucess, error)
    url = URL
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
  function events(e)
    ({
        ["polling"] = function(e)
          httpCall("success", "error")
        end,
        ["success"] = function(e)
          local data = json.decode(e.value.data)
          for lclass, devices in pairs(APP2DEV) do
            for name, dev in pairs(devices) do
              if APP2DEV[lclass][name].device.properties.value ~= data[name] then
                APP2DEV[lclass][name].device:setValue(data[name])
              end
            end
          end
          quickSelf:updateProperty("log", os.date("%m-%d %X"))
          post({type = "polling"}, INTERVAL)
          errs = 0
        end,
        ["error"] = function(e)
          Logger(LOG.error, "ERROR: %s", json.encode(e))
          quickSelf:updateProperty("log", json.encode(e))
          errs = errs + 1
          if errs > 3 then
            self:turnOff()
          end
          post({type = "polling"}, errs * INTERVAL)
        end
        })[e.type](e)
  end

  function self.start()
    Logger(LOG.debug, "---- START Awair ----")
    post({type = "polling"})
  end
  function self.stop()
    Logger(LOG.debug, "---- STOP Awair ----")
    if awairLoopKey ~= nil then
      clearTimeout(awairLoopKey)
      awairLoopKey = nil
    end
  end

  return self
end

function QuickApp:installChildDevice()
  self:initChildDevices(
    {
      ["com.fibaro.temperatureSensor"] = AwairTemperature,
      ["com.fibaro.multilevelSensor"] = AwairMultilevelSensor,
      ["com.fibaro.humiditySensor"] = AwairHumiditySensor
    }
  )
  local isSaveLogs = self.properties.saveLogs
  self.childDevices = self.childDevices or {}
  --set APP2DEV, DEV2APP
  Logger(LOG.sys, "---- set APP2DEV, DEV2APP ----")
  local cdevs = api.get("/devices?parentId=" .. plugin.mainDeviceId) or {}
  for _, cd in ipairs(cdevs) do
    local lClass, name = cd.properties.userDescription:match("([%w]+):(%w+)")
    if APP2DEV[lClass][name] ~= nil then
      APP2DEV[lClass][name].deviceId = cd.id
      APP2DEV[lClass][name].device = self.childDevices[cd.id]
      DEV2APP[cd.id] = {type = lClass, name = name}
    end
  end
  Logger(LOG.sys, "-----------------------")

  Logger(LOG.sys, "---- create device ----")
  for lClass, devices in pairs(APP2DEV) do
    for name, device in pairs(devices) do
      if APP2DEV[lClass][name].deviceId == nil then
        Logger(LOG.debug, "created device - %s", name)
        APP2DEV[lClass][name].device = createChild[lClass](lClass, name)
        APP2DEV[lClass][name].deviceId = APP2DEV[lClass][name].device.id
        DEV2APP[APP2DEV[lclass][name].device.id] = {type = lClass, name = name}
      end
      APP2DEV[lClass][name].device.properties.saveLogs = isSaveLogs    
    end
  end
  Logger(LOG.sys, "-----------------------")

  Logger(LOG.sys, "---- remove device ----")
  local cdevs = api.get("/devices?parentId=" .. plugin.mainDeviceId) or {}
  for _, cd in ipairs(cdevs) do
    local lClass, name = cd.properties.userDescription:match("([%w]+):(%w+)")
    if APP2DEV[lClass][name] == nil then
      plugin.deleteDevice(cd.id)
      Logger(LOG.sys, "removed device - %s", name)
    end
  end
  Logger(LOG.sys, "-----------------------")

  Logger(LOG.sys, "---- child device ----")
  for lclass, devices in pairs(APP2DEV) do
    for name, dev in pairs(devices) do
      Logger(LOG.sys, "[%s] Class: %s, DeviceId: %s ", name, lclass, dev.deviceId)
    end
  end
  Logger(LOG.sys, "-----------------------")
end

--[[ 
  Children 
]]
class "AwairTemperature"(QuickAppChild)
class "AwairMultilevelSensor"(QuickAppChild)
class "AwairHumiditySensor"(QuickAppChild)
createChild = {
  ["AwairTemperature"] = function(tp, nm)
    return quickSelf:createChildDevice(
      {
        name = string.format("%s_%s", _APP.name, nm),
        type = "com.fibaro.temperatureSensor",
        initialProperties = {
          userDescription = string.format("%s:%s", tp, nm)
        }
      },
      AwairTemperature
    )
  end,
  ["AwairMultilevelSensor"] = function(tp, nm)
    return quickSelf:createChildDevice(
      {
        name = string.format("%s_%s", _APP.name, nm),
        type = "com.fibaro.multilevelSensor",
        initialProperties = {
          userDescription = string.format("%s:%s", tp, nm),
          unit = unitMap[nm] or ""
        }
      },
      AwairMultilevelSensor
    )
  end,
  ["AwairHumiditySensor"] = function(tp, nm)
    return quickSelf:createChildDevice(
      {
        name = string.format("%s_%s", _APP.name, nm),
        type = "com.fibaro.humiditySensor",
        initialProperties = {
          userDescription = string.format("%s:%s", tp, nm)
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

function AwairMultilevelSensor:__init(device)
  QuickAppChild.__init(self, device)
end
function AwairMultilevelSensor:setValue(value)
  self:updateProperty("value", value)
end

function AwairHumiditySensor:__init(device)
  QuickAppChild.__init(self, device)
end
function AwairHumiditySensor:setValue(value)
  self:updateProperty("value", value)
end

function QuickApp:onInit()
  Utilities(self)
  quickSelf = self
  if self:getVariable("AWAIR_IP") == "" or self:getVariable("AWAIR_IP") == nil then
    self:setVariable("AWAIR_IP", "127.0.0.1")
    Logger(LOG.warning, "check variable: AWAIR_IP")
  end
  if self:getVariable("AWAIR_INTERVAL") == "" or self:getVariable("AWAIR_INTERVAL") == nil then
    self:setVariable("AWAIR_INTERVAL", "300")
    Logger(LOG.warning, "check variable: AWAIR_INTERVAL (seconds)")
  end
  local AWAIR_IP = self:getVariable("AWAIR_IP")
  local AWAIR_INTERVAL = self:getVariable("AWAIR_INTERVAL")
  Logger(LOG.sys, "AWAIR_INTERVAL %s (s)", AWAIR_INTERVAL)
  self:installChildDevice()

  oAwiar = newAwair(AWAIR_IP, AWAIR_INTERVAL)
  self:turnOn()
end

function QuickApp:turnOn()
  self:updateProperty("value", true)
  oAwiar.start()
end
function QuickApp:turnOff()
  oAwiar.stop()
  self:updateProperty("value", false)
end
--[[
  Utilities 
]]
function Utilities()
  logLevel = {trace = 1, debug = 2, warning = 3, error = 4}
  LOG = {debug = "debug", warning = "warning", trace = "trace", error = "error", sys = "sys"}
  function Logger(tp, ...)
    if tp == "debug" then
      if logLevel[_APP.logLevel] <= logLevel.debug then
        quickSelf:debug(string.format(...))
      end
    elseif tp == "warning" then
      if logLevel[_APP.logLevel] <= logLevel.warning then
        quickSelf:warning(string.format(...))
      end
    elseif tp == "trace" then
      if logLevel[_APP.logLevel] <= logLevel.trace then
        quickSelf:trace(string.format(...))
      end
    elseif tp == "error" then
      if logLevel[_APP.logLevel] <= logLevel.error then
        quickSelf:error(string.format(...))
      end
    elseif tp == "sys" then
      quickSelf:debug("[SYS]" .. string.format(...))
    end
  end
  local oldtostring, oldformat = tostring, string.format -- redefine format and tostring
  tostring = function(o)
    if type(o) == "table" then
      if o.__tostring and type(o.__tostring) == "function" then
        return o.__tostring(o)
      else
        return json.encode(o)
      end
    else
      return oldtostring(o)
    end
  end
  string.format = function(...) -- New format that uses our tostring
    local args = {...}
    for i = 1, #args do
      if type(args[i]) == "table" then
        args[i] = tostring(args[i])
      end
    end
    return #args > 1 and oldformat(table.unpack(args)) or args[1]
  end
  format = string.format

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
