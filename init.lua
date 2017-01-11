timer_started = nil
blink_level = gpio.LOW
LED = nil
leds = nil
collectgarbage()

print("Heap:(bytes)", node.heap())

function blinky()
  if blink_level == gpio.LOW then
    blink_level = gpio.HIGH
  else
    blink_level = gpio.LOW
  end
  
  for _, led in pairs(leds) do
    led.value.set(led.id)
  end
  collectgarbage()
end

function startup()
  print("in startup")

  local wifiname = "wifi.lua"
  local wifiapmode = false
  if file.list()[wifiname] then
	if not pcall(dofile, wifiname) then
      print("could not dofile " ..wifiname)
	  wifiapmode = true
	end
  else
    print("could not find " ..wifiname)
	wifiapmode = true
  end
  if wifiapmode then
    local wificonfig = { ssid="NodeMCU", pwd="Passwort" }
    local netconfig = { ip="192.168.1.1", netmask="255.255.255.0", gateway="192.168.1.1" }

	print("Open Wifi access point " ..wificonfig.ssid.. " / " ..wificonfig.pwd)
    wifi.setmode(wifi.SOFTAP)
    wifi.ap.config(wificonfig)
	wifi.ap.setip(netconfig)
	print("Network IP " ..netconfig.ip.. " / " ..netconfig.netmask)
  end
  
  timer_started=false
  LED = {
    ON =   { key="ON", set=function(id)
      if pcall(gpio.write, id, gpio.LOW) then
        return true
      else
        print("ERROR: on call gpio.write(" .. id .. ", " .. gpio.LOW .. ")")
        return false
      end
    end
    },
    OFF =  { key="OFF", set=function(id)
      if pcall(gpio.write, id, gpio.HIGH) then
        return true
      else
        print("ERROR: on call gpio.write(" .. id .. ", " .. gpio.HIGH .. ")")
        return false
      end
    end
    },
    BLINK= { key="BLINK", set=function(id)
      if pcall(gpio.write, id, blink_level) then
        return true
      else
        print("ERROR: on call gpio.write(" .. id .. ", " .. blink_level .. ")")
        return false
      end
    end
    }
  }

  leds = {
    GPIO0 =  { id=0,  value=LED.OFF },
    GPIO2 =  { id=4,  value=LED.OFF },
    RED =    { id=1,  value=LED.OFF },
    YELLOW = { id=2,  value=LED.OFF },
    GREEN =  { id=3,  value=LED.OFF }
  }

  for _, led in pairs(leds) do
    if not pcall(gpio.mode, led.id, gpio.OUTPUT)then
      print("ERROR: on call gpio.mode(" .. led.id .. ", " .. gpio.OUTPUT .. ")")
    end
    led.value.set(led.id)
  end
  
  srv=net.createServer(net.TCP)
  srv:listen(80,function(conn)
    conn:on("receive", function(client,request)
      print("in receive")
  
      local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP")
      if(method == nil)then
        _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP")
      end
      local _GET = {}
      if (vars ~= nil)then
        for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
          _GET[k] = v
        end
      end
      local buf = "<h1> ESP8266 Web Server</h1>"
      for k, _ in pairs(leds) do
        buf = buf .. "<p>" .. k .. " "
        buf = buf .. "<a href=\"?led=" .. k .. "&state=" .. LED.ON.key .. "\"><button>ON</button></a>&nbsp;"
        buf = buf .. "<a href=\"?led=" .. k .. "&state=" .. LED.OFF.key .. "\"><button>OFF</button></a>&nbsp;"
        buf = buf .. "<a href=\"?led=" .. k .. "&state=" .. LED.BLINK.key .. "\"><button>BLINK</button></a></p>"
      end
	  
      local pin = _GET.led and leds[_GET.led]
      local state = _GET.state and LED[_GET.state]
	  	  
      if(pin and state)then
        print("pin:", pin.id)
        print("state:", state.key)
	  
	    pin.value = state
        pin.value.set(pin.id)
  	    timer_started = timer_started or tmr.alarm(1, 500, tmr.ALARM_AUTO, blinky)
      else
        print("invalid pin:", pin)
        print("invalid state:", state)
      end
  
      client:send(buf)
      client:close()
      collectgarbage()
    end)
  end)
end

tmr.alarm(0, 5000, tmr.ALARM_SINGLE, startup)
