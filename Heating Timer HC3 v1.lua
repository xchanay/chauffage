{
    conditions = {
      {
        type = "se-start",
        property = "start",
        operator = "==",
        value = true,
        isTrigger = true
      }
    },
    operator = "all",
}


-- Scene used to toggle a Global Variable CHECKTEMP from 0 to 1 every n seconds (n defined in the
-- local variable "PeriodCheckTemp") and to update the display of the heating system controller QuickApps every PeriodUpdateDisplay

local debug = true

local sourceTrigger = 0
local PeriodCheckTemp = 300	-- time in seconds between 2 temperatures reading; must be a multiple of PeriodUpdateDisplay
local PeriodUpdateDisplay = 30	-- time in seconds between 2 updates of the displays of the QuickApps
local CheckTempVariable = 0
local NumberOfUpdateDisplay = 1
local TempTargetTVD = 0	
local TargetAutoChange = false	


function tempFunc()

	if debug then
        fibaro.debug ('HeatingTimer', 'Beggining of function tempFunc')
    end
	if NumberOfUpdateDisplay >= PeriodCheckTemp/PeriodUpdateDisplay then
		if debug then
			fibaro.debug ('HeatingTimer', 'Il vient de s ecouler '..PeriodCheckTemp..' seconds. CheckTempVariable = '..CheckTempVariable)
        end
        CheckTempVariable = tonumber(fibaro.getGlobalVariable('CHECKTEMP'))
		if CheckTempVariable == 0 then
			CheckTempVariable = 1
		else
			CheckTempVariable = 0
		end
		fibaro.setGlobalVariable("CHECKTEMP", tostring(CheckTempVariable))
		NumberOfUpdateDisplay = 0
		if debug then
			fibaro.debug ('HeatingTimer', 'CHECKTEMP toggled')
		end
	end
	NumberOfUpdateDisplay = NumberOfUpdateDisplay + 1
	
	local HT = fibaro.getGlobalVariable('HEATING_TABLE')
    	local HeatingTable = json.decode(HT)
	local WT = fibaro.getGlobalVariable('WEEKLY_TARGET')
	local WeeklyTarget = json.decode(WT)

	local DateTime = os.date("*t", os.time())
	local Day = ((DateTime.wday + 5) % 7)+1	-- changes the day number Sunday = 1 to Sunday = 7
	local Time = (DateTime.hour * 60) + DateTime.min
	if debug then
		fibaro.debug('HeatingTimer','Day = ' .. Day .. '; Time in minute = ' .. Time .. '; Hour = ' .. DateTime.hour .. '; Minutes = ' .. DateTime.min)
	end

	local room, roomTable = next(HeatingTable, nil)	
	if debug then
		fibaro.debug('HeatingTimer', 'Updating all displays and checking a change of TargetAuto for rooms managed by a virtual thermostat')
	end
	TargetAutoChange = false
	while room do
		if tonumber(roomTable.QAId) ~= 0 then
            if debug then
			    fibaro.debug('HeatingTimer', 'Updating display in room '..roomTable.RoomName..'  QAId = '..roomTable.QAId)
		    end
		    fibaro.call(tonumber(roomTable.QAId),"updateDisplay","0")
        end
		if not roomTable.Thermostat then	-- room managed by the virtual thermostat? Checking if there is a change of TargetAuto
							
			TempTargetTVD = roomTable.TargetTVD	-- this is the last temperature target provided by this virtual thermostat for this room
	        if debug then
                fibaro.debug('HeatingTimer', 'room = '..room..'  TempTargetTVD = '..TempTargetTVD)
            end
			if Time < WeeklyTarget[room][Day][1].Time then	-- computes the new temp target for this room 
				NewTempTarget = WeeklyTarget[room][((Day + 5) % 7) + 1][4].Target
			else
				NewTempTarget = WeeklyTarget[room][Day][4].Target
				for j = 1, 3 do
					if Time >= WeeklyTarget[room][Day][j].Time then
						if Time < WeeklyTarget[room][Day][j+1].Time then
							NewTempTarget = WeeklyTarget[room][Day][j].Target
						end
					end
				end
			end
			if debug then
				fibaro.debug('HeatingTimer', 'NewTempTarget = '..NewTempTarget..'  TempTargetTVD = '..TempTargetTVD)
			end
			if NewTempTarget ~= TempTargetTVD then	-- if different from the previous one, update it and update TargetAuto
                if debug then
                    fibaro.debug('HeatingTimer', 'Change of Temp Target')
                end
				TargetAutoChange = true
				roomTable.TargetTVD = NewTempTarget
				roomTable.TargetAuto = NewTempTarget	-- no modification of HEATING_TRIGGER. Adjustment will be done at next CHECKTEMP change
            end			
		end

		room, roomTable = next(HeatingTable, room)
	end
	if TargetAutoChange then			-- if at least 1 TargetAuto change detected, update HEATING_TABLE
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
	end
    if debug then
        fibaro.debug('HeatingTimer', 'End of function tempFunc')
    end
	fibaro.setTimeout(PeriodUpdateDisplay*1000, tempFunc)

end		-- end tempFunc

-------------------------------------------- début de la scene ---------------------------

if debug then	
	fibaro.debug('HeatingTimer', 'Launching Heating Timer')
end

local data, status = api.get('/globalVariables/CHECKTEMP')
if debug then
	fibaro.debug('HeatingTimer','CHECKTEMP status = '..status..'  data = '..json.encode(data))
end
if status ~= 200 then
	if debug then
		fibaro.debug('HeatingTimer','No CHECKTEMP global variable. Creating it first.')
	end
	local requestData = {
		name = 'CHECKTEMP',
		isEnum = false,
		readOnly = false,
		value = '0'
	}
	local responseData, status = api.post('/globalVariables', requestData)
	if debug then
		fibaro.debug('HeatingTimer','CHECKTEMP created. Status = '..status..'  responseData = '..json.encode(responseData))
	end
else
	if debug then
		fibaro.debug('HeatingTimer','CHECKTEMP global variable exists.')
	end
end
tempFunc()