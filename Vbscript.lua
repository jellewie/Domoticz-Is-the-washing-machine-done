
 -- Is the washing macgine done? Version 2.0
 -- create a lookup table that matches a usage
 -- device to the accompanying switch
 --https://www.domoticz.com/forum/viewtopic.php?t=23798
 local USAGE_DEVICES = {
 	['SC-Wasdroger gebruik'] = 'Wasdroger',	-- You need to have a inline wall plug that measures energy,
 	['SC-Wasmachine gebruik'] = 'Wasmachine',  -- here you make the link between the energy device and the wall plug.
 }

 local USAGE_TimeOut = {
 	['Wasdroger'] = 6,							-- Here you define how long no power is used per device.
 	['Wasmachine'] = 6,							-- The period is in minutes. Adjust to your needs. Between every add a ",".
 }

 local USAGE_MaxWatt = {
 	['Wasdroger'] = 3,							-- Here you define the maximum amount of power a device uses when it is in standby.
 	['Wasmachine'] = 3,							-- Some devices uses a little amount of power. Test it and a slightly higher usage.
 }

 return {
 	logging = {
        level = domoticz.LOG_INFO, 				-- Uncomment to override the dzVents global logging setting
        marker = 'POW'
    },
    
    on = {
		timer = { 'every 5 minutes' },
        devices = {								-- Make sure that the devices are the same as above
            'SC-Wasdroger gebruik',
            'SC-Wasmachine gebruik',
 		},
 	},
 	data = { 									-- use exact device names to match USAGE_DEVICES
        ['CountDevices'] = {initial=0},
        ['SC-Wasdroger gebruik'] = { history = true, maxMinutes = 10 },
        ['SC-Wasmachine gebruik'] = { history = true, maxMinutes = 10 },
 	},

 	execute = function(domoticz, device)

        function status(machine)
			local usage = "SC-" .. machine.. " gebruik"                     -- name of physical power measuring device
            local standby = USAGE_MaxWatt[machine]                          -- threshold for standby 
            local timeout = USAGE_TimeOut[machine]                          -- amount of time the power consumption needs to be constant
            local switch = domoticz.devices(machine)                        -- the actual virtual switch that shows the status of the device
            local power_actual = domoticz.devices(usage).WhActual           -- the actual power consumption of the device
            local power_average = domoticz.data[usage].avg()                -- the average power consumption in the last 10 minutes
            local minutes = domoticz.devices(usage).lastUpdate.minutesAgo   -- the # minutes the power consumption is unchanjged
            domoticz.log("device   : " .. machine .. ', power: ' .. usage)
            domoticz.log('gebruik  : ' .. power_actual .. ', treshold: ' .. standby)
            domoticz.log('gemiddeld: ' .. power_average)
            domoticz.log('sinds    : ' .. minutes .. ', standby: ' .. timeout)
            domoticz.data[usage].add(power_actual)
            if (switch.active) then
                if power_actual > standby then                  -- Device is already on
                    return('Already on')
                end
         	    if (power_actual == 0) or (power_actual <= standby and 
         	        (power_average <= standby) or minutes > standby)  then
                    switch.switchOff()                          -- Device is off or on standby
                    domoticz.data[usage].reset()                -- Reset history
                    return('Off')
         		end
     		    return('Idle')
 			end
            if power_actual > standby then                      -- Device is active
                switch.switchOn()                               -- Turn the virtual switch on
                if domoticz.data['CountDevices'] == 0 then
                    domoticz.data['CountDevices'] =  1          -- Keep track off active devices
                end
                return('Switching On')                      
            end
            if power_average > 0 then                           -- Switch is off but average needs to be reset
    	        domoticz.data[usage].reset()                    -- Reset history
            end                
            return('Off')                                       -- Device is off
        end
        
        if (device.isTimer) then                                -- Then its a regular check
			domoticz.log("Monitoring " .. tostring(domoticz.data['CountDevices']) .. "  apparaten.")
		 	if (domoticz.data['CountDevices'] > 0) then         -- When one or more devices are on
				domoticz.log("Monitoring " .. tostring(domoticz.data['CountDevices']) .. "  apparaten.")
				domoticz.data['CountDevices'] = 0               -- Reset count
     			for i, machine in pairs(USAGE_DEVICES) do       -- Loop thru all the devices
     			    checked = status(machine)                   -- Check the status of each device
                    domoticz.log('status: '..checked)           -- Check the status of each device
                    if checked ~= 'Off' then
                        domoticz.data['CountDevices'] = domoticz.data['CountDevices'] + 1   -- Keep track off active devices
                    end
     			end
			end
     	elseif (USAGE_DEVICES[device.name] ~= nil) then         -- Then one device has a changed power consumption
            domoticz.log('status: '..status(USAGE_DEVICES[device.name]))    -- Check the status of this one device
        end
 	end
 }
 