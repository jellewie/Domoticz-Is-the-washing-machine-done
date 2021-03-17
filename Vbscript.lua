--"Is the washing machine done?"
--	Version 2.0 https://www.domoticz.com/forum/viewtopic.php?t=23798
--	Version 3.0 Tweaked by JelleWho https://github.com/jellewie
--TLDR: You need a smart Switch to turn a device off/on, AND you need a smart kWh measureing device, to setup read intresting lines with █ in them

--This script checks if a switch has been turned on, or the device is using more power than 'StandbyMaxWatt'
--'TimeOut' minutes after the switch (and the device) has been turned on, the code start to check if the machine is done
--If the switch is turned off, or the device uses 0Watt, or it uses less than 'StandbyMaxWatt' average over 'TimeOut' minutes, The Switch (and the device) is turned off
--This is usefull so you can attach a notification when the switch turns off (and thus when the device is done), This is extreemly usefull for washing machines, dryers, and 3D printers for example

local DEVICES = {
--█Change the below values to EXACTLY match the names set in Domoticz as device names
    --Random,  SwitchName,  MeterName             , TimeOut, StandbyMaxWatt
	['a'] = {'Wasdroger' , 'SC-Wasdroger gebruik' , 5      , 1},
	['b'] = {'Wasmachine', 'SC-Wasmachine gebruik', 5      , 4},
	--['c'] = {'3D_Printer', 'SC-3D_Printer gebruik', 5      , 12},					--Another example
	--Also add these names to "data = {" in the format of "['SwitchName'] = {history = true, maxMinutes = 10}," !
}

local LogDebugging = false						                                    --Set to TRUE to recieve more information in the log, This includes most values of each status check
local LogChecking = true						                                    --Set to TRUE to log what the result of the check was (machine was on/off/idle etc)

return {
	logging = {
		--level = domoticz.LOG_INFO, 								                --█Uncomment to override the dzVents global logging setting
		marker = 'POW'
	},
	on = {
		timer = {'every 1 minutes'},								                --█Every x, call the 'execute' function with 'devices' variable listed below
	},
	data = {
--█use exact SwitchName to match DEVICES
		['Wasdroger']  = {history = true, maxMinutes = 10},                         --Log the values and store them here, remove all data after 10 min
		['Wasmachine'] = {history = true, maxMinutes = 10},
		--['3D_Printer'] = {history = true, maxMinutes = 10},
	},
--You can stop reading now, from here on out its just code
	execute = function(domoticz)
		function status(machine)
			local DevSwitch      = machine[1]						                -- name of physical power measuring device
			local DevUsage       = machine[2]						                -- name of physical power measuring device
			local timeout        = machine[3]						                -- amount of time the power consumption needs to be constant
			local StandbyMaxWatt = machine[4]						                -- threshold for standby 
			local Meter          = domoticz.devices(DevUsage)
			local Switch         = domoticz.devices(DevSwitch)
			local power_average  = domoticz.data[DevSwitch].avg()                   -- the average power consumption in the last 10 minutes
			--lastUpdate.minutesAgo = the time in minutes the device is unchanged
			--WhActual = the actual power consumption of the device

			if LogDebugging then
				domoticz.log("	Switch name=" .. DevSwitch .. ', Meter name=' .. DevUsage)
				domoticz.log('	Usage=' .. Meter.WhActual .. ', Treshold=' .. StandbyMaxWatt .. ', Average=' .. power_average)
				domoticz.log('	Last read=' .. Meter.lastUpdate.minutesAgo .. ', Timout after=' .. timeout .. ', Last switch update=' .. Switch.lastUpdate.minutesAgo )
			end 
			domoticz.data[DevSwitch].add(Meter.WhActual)
			if (Switch.active) then
				if Meter.WhActual > StandbyMaxWatt then                             --Device is already on
					return('Already on')
				end
				local Reason = ""
				if (Switch.lastUpdate.minutesAgo > timeout) then                    --If the button has not changed for more than x minutes
					if (Meter.WhActual == 0) then
						Reason = "No ActPower"
					elseif (Meter.WhActual <= StandbyMaxWatt) then
						if (power_average <= StandbyMaxWatt) then
						    Reason = "ActPower<Standby & Poweravg<Standby"
						elseif (Meter.lastUpdate.minutesAgo > timeout) then
						    Reason = "ActPower<Standby & update timeout"
						end
					end
					if (Reason ~= "") then
						Switch.switchOff() 							                --Device is off or on standby
						domoticz.data[DevSwitch].reset()                            --Reset history
						return('Off: '..Reason)
					end
                end
			
				if (Switch.lastUpdate.minutesAgo <= timeout) then
					Reason = "Wait for Switch idle:"..tostring(timeout-Switch.lastUpdate.minutesAgo).."min"
				elseif(Meter.WhActual > StandbyMaxWatt) then
					if (power_average > StandbyMaxWatt) then
                        Reason = "Wait for Poweravg<Standby OR timeout:"..tostring(Meter.WhActualo).."<"..tostring(StandbyMaxWatt).."W | "..tostring(Meter.lastUpdate.minutesAgo)..">"..tostring(timeout).."min"
					end
				end
				return('Idle: '..Reason)
			end
			--Note: switch is not active
			if Meter.WhActual > StandbyMaxWatt then                                 --Device is active 
				Switch.switchOn()									                --Turn the virtual switch on
				return('Switching On: Act_Power>'..tostring(StandbyMaxWatt))
			end
			--Note: switch and machine are not active
			if power_average > 0 then 								                --Switch is off but average is not reseted
				domoticz.data[DevSwitch].reset()                                    --Reset history (and the new average of NULL data is ofc 0)
			end 
			return('Off')											                --Device is off
		end

		for i, machine in pairs(DEVICES) do 						                --Loop thru all the devices
			checked = status(machine)								                --Check the status of each device
			if LogChecking then domoticz.log('Status of '..machine[1]..'='..checked) end	--Log the status of each device
		end
	end
}
-- Some info about the DzVents language used here https://www.domoticz.com/wiki/DzVents:_next_generation_Lua_scripting