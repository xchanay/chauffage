--[[ Thermostat Virtual Device QA									v2 2023/11/21

Manages global variable called WEEKLY_TARGET and HEATING_TABLE and initializes the virtual device Id in HEATING_TABLE if the device is installed in a Room

WEEKLY_TARGET is a structure transformed into a string by the function json.encode with 4 dimensions
	- the room number to which the targets apply
	- the day number (1 to 7)
	- the period number (1 to 4 but can be changed)
		.Time: time for the target change
		.Target: target for this time

HEATING_TABLE is the following structure transformed into a string by function json.encode for each room:
		.Mode: contains 'Auto', 'Manual', 'Away' or 'Off'
		.FlamesManu: integer between 0 and 9. Flames height in 'Manual' mode
		.TargetAuto: temperature target in °C (decimal number)in 'Auto' mode
		.TargetTVD: temperature target in °C (decimal number)in 'Auto' mode set by the Virtual Thermostat
		.TargetAway: temperature target in °C (decimal number)in 'Away' mode
		.Flames: integer between 0 and 9. Flames height in 'Auto' or 'Away' modes
		.EndTimer: system time at which the timer of 'Manual' mode will end (in seconds)
		.LastTemp: last measured temperature in °C (decimal number)
		.PreviousMode: mode in which the system was before going to 'Manual'
		.MoveDetectorTimer: date/time of the end of the timer after a move detection
		
		.RoomName: name of the room ('LIVING', 'PARENTS'...)
		.SystemRoomNumber: number of the room in the HC2
		.HVDId: Id of the HVD Virtual device in the room
		.HeatingType: 'Fire' or 'Convector' or 'Inverter' or 'Fire-Inverter'
		.FlamesId: Id of the fire controller
		.PilotId: Id of device controlling the "fil pilote" of a convector
		.IRIdTemp1: Id of the Infra Red controller of the Inverter 1
		.IRIdMode1: Id of the Infra Red controller of the Inverter 1
		.IRIdTemp2: Id of the Infra Red controller of the Inverter 2. 0 if only 1 inverter in the room
		.IRIdMode2: Id of the Infra Red controller of the Inverter 2. 0 if only 1 inverter in the room
		.PreviousInverterMode: previous mode of the heating system in rooms with fire and inverter (can be 'Fire' or 'Inverter')
		.Thermometer: boolean true if there is a thermometer in the room
		.ThermometerId: Id of the thermometer if present
		.Thermostat: boolean true if there is a physical thermostat in the room (if there is a virtual thermostat, the value is "false"
		.ThermostatId: Id of the physical thermostat if present or of the virtual thermostat if not
		.VoiceActivation: boolean true if there is a voice activation device in the room
		.VoiceActivationId: Id of the voice activation device if present
		.MoveDetector: boolean true if there is a movement detector in the room
		.MoveDetectorId: Id of the move detector if there is one in the room 

RDPC: is a structure containing the following data 
	.PreviousRoom: the room selected after pressing twice in a row the Copy key
	.Room: the current room
	.Day: number the last selected day of the week (1: Monday; 2: Tuesday...)
	.Period: number of the last selected period (between 1 and 4)
	.Copy: 2 if "Copy" pressed twice in a row, 1 if "Copy" pressed once, 0 otherwise	

1: Monday; 2: Tuesday; 3: Wednesday; 4: Thursday; 5: Friday; 6: Saturday; 7: Sunday; 9: Copy
11: PeriodDown; 12: PeriodUp;
21: StartTimeFastDown; 22: StartTimeDown; 23: StartTimeUp; 24: StartTimeFastUp
31: TempFastDown; 32: TempDown; 33: Tempup; 34: TempFastUp

The device manages the temperature target setting for each period of each day.

To install the thermostat, run the Thermostat_Init scene and the Heating_Init scene first to create required global variables

After that, add the device. This is it.
--]]



-------------------------------------------------------------------------------------------------------------
----------------------- below variables can be adjusted if wished -------------------------------------------
-------------------------------------------------------------------------------------------------------------
local debug = true



-------------------------------------------------------------------------------------------------------------
---------------------------          no more customization below        -------------------------------------
-------------------------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------------------------------
------------------------------------------------------- Local Functions -------------------------------------------------
-------------------------------------------------------------------------------------------------------------------


--[[Function:  timeString = timeToString(minutes): converts a time expressed in minutes into a string in the format 'hh:mm'
--]]

function timeString(minutes)

	return string.format('%02d:%02d', math.floor(minutes / 60), minutes % 60)

end

--[[getNumberOfRooms(HeatingTable)
This function checks the number of rooms with a controlled heating system

Call: numberOfRooms = getNumberOfRooms(HeatingTable)
--]]

function getNumberOfRooms(HeatingTable)
local numberOfRooms = 0
local room, t = next(HeatingTable, nil)
while room do
	numberOfRooms = room
	room, t = next(HeatingTable, room)
end
return (numberOfRooms)
	
end -- of function getNumberOfRooms



--[[changeDisplay(fontColor, textToChange)
This function changes the text to be displayed in the color fontColor (needs to be hexadecimal in format string) and bold

Call: text = changeDisplay(fontColor, textToChange)
--]]

function changeDisplay(fontColor, textToChange)

	return (string.format("<b><span><font color=%s> %s </font></span>",fontColor, textToChange))
	
end

-------------------------------------------------------------------------------------------------------------------
--------------------------------------------------- End of local functions ----------------------------------------
-------------------------------------------------------------------------------------------------------------------

--[[Function:  QuickApp:updateFullDisplay(previousRoom, room, day, period, copy): update the full display of the virtual device
--]]


function QuickApp:updateFullDisplay(previousRoom, room, day, period, copy)

	local blackColor = "#000000"
	local redColor = "ff0000"
	local Temporary = fibaro.getGlobalVariable('HEATING_TABLE')
    local HT = json.decode(Temporary)
    Temporary = fibaro.getGlobalVariable('WEEKLY_TARGET')
	local WT = json.decode(Temporary)
	local Label = ' '
	
	
	self:updateView("PeriodNumber", "text", "Period "..period)
	if HT[room].Thermometer then
		self:updateView("Room", "text", HT[room].RoomName..' . . . . Target: '..HT[room].TargetTVD..'°C')
		self:updateView("PeriodNumberLabel", "text", changeDisplay(blackColor, WT[room][day][period].DayName..' . . Période . . ' .. period .. ' . . '..
					timeString(WT[room][day][period].Time)..' . . ' .. string.format('%.1f', WT[room][day][period].Target) .. 'ºC'))
		for periodNumber = 1, 4 do
			Label = 'Period'..periodNumber..'Label'
			self:updateView(Label, "text", changeDisplay(blackColor, 'After ' .. timeString(WT[room][day][periodNumber].Time) .. ' = '
											.. string.format('%.1f', WT[room][day][periodNumber].Target) .. 'ºC'))
		end			
	else
		self:updateView("Room", "text", HT[room].RoomName..' . . . . Target: '..HT[room].TargetTVD)
		self:updateView("PeriodNumberLabel", "text", changeDisplay(blackColor, WT[room][day][period].DayName..' . . Période . . ' .. period .. ' . . '..
					timeString(WT[room][day][period].Time)..' . . ' .. WT[room][day][period].Target))
		for periodNumber = 1, 4 do
			Label = 'Period'..periodNumber..'Label'
			self:updateView(Label, "text", changeDisplay(blackColor, 'After ' .. timeString(WT[room][day][periodNumber].Time) .. ' = '
											.. WT[room][day][periodNumber].Target))
		end
	end
	
	if copy == 1 then
		self:updateView("CopyLabel", "text", changeDisplay(redColor, '------ COPY ------ '..WT[room][day][period].DayName .. ' ------ '))
	elseif copy == 2 then
		self:updateView("CopyLabel", "text", changeDisplay(redColor, '------ COPY ------ '..HT[previousRoom].RoomName .. ' ------ '))
	else
		self:updateView("CopyLabel", "text", ' ')
	end
end	-- end of Function updateFullDisplay


---------------------------------------------------------------------------------------------------
------------------------------------ Function onInit  ---------------------------------------------
---------------------------------------------------------------------------------------------------

function QuickApp:onInit()

    local debug = true

	if debug then
		self:debug("onInit")
        self:debug('device Id = '..self.id)
    end
			
	local Refresh = 30	-- time to check if change of target temperature
	local DateTime = os.date("*t", os.time())
	local Room, NumberOfRooms = 0
	self.InARoom = false

	local Temporary = fibaro.getGlobalVariable('WEEKLY_TARGET')
	local WeeklyTarget = json.decode(Temporary)
	Temporary = fibaro.getGlobalVariable('RDPC')
	local RDPC = json.decode(Temporary)
	
	if debug then
		self:debug('WeeklyTarget = '..json.encode(WeeklyTarget))
		self:debug('RDPC = '..json.encode(RDPC))
	end

	--------------------- check if the virtual device is installed in a room or not
--[[	local SystemRoomNumber = fibaro.getRoomID(tonumber(self.id))
	NumberOfRooms = getNumberOfRooms(HeatingTable)
    self:debug('SystemRoomNumber = '..SystemRoomNumber)
	if SystemRoomNumber ~= 0 then	-- device installed in a room
		Room = 1
		while Room <= NumberOfRooms and HeatingTable[Room].SystemRoomNumber - SystemRoomNumber ~= 0 do
			Room = Room + 1
		end
		if HeatingTable[Room].SystemRoomNumber - SystemRoomNumber == 0 then
			self:debug('Device installed in room '..HeatingTable[Room].RoomName)
			self.InARoom = true
			self.DeviceRoom = Room
			HeatingTable[self.DeviceRoom].ThermostatId = self.id
			fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
		end
	end
]]--
    if debug then
        self:debug('End of function OnInit')
    end
end		-- ------------------------------end function onInit ------------------------------------------


--------------------------------------------------------------------------------------------------------
------------------------------------------- Function sendKey -------------------------------------------
--------------------------------------------------------------------------------------------------------

function QuickApp:sendKey(key)

----------------------- below variables can be adjusted if wished -------------------------------------------

local debug = true

local TEMP_STEP = 0.5		-- increment step of target temperature
local TEMP_FAST_STEP = 1.0	-- fast increment step of target temperature

local TEMP_TARGET_MAX = 26
local TEMP_TARGET_MIN = 10

local START_TIME_STEP = 5		-- increment step in minutes of the start time of the period
local START_TIME_FAST_STEP = 30	-- fast increment step in minutes of the start time of the period



-------------------------------------------------------------------------------------------------------------
---------------------------          no more customization below        -------------------------------------
-------------------------------------------------------------------------------------------------------------

	if debug then 
		self:debug('Start of function sendKey')
		self:debug("Function sendKey. Key = "..json.encode(key))
		self:debug("Function sendKey. DeviceID = "..key.deviceId)
	end

	local Temporary = fibaro.getGlobalVariable('HEATING_TABLE')
    local HeatingTable = json.decode(Temporary)
    Temporary = fibaro.getGlobalVariable('RDPC')
	local RDPC = json.decode(Temporary)

	local NumberOfRooms = getNumberOfRooms(HeatingTable)

	local Room = 0
	if self.InARoom then
		Room = self.DeviceRoom
	else
		Room = RDPC.Room
	end
    if RDPC.PreviousRoom == 0 then
        RDPC.PreviousRoom = Room
        fibaro.setGlobalVariable('RDPC', json.encode(RDPC))
        if debug then
            self:debug("RDPC.PreviousRoom was at 0; modified to "..Room)
        end
    end

	local RoomName = HeatingTable[Room].RoomName
	
	local Key = tonumber(key.elementName)

	if debug then
		if self.InARoom then	
			self:debug('Scene launched from a VD installed in room: '..RoomName)
		end
		self:debug('PR = '..RDPC.PreviousRoom..'  Room = '..Room..'  Day = '..RDPC.Day..'  Period = '..RDPC.Period..'  Copy = '..RDPC.Copy)
	end

    Temporary = fibaro.getGlobalVariable('WEEKLY_TARGET')
	local WeeklyTarget = json.decode(Temporary)

	local StartTime, Limit = 0

	if debug then
		self:debug('Key = ' .. Key .. ', Room number = ' .. Room .. ', Room name = ' .. RoomName .. '.')
		self:debug('Copy: ' .. RDPC.Copy .. ' ; Period: ' .. RDPC.Period .. ' ; Day: ' .. RDPC.Day..'  Previous room number = '..RDPC.PreviousRoom)
	end


	-----------------------------------------------Day key---------------------------------------------

	if (Key <= 7) then		-- the key pressed is a week day; check if a copy is requested or display the data for this day
	 
		if debug then self:debug('Day key: ' .. Key .. ' pressed.')
		end
	  
		if RDPC.Copy == 1 then		-- copy requested
			if debug then self:debug('Copy requested')
			end
			for period = 1, 4 do	-- copy data from WeeklyTarget[Day] to WeeklyTarget[Key]
				WeeklyTarget[Room][Key][period].Time = WeeklyTarget[Room][RDPC.Day][period].Time
				WeeklyTarget[Room][Key][period].Target = WeeklyTarget[Room][RDPC.Day][period].Target
			end
			RDPC.Copy = 0	-- reset 'Copy' to 0
			fibaro.setGlobalVariable('WEEKLY_TARGET', json.encode(WeeklyTarget))
		end
		
		self:updateFullDisplay(RDPC.PreviousRoom, Room, Key, RDPC.Period, RDPC.Copy)
		
		RDPC.Day = Key
		fibaro.setGlobalVariable('RDPC', json.encode(RDPC))

	-----------------------------------------------Copy key---------------------------------------------	

	elseif (Key == 9) then		-- the key pressed is "Copy"
		if debug then self:debug('Copy pressed')
		end
		
		if not InARoom then
			if RDPC.Copy == 2 then	-- requesting the copy of a full room (PreviousRoom) into the new room (Room)
				if debug then self:debug('Copying Room '..RDPC.PreviousRoom..' to Room '..Room)
				end
				if HeatingTable[Room].Thermometer then
					if HeatingTable[RDPC.PreviousRoom].Thermometer then	-- both Room and PreviousRoom have a thermometer: copy values
						if debug then self:debug("Both Room and PreviousRoom have a Thermometer: copy")
						end
						for i = 1, 7 do
							for j = 1, 4 do
								WeeklyTarget[Room][i][j].Time = WeeklyTarget[RDPC.PreviousRoom][i][j].Time
								WeeklyTarget[Room][i][j].Target = WeeklyTarget[RDPC.PreviousRoom][i][j].Target
							end
						end
					else	-- Room has a Thermostat but not PreviousRoom: don't copy
						if debug then self:debug("Room has a Thermometer but not PreviousRoom: don't copy")
						end
					end
				else
					if HeatingTable[RDPC.PreviousRoom].Thermometer then	--- PreviousRoom has a Thermometer but not Room: don't copy
						if debug then self:debug("PreviousRoom has a Thermometer but not Room: don't copy")
						end
					else	-- neither Room nor PreviousRoom have a thermometer: copy values
						if debug then self:debug("Neither Room nor PreviousRoom have a Thermometer: copy")
						end
						for i = 1, 7 do
							for j = 1, 4 do
								WeeklyTarget[Room][i][j].Time = WeeklyTarget[RDPC.PreviousRoom][i][j].Time
								WeeklyTarget[Room][i][j].Target = WeeklyTarget[RDPC.PreviousRoom][i][j].Target
							end
						end
					end
				end
						
				fibaro.setGlobalVariable('WEEKLY_TARGET', json.encode(WeeklyTarget))
				RDPC.Copy = 0
			elseif RDPC.Copy == 1 then -- second consecutive Copy key pressed: request to copy the current room
				RDPC.PreviousRoom = Room
				RDPC.Copy = 2
			else
				RDPC.Copy = 1
			end	
		else	-- the VD is in a room. Toggle between 0 and 1
			if RDPC.Copy == 0 then
				RDPC.Copy = 1
			else
				RDPC.Copy = 0
			end
		end
	
		self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
		fibaro.setGlobalVariable('RDPC', json.encode(RDPC))
		
	-----------------------------------------------Room Down --------------------------------------------

	elseif (Key == 41) then
		if (debug) then self:debug('Room down requested')
		end
		if not InARoom then
			NumberOfRooms = getNumberOfRooms(HeatingTable)
			
			repeat
				Room = Room - 1
				if Room == 0 then
					Room = NumberOfRooms
				end
			until not HeatingTable[Room].Thermostat	-- look for the first room with no physical thermostat

			RDPC.Room = Room
			if RDPC.Copy == 1 then
				RDPC.Copy = 0
			end
            self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
			fibaro.setGlobalVariable('RDPC', json.encode(RDPC))
		end
		

	-----------------------------------------------Room Up ----------------------------------------------		
		
	elseif (Key == 42) then
		if (debug) then self:debug('Room up requested')
		end
		if not InARoom then
			NumberOfRooms = getNumberOfRooms(HeatingTable)
            			
			repeat
				Room = Room + 1
				if Room > NumberOfRooms then
					Room = 1
				end
			until not HeatingTable[Room].Thermostat	-- look for the first room with no physical thermostat
			RDPC.Room = Room
			if RDPC.Copy == 1 then
				RDPC.Copy = 0
			end
			self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
			fibaro.setGlobalVariable('RDPC', json.encode(RDPC))
		end
		

	-----------------------------------------------Period Down -------------------------------------------

	elseif (Key == 11) then
		if (debug) then self:debug('Period down requested')
		end

		RDPC.Period = RDPC.Period - 1
		if RDPC.Period == 0 then
			RDPC.Period = 4
		end
		
		RDPC.Copy = 0
		self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
		fibaro.setGlobalVariable('RDPC', json.encode(RDPC))
		
		

	-----------------------------------------------Period up---------------------------------------------

	elseif (Key == 12) then
		if (debug) then self:debug('Period up requested')
		end
		RDPC.Period = RDPC.Period + 1
		if RDPC.Period > 4 then
			RDPC.Period = 1
		end
		
		RDPC.Copy = 0
		self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
		fibaro.setGlobalVariable('RDPC', json.encode(RDPC))
		

	-----------------------------------------------Start Time Fast Down---------------------------------------------

	elseif (Key == 21) then
		if debug then self:debug('Start time fast down')
		end
		
		StartTime = WeeklyTarget[Room][RDPC.Day][RDPC.Period].Time
		if RDPC.Period == 1 then
			Limit = 0
		else
			Limit = WeeklyTarget[Room][RDPC.Day][RDPC.Period-1].Time
			if Limit % START_TIME_FAST_STEP ~= 0 then
				Limit = (math.floor (Limit / START_TIME_FAST_STEP) + 1) * START_TIME_FAST_STEP
			end
		end
		
		if StartTime - START_TIME_FAST_STEP > Limit then
			if StartTime % START_TIME_FAST_STEP == 0 then
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Time = StartTime - START_TIME_FAST_STEP
			else
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Time = StartTime - (StartTime % START_TIME_FAST_STEP)
			end
		end
			
		fibaro.setGlobalVariable('WEEKLY_TARGET', json.encode(WeeklyTarget))
		
		RDPC.Copy = 0
		self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
		fibaro.setGlobalVariable('RDPC', json.encode(RDPC))
		


	-----------------------------------------------Start Time Down---------------------------------------------

	elseif (Key == 22) then
		if debug then self:debug('Start time down')
		end
		
		StartTime = WeeklyTarget[Room][RDPC.Day][RDPC.Period].Time
		if RDPC.Period == 1 then
			Limit = 0
		else
			Limit =  WeeklyTarget[Room][RDPC.Day][RDPC.Period-1].Time
			if Limit % START_TIME_STEP ~= 0 then
				Limit = (math.floor (Limit / START_TIME_STEP) + 1) * START_TIME_STEP
			end
		end
		
		if StartTime - START_TIME_STEP > Limit then
			if StartTime % START_TIME_STEP == 0 then
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Time = StartTime - START_TIME_STEP
			else
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Time = StartTime - (StartTime % START_TIME_STEP)
			end
		end
		
		fibaro.setGlobalVariable('WEEKLY_TARGET', json.encode(WeeklyTarget))
		
		RDPC.Copy = 0
		self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
		fibaro.setGlobalVariable('RDPC', json.encode(RDPC))

	-----------------------------------------------Start Time Up---------------------------------------------

	elseif (Key == 23) then
		if debug then self:debug('Start time up')
		end
		
		StartTime = WeeklyTarget[Room][RDPC.Day][RDPC.Period].Time
		if RDPC.Period == 4 then
			Limit = 24*60
		else
			Limit = WeeklyTarget[Room][RDPC.Day][RDPC.Period+1].Time
			if Limit % START_TIME_STEP ~= 0 then
				Limit = math.floor (Limit / START_TIME_STEP) * START_TIME_STEP
			end
		end
		
		if StartTime + START_TIME_STEP < Limit then
			if StartTime % START_TIME_STEP == 0 then
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Time = StartTime + START_TIME_STEP
			else
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Time = StartTime + START_TIME_STEP - (StartTime % START_TIME_STEP)
			end
		end
		
		fibaro.setGlobalVariable('WEEKLY_TARGET', json.encode(WeeklyTarget))
		
		RDPC.Copy = 0
		self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
		fibaro.setGlobalVariable('RDPC', json.encode(RDPC))

	-----------------------------------------------Start Time Fast Up---------------------------------------------

	elseif (Key == 24) then
		if debug then self:debug('Start time fast up')
		end
		
		StartTime = WeeklyTarget[Room][RDPC.Day][RDPC.Period].Time
		if RDPC.Period == 4 then
			Limit = 24*60
		else
			Limit = WeeklyTarget[Room][RDPC.Day][RDPC.Period+1].Time
			if Limit % START_TIME_FAST_STEP ~= 0 then
				Limit = math.floor (Limit / START_TIME_FAST_STEP) * START_TIME_FAST_STEP
			end
		end
		
		if StartTime + START_TIME_FAST_STEP < Limit then
			if StartTime % START_TIME_FAST_STEP == 0 then
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Time = StartTime + START_TIME_FAST_STEP
			else
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Time = StartTime + START_TIME_FAST_STEP - (StartTime % START_TIME_FAST_STEP)
			end
		end

		fibaro.setGlobalVariable('WEEKLY_TARGET', json.encode(WeeklyTarget))
		
		RDPC.Copy = 0
		self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
		fibaro.setGlobalVariable('RDPC', json.encode(RDPC))

	-----------------------------------------------Temperature Fast Down---------------------------------------------

	elseif (Key == 31) then
		if debug then self:debug('Temperature fast down')
		end

		if HeatingTable[Room].Thermometer then
			if WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target - TEMP_FAST_STEP > TEMP_TARGET_MIN then 
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target = WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target - TEMP_FAST_STEP
			else
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target = TEMP_TARGET_MIN
			end
		else
			WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target = 'OFF'
		end
		
		fibaro.setGlobalVariable('WEEKLY_TARGET', json.encode(WeeklyTarget))
		
		RDPC.Copy = 0
		self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
		fibaro.setGlobalVariable('RDPC', json.encode(RDPC))

	-----------------------------------------------Temperature Down---------------------------------------------

	elseif (Key == 32) then
		if debug then self:debug('Temperature down')
		end

		if HeatingTable[Room].Thermometer then
			if WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target - TEMP_STEP > TEMP_TARGET_MIN then 
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target = WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target - TEMP_STEP
			else
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target = TEMP_TARGET_MIN
			end
		else
			WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target = 'OFF'
		end
		
		fibaro.setGlobalVariable('WEEKLY_TARGET', json.encode(WeeklyTarget))
		
		RDPC.Copy = 0
		self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
		fibaro.setGlobalVariable('RDPC', json.encode(RDPC))

	-----------------------------------------------Temperature Up---------------------------------------------

	elseif (Key == 33) then
		if debug then self:debug('Temperature up')
		end

		if HeatingTable[Room].Thermometer then
			if WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target + TEMP_STEP < TEMP_TARGET_MAX then 
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target = WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target + TEMP_STEP
			else
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target = TEMP_TARGET_MAX
			end
		else
			WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target = 'ON'
		end
		
		fibaro.setGlobalVariable('WEEKLY_TARGET', json.encode(WeeklyTarget))
		
		RDPC.Copy = 0
		self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
		fibaro.setGlobalVariable('RDPC', json.encode(RDPC))

	-----------------------------------------------Temperature Fast Up---------------------------------------------
	  
	elseif (Key == 34) then	
		if debug then self:debug('Temperature fast up')
		end

		if HeatingTable[Room].Thermometer then
			if WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target + TEMP_FAST_STEP < TEMP_TARGET_MAX then 
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target = WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target + TEMP_FAST_STEP
			else
				WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target = TEMP_TARGET_MAX
			end
		else
			WeeklyTarget[Room][RDPC.Day][RDPC.Period].Target = 'ON'
		end
		
		fibaro.setGlobalVariable('WEEKLY_TARGET', json.encode(WeeklyTarget))
		
		RDPC.Copy = 0
		self:updateFullDisplay(RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
		fibaro.setGlobalVariable('RDPC', json.encode(RDPC))

	-----------------------------------------------Unknown key!---------------------------------------------

	else 
		if (debug) then self:debug('Unknown key requested')
		end
	end

end
---------------------------------------------------------------------------------------------------------------
---------------------------------------- End function sendKey -------------------------------------------------
---------------------------------------------------------------------------------------------------------------



function QuickApp:updateDisplay()

	if debug then self:debug('Start of function updateDisplay')
	end

	local WeeklyTarget = json.decode(fibaro.getGlobalVariable('WEEKLY_TARGET'))
	local HeatingTable = json.decode(fibaro.getGlobalVariable('HEATING_TABLE'))
--	local HeatingTrigger = json.decode(fibaro.getGlobalVariable('HEATING_TRIGGER'))
	local RDPC = json.decode(fibaro.getGlobalVariable('RDPC'))
	local Room, TempTargetTVD, NewTempTarget = 0
	
	if self.InARoom then
		Room = self.DeviceRoom
	else
		Room = RDPC.Room
	end
	if debug then self:debug('PreviousRoom = '..RDPC.PreviousRoom..'  Room = '..Room..'  Day = '..RDPC.Day..'  Period = '..RDPC.Period..'  Copy = '..RDPC.Copy)
	end

	local DateTime = os.date("*t", os.time())
	local Day = ((DateTime.wday + 5) % 7)+1	-- changes the day number Sunday = 1 to Sunday = 7
	local Time = (DateTime.hour * 60) + DateTime.min
	if debug then self:debug('Day = ' .. Day .. '; Time in minute = ' .. Time .. '; Hour = '
			.. DateTime.hour .. '; Minutes = ' .. DateTime.min)
	end

	local NumberOfRooms = getNumberOfRooms(HeatingTable)
	
	if not InARoom then	-- if the device is not installed in a room (main device) then checks if there is a change of target temperature
		
		for room = 1, NumberOfRooms do
			if not HeatingTable[room].Thermostat then	-- room managed by the virtual thermostat
							
				TempTargetTVD = HeatingTable[room].TargetTVD	-- this is the last temperature target provided by this virtual thermostat for this room
				
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
				if debug then self:debug('Room number = '..room..'  TempTargetTVD = ' .. TempTargetTVD .. ' NewTempTarget = ' .. NewTempTarget)
				end
							
				if NewTempTarget ~= TempTargetTVD then	-- if different from the previous one, update it and generate a trigger to process the new target
					HeatingTable[room].TargetTVD = NewTempTarget
					fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
				end
			end
		end
	end
		
	if debug then self:debug('\nPrevious Room = '..RDPC.PreviousRoom..'  Room = '..Room..'  Day = '..RDPC.Day..'  Period = '..RDPC.Period..'  Copy = '..RDPC.Copy..'   Consigne = '..HeatingTable[RDPC.Room].TargetTVD)
	end
	
	self:updateFullDisplay(VDId, RDPC.PreviousRoom, Room, RDPC.Day, RDPC.Period, RDPC.Copy)
	
end