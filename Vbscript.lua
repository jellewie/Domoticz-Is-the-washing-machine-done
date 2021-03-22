--"Is the washing machine done?"
--Code Tweaked by JelleWho https://github.com/jellewie/Domoticz-Is-the-washing-macgine-done--

local DEVICES = {
--█Change the below values to EXACTLY match the names set in Domoticz as device names
--Random    ,SwitchName  ,  MeterName        , TimeOut, StandbyMaxWatt
	['a'] = {'Wasmachine', 'Wasmachine usage', 5      , 4},
	['b'] = {'Wasdroger' , 'Wasdroger usage' , 5      , 1},
	--['c'] = {'3D_Printer', '3D_Printer usage', 5      , 12},							--Another example
	--Also add these names to "data = {" in the format of "['SwitchName'] = {history = true, maxMinutes = 10}," !
}

local LogDebugging = false																--Set to TRUE to receive more information in the log, this includes most values of each status check
local LogChecking = true																--Set to TRUE to log what the result of the check was (machine was on/off/idle etc)

return {
	logging = {
		--level = domoticz.LOG_INFO, 													--█Uncomment to override the dzVents global logging setting
		marker = 'POW'
	},
	on = {
		timer = {'every 1 minutes'},													--█Every x, call the 'execute' function with 'devices' variable listed below
	},
	data = {
--█use exact SwitchName to match DEVICES
		['Wasmachine'] = {history = true, maxMinutes = 10},								--Log the values and store them here, remove all data after 10 min
		['Wasdroger']  = {history = true, maxMinutes = 10},
		--['3D_Printer'] = {history = true, maxMinutes = 10},
	},
--You can stop reading now, from here on out its just code
	execute = function(domoticz)
		function status(machine)
			local SwitchName		= machine[1]										-- name of physical power measuring device
			local MeterName			= machine[2]										-- name of physical power measuring device
			local TimeOut			= machine[3]+0										-- amount of time the power consumption needs to be constant
			local StandbyMaxWatt 	= machine[4]+0										-- threshold for standby 
			local Meter				= domoticz.devices(MeterName)
			local Switch			= domoticz.devices(SwitchName)
			local power_average		= domoticz.data[SwitchName].avg()+0					-- the average power consumption in the last 10 minutes
			--lastUpdate.minutesAgo = the time in minutes the device is unchanged
			--WhActual = the actual power consumption of the device

			if LogDebugging then
				domoticz.log(' - Switch name='..SwitchName..', Meter name='..MeterName)
				domoticz.log(' - Usage='..Meter.WhActual..', Treshold='..StandbyMaxWatt..', Average='..power_average)
				domoticz.log(' - Last read='..Meter.lastUpdate.minutesAgo..', Timout after='..TimeOut..', Last switch update='..Switch.lastUpdate.minutesAgo)
			end
			domoticz.data[SwitchName].add(Meter.WhActual)
			if (Switch.active) then
				if Meter.WhActual > StandbyMaxWatt then									--Device is already on
					return('Already on')
				end
				local Reason = ""
				if (Switch.lastUpdate.minutesAgo > TimeOut) then						--If the button has not changed for more than x minutes
					if (Meter.WhActual == 0) then
						Reason = "No ActPower"
					elseif (Meter.WhActual <= StandbyMaxWatt) then
						if (power_average <= StandbyMaxWatt) then
						    Reason = "ActPower<Standby & Poweravg<Standby"
						elseif (Meter.lastUpdate.minutesAgo > TimeOut) then
						    Reason = "ActPower<Standby & update TimeOut"
						end
					end
					if (Reason ~= "") then
						Switch.switchOff()												--Device is off or on standby
						domoticz.data[SwitchName].reset()								--Reset history
						return('Off: '..Reason)
					end
				end
			
				if (Switch.lastUpdate.minutesAgo <= TimeOut) then
					Reason = "Wait for Switch idle:"..tostring(TimeOut-Switch.lastUpdate.minutesAgo).."min"
				elseif(Meter.WhActual > StandbyMaxWatt) then
					if (power_average > StandbyMaxWatt) then
						Reason = "Wait for Poweravg<Standby OR TimeOut:"..tostring(Meter.WhActualo).."<"..tostring(StandbyMaxWatt).."W | "..tostring(Meter.lastUpdate.minutesAgo)..">"..tostring(TimeOut).."min"
					end
				end
				return('Idle: '..Reason)
			end
			--Note: switch is not active
			if Meter.WhActual > StandbyMaxWatt then										--Device is active 
				Switch.switchOn()														--Turn the virtual switch on
				return('Switching On: Act_Power>'..tostring(StandbyMaxWatt))
			end
			--Note: switch and machine are not active
			if power_average > 0 then 													--Switch is off but average is not reset
				domoticz.data[SwitchName].reset()										--Reset history (and the new average of NULL data is ofc 0)
			end 
			return('Off')																--Device is off
		end

		for i, machine in pairs(DEVICES) do 											--Loop thru all the devices
			checked = status(machine)													--Check the status of each device
			if LogChecking then domoticz.log('Status of '..machine[1]..'='..checked) end--Log the status of each device
		end
	end
}