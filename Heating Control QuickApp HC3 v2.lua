--[[ Heating Control QuickApp.                      v2 2023/11/21

Controls the heating system in a room

]]--

--[[Function:  setDurationString(duration, endTimer, mode)

Set the content of the duration string based on:
- the timer duration left (in seconds)
- the timer end time (in seconds in system time)
- the mode in which the system is (manual or away as there is no duration string for other modes)

Call: DurationString = setDurationString (duration, endTimer, mode) where DurationString is a string.

--]]

function setDurationString(duration, endTimer, mode)

	local setDurationStringDebug = false

	if setDurationStringDebug then
		self:debug('Function setDurationString.')
	end

	local durationString = ' '
	
	if mode == 'Manual' then
		durationString = 'Duration:  '..tostring(math.floor((duration + 59)/60))..' Min'
		
	elseif mode == 'Away' then
		if duration >= 0 then
			durationString = os.date("Away till: %d %b at %Hh", endTimer)
		else
			durationString = 'Duration:  00 Min'
		end	
		
	end
	
	if setDurationStringDebug then
		self:debug('DurationString = '..durationString)
	end
	return durationString
	
end	-- end of Function setDurationString


--[[getNumberOfRooms(HeatingTable)
This function checks the number of rooms with a controlled heating system

Call: numberOfRooms = getNumberOfRooms(HeatingTable)
--]]

function getNumberOfRooms(HD)
local numberOfRooms = 0
local room, t = next(HD, nil)
while room do
	numberOfRooms = room
	room, t = next(HeatingTable, room)
end
return (numberOfRooms)
	
end -- of function getNumberOfRooms

	
----------------------------------- End of internal functions -------------------------------------
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
------------------------------------ Function onInit  ---------------------------------------------
---------------------------------------------------------------------------------------------------

function QuickApp:onInit()

    local debug = true

	if debug then
		self:debug('Function onInit.  '..'device Id = '..self.id)
    end
		
	self.MODE_STRING_OFF = 		'Mode:    OFF'
	self.MODE_STRING_AUTO = 	'Mode:    AUTOMATIC'
	self.MODE_STRING_MANU = 	'Mode:    MANUAL'
	self.MODE_STRING_ECO = 		'Mode:    ECONOMY'
	self.MODE_STRING_AWAY = 	'Mode:    AWAY'
	
    self.TempEco = 2		--  target temperature decrease except during off-peak hours for electric heating
							-- also defined in HeatingManagement

	local HT = fibaro.getGlobalVariable('HEATING_TABLE')
    local HeatingTable = json.decode(HT)
	local roomName = fibaro.getRoomNameByDeviceID(self.id)
	if debug then
		self:debug("Function onInit. roomName = "..roomName..'  QAId = '..self.id)
	end
	local room, roomTable = next(HeatingTable, nil)	
	while room do
		if roomName == roomTable.RoomName then
			self.Room = room
			if debug then
				self:debug('Function onInit ', 'Room number: '..room..'    Room name: '..roomName)
			end
			HeatingTable[room].QAId = self.id
			fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
			self:updateDisplay()
			break
		end
		room, roomTable = next(HeatingTable, room)
	end
	if not room then	-- roomName not found in HeatingTable
		self:debug('Function onInit. ', 'No roomName: '..roomName..' in HeatingTable ')
	end	-- self.Room contains the room number in which the device is installed
	
-- check if HeatingTimer scene is running and start it if not
	local HeatingTimerSceneId = 0
	for _,s in ipairs(api.get("/scenes")) do
		if s.name == "Heating_Timer" then
			HeatingTimerSceneId = s.id
			if s.isRunning then 
				if debug then
					self:debug('Function onInit. ', 'Scene '..s.name..' is running')
				end
			else
				if debug then
					self:debug('Function onInit. ', 'Scene '..s.name..' is not running. Launching it')
				end
				api.put('/scenes/'..HeatingTimerSceneId, {enabled = true})
				fibaro.scene('execute', {HeatingTimerSceneId})
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
------------------------------------ Function updateDisplay  ---------------------------------------------
---------------------------------------------------------------------------------------------------

function QuickApp:updateDisplay()
		
	local debug = true

	local TempString, ModeString, TargetString, DurationString = ' '
	
	if self.Room == 0 then
		ModeString = 'Press any key to initialize'
		self:updateView("Mode", "text", ModeString)
		if debug then
			self:debug('UpdateDisplay : self.Room = 0')
		end
	else
		if debug then
			self:debug('UpdateDisplay : self.Room = '..self.Room)
		end
		local HT = fibaro.getGlobalVariable('HEATING_TABLE')
		local HeatingTable = json.decode(HT)
		HT = fibaro.getGlobalVariable('HEATING_TRIGGER')
		local HeatingTrigger = json.decode(HT)

		if HeatingTable[self.Room].Thermometer then
			local Temp = tonumber (HeatingTable[self.Room].LastTemp)
			TempString = 'Temp:   '..string.format('%.1f', Temp)..' ºC'
		else
			TempString = 'No thermometer'
		end

------------------------------------------- Mode: Off ------------------------------------------- 
		if HeatingTable[self.Room].Mode == 'Off' then
			if debug then
				self:debug('Mode Off')
			end  
			-- updates the VD UI variables
			ModeString = self.MODE_STRING_OFF
			TargetString = ' '
			DurationString = ' '
		
------------------------------------------- Mode: Auto ------------------------------------------- 
		elseif HeatingTable[self.Room].Mode == 'Auto' then
			if debug then
				self:debug('Mode Auto')
			end  
			-- updates the VD UI variables
			ModeString = self.MODE_STRING_AUTO
			
			if HeatingTable[self.Room].Thermometer then
				TargetString = 'Target:   '..string.format('%.1f', HeatingTable[self.Room].TargetAuto)..' ºC'
			else
				TargetString = ' '
			end
			
			DurationString = ' '

----------------------------------------- Mode: Manual ------------------------------------------- 		
		elseif HeatingTable[self.Room].Mode == 'Manual' then
			if debug then
				self:debug('Mode Manual')
			end 
			-- updates the VD UI variables
					
			if (HeatingTable[self.Room].HeatingType == 'Fire' or HeatingTable[self.Room].HeatingType == 'Fire-Inverter') then
				if HeatingTable[self.Room].FlamesManu == FlamesEco then
					TargetString = 'Flames:   '..'Eco'
				else
					TargetString = 'Flames:   '..tostring(HeatingTable[self.Room].FlamesManu)
				end
			else
				TargetString = ' '
			end
			
			DateTime = os.time()
			
			if DateTime >= HeatingTable[self.Room].EndTimer then
				-- Timer elapsed. Switching back to PreviousMode mode
				if debug then
					self:debug('Mode Manu. Timer elapsed. Switching back to Previous Mode: '..HeatingTable[self.Room].PreviousMode)
				end

				DurationString = ' '
				if HeatingTable[self.Room].PreviousMode == 'Auto' then
					HeatingTrigger[self.Room].Mode = 'Auto'
					ModeString = self.MODE_STRING_AUTO
				else
					HeatingTrigger[self.Room].Mode = 'Off'
					ModeString = MODE_STRING_OFF
				end
				
				HeatingTrigger[self.Room].Mode = HeatingTable[self.Room].PreviousMode
				fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))
	--[[
				if HeatingTable[self.Room].VoiceActivation then
					fibaro.call (HeatingTable[self.Room].VoiceActivationId, 'turnOff')	-- turn off the VoiceActivation switch to be sure that it will be
																						-- off next time it is used
				end
	--]]
			else
				-- Timer not elapsed. Refresh timer on display
				if debug then self:debug('Mode Manu. Timer not elapsed. Timer = '..tostring(HeatingTable[self.Room].EndTimer-DateTime))
				end
				ModeString = self.MODE_STRING_MANU
				DurationString = setDurationString(HeatingTable[self.Room].EndTimer - DateTime, HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)
			end

------------------------------------------- Mode: Away ------------------------------------------- 			
		elseif HeatingTable[self.Room].Mode == 'Away' then
			if debug then
				self:debug('Mode Away')
			end 
			-- updates the VD UI variables
			ModeString = self.MODE_STRING_AWAY
			if HeatingTable[self.Room].Thermometer then 
				TargetString = 'Target:   '..string.format('%.1f', HeatingTable[self.Room].TargetAway)..' ºC'
			else
				TargetString = 'Hors Gel'
			end
			
			DateTime = os.time()
			
			if DateTime >= HeatingTable[self.Room].EndTimer then
				-- Timer elapsed. Switching back to Auto mode
				if debug then
					self:debug('Mode Away. Timer elapsed. Switching back to Auto')
				end
				ModeString = self.MODE_STRING_AUTO
				DurationString = ' '
				HeatingTrigger[self.Room].Mode = 'Auto'
				fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))
			else
				-- Timer not elapsed. Refresh timer on display
				if debug then self:debug('Mode Away. Timer not elapsed. Timer = '..tostring(HeatingTable[self.Room].EndTimer-DateTime))
				end
				ModeString = 'Mode:      Away'
				DurationString = setDurationString(HeatingTable[self.Room].EndTimer - DateTime, HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)
			end

-------------------------------------------- Mode: Eco ------------------------------------------- 
		elseif HeatingTable[self.Room].Mode == 'Eco' then
			if debug then
				self:debug('Mode Eco')
			end  
			-- updates the VD UI variables
			ModeString = self.MODE_STRING_ECO
			
			if HeatingTable[self.Room].Thermometer then
				TargetString = 'Target:   '..string.format('%.1f', HeatingTable[self.Room].TargetAuto - self.TempEco)..' ºC'
			else
				TargetString = ' '
			end
			
			DurationString = ' '	
		end


		if HeatingTable[self.Room].Thermometer then
			TempString = 'Temperature:   '..HeatingTable[self.Room].LastTemp..' °C'
		else
			TempString = ' '
		end
		
		self:updateView("Temp", "text", TempString)
		self:updateView("Mode", "text", ModeString)
		self:updateView("Target", "text", TargetString)
		self:updateView("Duration", "text", DurationString)
	end

end --- end function



---------------------------------------------------------------------------------------------------
------------------------------------ Function sendKey  ---------------------------------------------
---------------------------------------------------------------------------------------------------

function QuickApp:sendKey(key)



    local debug = true
	
	local FlamesMin = 0
	local FlamesMax = 8
	local FlamesEco = 9
	local Step = 0.5					-- increment step of target temperature
	local DurationManualStep = 10		-- low increment step in minutes in Manual mode with a FirePlace in the room
	local DurationAwayStep = 60			-- low increment step in minutes in Away mode and in Manual mode if Convertor only
	local DurationManualHighStep = 30	-- high increment step in minutes in Manual mode with a FirePlace in the room
	local DurationAwayHighStep = 24*60	-- high increment step in minutes in Away mode and in Manual mode if Convertor only
	local Step = 0.5					-- increment step of target temperature
	local TempTargetMax = 26
	local TempTargetAwayMax = 20
	local TempTargetMin = 10
	local TempTargetAwayMin = 5
	local TempTargetDefault = 18
	local TempTargetAwayDefault = 12
	local TempEco = 2					-- Temperature decrease of TempTarget when in Eco mode
	
	local ModeString, TargetString, DurationString, TempString = ''
	local DateTime = 0
	
	if debug then
		self:debug("Function sendKey. Key = "..json.encode(key))
		self:debug("Function sendKey. DeviceID = "..key.deviceId)
	end
	
-- check if HeatingTimer scene is running and start it if not
	local HeatingTimerSceneId = 0
	for _,s in ipairs(api.get("/scenes")) do
		if s.name == "Heating_Timer" then
			HeatingTimerSceneId = s.id
			if s.isRunning then 
				if debug then
					self:debug('Function onInit. ', 'Scene '..s.name..' is running')
				end
			else
				if debug then
					self:debug('Function onInit. ', 'Scene '..s.name..' is not running. Launching it')
				end
				api.put('/scenes/'..HeatingTimerSceneId, {enabled = true})
				fibaro.scene('execute', {HeatingTimerSceneId})
			end
		end
	end
	
    local HT = fibaro.getGlobalVariable('HEATING_TABLE')
    local HeatingTable = json.decode(HT)
    HT = fibaro.getGlobalVariable('HEATING_TRIGGER')
    local HeatingTrigger = json.decode(HT)
    if debug then
        self:debug('self.Room = '..self.Room)
    end
	
    if self.Room == 0 then	-- first key pressed: need to find out room number
        
        local roomName = fibaro.getRoomNameByDeviceID(key.deviceId)
        if debug then
            self:debug("Function sendKey. roomName = "..roomName..'  QAId = '..key.deviceId)
        end
		local room, roomTable = next(HeatingTable, nil)	
		if debug then
			self:debug('Function sendKey ', 'Room name: '..roomName)
		end
		while room do
			if roomName == roomTable.RoomName then
				self.Room = room
				if debug then
					self:debug('Function sendKey ', 'Room number: '..room..'    Room name: '..roomName)
				end
				HeatingTable[room].QAId = key.deviceId
				fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
				break
			end
			room, roomTable = next(test, room)
		end
		if not room then	-- roomName not found in HeatingTable
			self:debug('sendKey', 'No roomName: '..roomName..' in HeatingTable ')
		end
	end	-- self.Room contains the room number in which the device is installed
	
----------------------------------------------Off---------------------------------------------
	if key.elementName == '0' then
		if true then 
			self:debug("Function sendKey. Key = 0")
			self:debug('Off mode requested')
		end

		-- updates the VD UI variables
		ModeString = self.MODE_STRING_OFF
		TargetString = ' '
		DurationString = ' '
		
	--	self:updateView("Mode", "text", ModeString)

		-- updates HeatingTable structure
		HeatingTrigger[self.Room].Mode='Off'
		fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))

----------------------------------------------Auto---------------------------------------------

	elseif key.elementName == '1' then
		if debug then
            self:debug("Function sendKey. Key = 1")
		    self:debug('Automatic mode requested')
        end
		
		-- updates the VD UI variables
		ModeString = self.MODE_STRING_AUTO
		if HeatingTable[self.Room].Thermometer then
			TargetString = 'Target:   '..string.format('%.1f', HeatingTable[self.Room].TargetAuto)..' ºC'
		else
			TargetString = ' '
		end
		DurationString = ' '
        if debug then
            self:debug('Function sendKey ', 'TargetString = '..TargetString)
        end
		-- updates HeatingTable structure
		HeatingTrigger[self.Room].Mode = 'Auto'
		
		fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))
		
	-----------------------------------------------Manual---------------------------------------------
	elseif key.elementName == '2' then
		if debug then
			self:debug("Function sendKey. Key = 2")
		    self:debug('Manual mode requested')
		end
	 
		DateTime = os.time()
		if HeatingTable[self.Room].Mode ~= 'Manual' then
			if debug then
				self:debug('Switching Mode to Manual')
			end
			EndDateTime = DateTime + DurationManualStep	* 60 -- initializes duration if previous mode was not manual
		else
			EndDateTime = HeatingTable[self.Room].EndTimer		-- recovers the remaining value of the timer if already in manual mode
		end

		-- updates the VD UI variables
        if debug then
				self:debug('Manual: updates the VD UI variables')
		end
		ModeString = self.MODE_STRING_MANU
		if (HeatingTable[self.Room].HeatingType == 'Fire' or HeatingTable[self.Room].HeatingType == 'Fire-Inverter') then
			if tonumber(HeatingTable[self.Room].FlamesManu) == FlamesEco then
				FlamesString = 'Eco'
			else
				FlamesString = tostring(HeatingTable[self.Room].FlamesManu)
			end
			TargetString = 'Flames:   '..FlamesString
		else	
			TargetString = ' '
		end
        if debug then
				self:debug('Manual: calling setDurationString')
		end
		DurationString = setDurationString(EndDateTime-DateTime, EndDateTime, 'Manual')

		-- updates HeatingTable structure
		HeatingTrigger[self.Room].Mode='Manual'
		HeatingTable[self.Room].EndTimer = EndDateTime
		
        if debug then
			self:debug('Manual: setting global variables')
		end
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
		fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))
        if debug then
			self:debug('Manual: global variables set')
		end

----------------------------------------------Away---------------------------------------------
	elseif key.elementName == '3' then
		if debug then
			self:debug('Away mode requested')
		end

		DateTime = os.time()
		if (HeatingTable[self.Room].Mode ~= 'Away') then
			if debug then
				self:debug('Switching Mode to Away')
			end
			EndDateTime = DateTime + DurationAwayStep * 60		-- initializes remaining duration if not previously in away mode
		else
			EndDateTime = HeatingTable[self.Room].EndTimer		-- recovers remaining timer if already in away mode
		end
		
		-- updates the VD UI variables
		ModeString = self.MODE_STRING_AWAY
		if HeatingTable[self.Room].Thermometer then
			TargetString = 'Target:   '..string.format('%.1f', HeatingTable[self.Room].TargetAway)..' ºC'
		else
			TargetString = 'Hors gel'
		end
		DurationString = setDurationString(EndDateTime-DateTime, EndDateTime, 'Away')

		-- updates HeatingTable structure
		HeatingTrigger[self.Room].Mode='Away'
		HeatingTable[self.Room].EndTimer = EndDateTime
		
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
		fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))
		
-------------------------------------------Mode Eco -------------------------------------------	
	elseif key.elementName == '4' then
		if debug then
			self:debug('Eco mode requested')
		end

		-- updates the VD UI variables
		ModeString = self.MODE_STRING_ECO
		if HeatingTable[self.Room].Thermometer then
			TargetString = 'Target:   '..string.format('%.1f', HeatingTable[self.Room].TargetAuto - self.TempEco)..' ºC'
		else
			TargetString = ' '
		end
		DurationString = ' '

		-- updates HeatingTable structure
		HeatingTrigger[self.Room].Mode = 'Eco'
		
		fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))
		
--------------------------------------------Temp Min -------------------------------------------
	elseif key.elementName == '10' then
		if debug then
			self:debug('Temp Min requested')
		end

		if HeatingTable[self.Room].Mode == 'Auto' then
			if debug then
				self:debug('Decreasing Auto Target temperature to Min')
			end
			
			-- updates the VD UI variables
			ModeString = self.MODE_STRING_AUTO
			if HeatingTable[self.Room].Thermometer then	
				TempTarget = TempTargetMin
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = ' '
			end
			DurationString = ' '

		-- updates HeatingTable structure
			HeatingTrigger[self.Room].TargetAuto = TempTarget


		elseif HeatingTable[self.Room].Mode == 'Manual' then
			if (debug) then self:debug('Decreasing flames level to Min')
			end
			
			-- updates the VD UI variables
			ModeString = self.MODE_STRING_MANU
			if (HeatingTable[self.Room].HeatingType=='Fire' or HeatingTable[self.Room].HeatingType=='Fire-Inverter') then
				Flames = FlamesMin
				TargetString = 'Flames:   '..tostring(Flames)
			else
				TargetString = ' '
			end
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - os.time(), HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)

			-- updates HeatingTable structure
			HeatingTrigger[self.Room].FlamesManu = Flames


		elseif HeatingTable[self.Room].Mode == 'Away' then
			if (debug) then self:debug('Decreasing Away Target temperature to Min')
			end

			-- updates the VD UI variables
			ModeString = self.MODE_STRING_AWAY
			if HeatingTable[self.Room].Thermometer then
				TempTarget = TempTargetAwayMin
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = 'Hors gel'
			end
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - os.time(), HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)

			-- updates HeatingTable structure
			HeatingTable[self.Room].TargetAway = TempTarget


		elseif (HeatingTable[self.Room].Mode == 'Off') then
			if (debug) then self:debug('Mode Off: nothing to do')
			end

			-- updates the VD UI variables
			ModeString = self.MODE_STRING_OFF
			TargetString = ' '
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change

		end
		
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
		fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))


-------------------------------------------Temp Down---------------------------------------------
	elseif key.elementName == '11' then
		if debug then
			self:debug('Temp down requested')
		end

		if HeatingTable[self.Room].Mode == 'Auto' then
			if debug then
				self:debug('Decreasing Auto Target temperature')
			end
			
				
			-- updates the VD UI variables
			ModeString = self.MODE_STRING_AUTO
			if HeatingTable[self.Room].Thermometer then
				TempTarget =  HeatingTable[self.Room].TargetAuto - Step	-- computes new target temperatureTempTarget = TempTargetAwayMin
				if ( TempTarget < TempTargetMin) then TempTarget = TempTargetMin
				end
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = ' '
			end
			DurationString = ' '

			-- updates HeatingTable structure
			HeatingTrigger[self.Room].TargetAuto = TempTarget


		elseif HeatingTable[self.Room].Mode == 'Manual' then
			if debug then
				self:debug('Decreasing flames level')
			end

			-- updates the VD UI variables
			ModeString = self.MODE_STRING_MANU
			if (HeatingTable[self.Room].HeatingType=='Fire' or HeatingTable[self.Room].HeatingType=='Fire-Inverter') then
				Flames =  HeatingTable[self.Room].FlamesManu - 1	-- computes new flames level as in "Manu" mode, there is no temp target
				if Flames < FlamesMin then
					Flames = FlamesMin
				end
				if Flames == FlamesEco then
					FlamesString = 'Eco'
				else
					FlamesString = tostring(Flames)
				end
				TargetString = 'Flames:   '..FlamesString
			else
				TargetString = ' '
			end
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - os.time(), HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)

			-- updates HeatingTable structure
			HeatingTrigger[self.Room].FlamesManu = Flames


		elseif HeatingTable[self.Room].Mode == 'Away' then
			if debug then
				self:debug('Decreasing Away Target temperature')
			end
			
			-- updates the VD UI variables
			ModeString = self.MODE_STRING_AWAY
			if HeatingTable[self.Room].Thermometer then
				TempTarget =  HeatingTable[self.Room].TargetAway - Step
				if TempTarget < TempTargetAwayMin then
					TempTarget = TempTargetAwayMin
				end
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = 'Hors gel'
			end
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - os.time(), HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)

			-- updates HeatingTable structure
			HeatingTable[self.Room].TargetAway = TempTarget
			

		elseif HeatingTable[self.Room].Mode == 'Off' then
			if debug then
				self:debug('Mode Off: nothing to do')
			end

			-- updates the VD UI variables
			ModeString = self.MODE_STRING_OFF
			TargetString = ' '
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change
		end
		
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
		fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))

--------------------------------------------Temp Up---------------------------------------------
	elseif key.elementName == '12' then
		if debug then
			self:debug('Temp up requested')
		end

		if HeatingTable[self.Room].Mode == 'Auto' then
			if debug then
				self:debug('Increasing Auto Target temperature')
			end
			
			-- updates the VD UI variables
			ModeString = self.MODE_STRING_AUTO
			if HeatingTable[self.Room].Thermometer then
				TempTarget =  HeatingTable[self.Room].TargetAuto + Step
				if TempTarget > TempTargetMax then
					TempTarget = TempTargetMax
				end
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = ' '
			end
			DurationString = ' '

	-- updates HeatingTable structure
			HeatingTrigger[self.Room].TargetAuto = TempTarget


		elseif HeatingTable[self.Room].Mode == 'Manual' then
			if debug then
				self:debug('Increasing flames level')
			end
			
			ModeString = self.MODE_STRING_MANU	
			if (HeatingTable[self.Room].HeatingType=='Fire' or HeatingTable[self.Room].HeatingType=='Fire-Inverter') then
				Flames = HeatingTable[self.Room].FlamesManu + 1
				if Flames > FlamesEco then
					Flames = FlamesEco
				end
				if Flames == FlamesEco then
					FlamesString = 'Eco'
				else
					FlamesString = tostring(Flames)
				end
				TargetString = 'Flames:   '..FlamesString
			else
				TargetString = ' '
			end
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - os.time(), HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)

			-- updates HeatingTable structure
			HeatingTrigger[self.Room].FlamesManu = Flames


		elseif HeatingTable[self.Room].Mode == 'Away' then
			if debug then
				self:debug('Increasing Away Target temperature')
			end

			ModeString = self.MODE_STRING_AWAY
			if HeatingTable[self.Room].Thermometer then
				TempTarget =  HeatingTable[self.Room].TargetAway + Step
				if TempTarget > TempTargetAwayMax then
					TempTarget = TempTargetAwayMax
				end
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = 'Hors gel'
			end
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - os.time(), HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)

			-- updates HeatingTable structure
			HeatingTable[self.Room].TargetAway = TempTarget


		elseif HeatingTable[self.Room].Mode == 'Off' then
			if debug then
				self:debug('Mode Off: nothing to do')
			end

			-- updates the VD UI variables
			ModeString = self.MODE_STRING_OFF
			TargetString = ' '
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change
		end
		
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
		fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))

--------------------------------------------Temp Max---------------------------------------------
	elseif key.elementName == '13' then
		if debug then
			self:debug('Temp max requested')
		end
		
			if HeatingTable[self.Room].Mode == 'Auto' then
			if debug then
				self:debug('Increasing Auto Target temperature to Max')
			end
			
			-- updates the VD UI variables
			ModeString = self.MODE_STRING_AUTO
			if HeatingTable[self.Room].Thermometer then	
				TempTarget = TempTargetMax
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = ' '
			end
			DurationString = ' '

		-- updates HeatingTable structure
			HeatingTrigger[self.Room].TargetAuto = TempTarget


		elseif HeatingTable[self.Room].Mode == 'Manual' then
			if debug then
				self:debug('Increasing flames level to Max')
			end
			
			-- updates the VD UI variables
			ModeString = MODE_STRING_MANU
			if (HeatingTable[self.Room].HeatingType=='Fire' or HeatingTable[self.Room].HeatingType=='Fire-Inverter') then
				Flames = FlamesMax
				TargetString = 'Flames:   '..tostring(Flames)
			else
				TargetString = ' '
			end
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - os.time(), HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)

			-- updates HeatingTable structure
			
			HeatingTrigger[self.Room].FlamesManu = Flames


		elseif HeatingTable[self.Room].Mode == 'Away' then
			if debug then
				self:debug('Increasing Away Target temperature to Max')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_AWAY
			if HeatingTable[self.Room].Thermometer then
				TempTarget = TempTargetAwayMax
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = 'Hors gel'
			end
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - os.time(), HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)
			
			-- updates HeatingTable[self.Room] structure
			HeatingTable[self.Room].TargetAway = TempTarget


		elseif HeatingTable[self.Room].Mode == 'Off' then
			if debug then
				self:debug('Mode Off: nothing to do')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_OFF
			TargetString = ' '
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change

		end
		
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
		fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))


------------------------------------Duration Fast Down---------------------------------------------
	elseif key.elementName == '20' then
		if debug then
			self:debug('Duration fast down requested')
		end

		if HeatingTable[self.Room].Mode == 'Auto' then
			if debug then
				self:debug('Mode Auto: nothing to do')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_AUTO
			if HeatingTable[self.Room].Thermometer then
				TargetString = 'Target:   '..string.format('%.1f', HeatingTable[self.Room].TargetAuto)..' ºC'
			else
				TargetString = ' '
			end
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change

		elseif HeatingTable[self.Room].Mode == 'Manual' then
			if debug then
				self:debug('Decreasing Manual Duration fast')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_MANU
			
			if (HeatingTable[self.Room].HeatingType=='Fire' or HeatingTable[self.Room].HeatingType=='Fire-Inverter') then
				TargetString = 'Flames:   '..tostring(HeatingTable[self.Room].FlamesManu)
			else
				TargetString = ' '
			end

			DateTime = os.time()
			Duration =  math.floor((HeatingTable[self.Room].EndTimer - DateTime)/60)	-- duration left rounded to the closest minute
			if Duration % DurationManualHighStep == 0 then
					Duration =  Duration - DurationManualHighStep
			else
				Duration = Duration - (Duration % DurationManualHighStep)
			end

			if Duration <= 0 then 	-- end of Manual mode.
				Duration = 0
			end	
			
			DurationString = setDurationString(Duration * 60, DateTime + (Duration * 60), HeatingTable[self.Room].Mode)

			-- updates HeatingTable structure
			HeatingTable[self.Room].EndTimer = DateTime + (Duration * 60)


		elseif HeatingTable[self.Room].Mode == 'Away' then
			if debug then
				self:debug('Decreasing Away Duration fast')
			end

			-- updates the VD UI variables
			
			ModeString = MODE_STRING_AWAY

			if HeatingTable[self.Room].Thermometer then
				TempTarget = HeatingTable[self.Room].TargetAway
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = 'Hors gel'
			end

			DateTime = os.time()
			
			if HeatingTable[self.Room].EndTimer % (DurationAwayStep * 60) == 0 then
				HeatingTable[self.Room].EndTimer = HeatingTable[self.Room].EndTimer - (DurationAwayHighStep * 60)
			else
				HeatingTable[self.Room].EndTimer = HeatingTable[self.Room].EndTimer - (HeatingTable[self.Room].EndTimer % (DurationAwayStep * 60))
			end
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - DateTime, HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)

		elseif HeatingTable[self.Room].Mode == 'Off' then
			if debug then
				self:debug('Mode Off: nothing to do')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_OFF
			TargetString = ' '
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change

		end
		
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))

-------------------------------------Duration Down---------------------------------------------
	elseif key.elementName == '21' then
		if debug then
			self:debug('Duration down requested')
		end

		if HeatingTable[self.Room].Mode == 'Auto' then
			if debug then
				self:debug('Mode Auto: nothing to do')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_AUTO
			if HeatingTable[self.Room].Thermometer then
				TargetString = 'Target:   '..string.format('%.1f', HeatingTable[self.Room].TargetAuto)..' ºC'
			else
				TargetString = ' '
			end
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change

		elseif HeatingTable[self.Room].Mode == 'Manual' then
			if debug then
				self:debug('Decreasing Manual Duration')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_MANU
			if (HeatingTable[self.Room].HeatingType == 'Fire' or HeatingTable[self.Room].HeatingType == 'Fire-Inverter') then
				TargetString = 'Flames:   '..tostring(HeatingTable[self.Room].FlamesManu)
			else
				TargetString = ' '
			end

			DateTime = os.time()
			Duration =  math.floor((HeatingTable[self.Room].EndTimer - DateTime)/60)	-- duration left rounded to the closest minute
			if Duration % DurationManualStep == 0 then
					Duration =  Duration - DurationManualStep
			else
				Duration = Duration - (Duration % DurationManualStep)
			end

			if Duration <= 0 then		-- end of Manual mode.
				Duration = 0
			end
			DurationString = setDurationString(Duration * 60, DateTime + (Duration * 60), HeatingTable[self.Room].Mode)

			-- updates HeatingTable structure
			HeatingTable[self.Room].EndTimer = DateTime + (Duration * 60)

		elseif HeatingTable[self.Room].Mode == 'Away' then
			if debug then
				self:debug('Decreasing Away Duration')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_AWAY
			if HeatingTable[self.Room].Thermometer then
				TempTarget = HeatingTable[self.Room].TargetAway
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = 'Hors gel'
			end

			DateTime = os.time()

			if HeatingTable[self.Room].EndTimer % (DurationAwayStep * 60) == 0 then
				HeatingTable[self.Room].EndTimer = HeatingTable[self.Room].EndTimer - (DurationAwayStep * 60)
			else
				HeatingTable[self.Room].EndTimer = HeatingTable[self.Room].EndTimer - (HeatingTable[self.Room].EndTimer % (DurationAwayStep * 60))
			end
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - DateTime, HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)

		elseif HeatingTable[self.Room].Mode == 'Off' then
			if debug then self:debug('Mode Off: nothing to do')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_OFF
			TargetString = ' '
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change

		end
		
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))

-----------------------------------------Duration Up---------------------------------------------
	elseif key.elementName == '22' then
		if debug then
			self:debug('Duration up requested')
		end

		if HeatingTable[self.Room].Mode == 'Auto' then
			if debug then
				self:debug('Mode Auto: nothing to do')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_AUTO
			if HeatingTable[self.Room].Thermometer then
				TargetString = 'Target:   '..string.format('%.1f', HeatingTable[self.Room].TargetAuto)..' ºC'
			else
				TargetString = ' '
			end
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change

		elseif HeatingTable[self.Room].Mode == 'Manual' then
			if debug then
				self:debug('Increasing Manual Duration')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_MANU
			
			if (HeatingTable[self.Room].HeatingType=='Fire' or HeatingTable[self.Room].HeatingType=='Fire-Inverter') then
				TargetString = 'Flames:   '..tostring(HeatingTable[self.Room].FlamesManu)
			else
				TargetString = ' '
			end
			
			DateTime = os.time()
			Duration =  math.floor(((HeatingTable[self.Room].EndTimer - DateTime)/60) + 0.5)	-- duration left rounded to the closest minute
			Duration = Duration + DurationManualStep 
			Duration = Duration - (Duration % DurationManualStep)	-- round down the remaining duration to a multiple of the increasing step
			DurationString = setDurationString(Duration * 60, DateTime + (Duration * 60), HeatingTable[self.Room].Mode)

			-- updates HeatingTable structure
			HeatingTable[self.Room].EndTimer = DateTime + (Duration * 60)


		elseif HeatingTable[self.Room].Mode == 'Away' then
			if debug then
				self:debug('Increasing Away Duration')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_AWAY

			if HeatingTable[self.Room].Thermometer then
				TempTarget = HeatingTable[self.Room].TargetAway
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = 'Hors gel'
			end

			DateTime = os.time()
			
			HeatingTable[self.Room].EndTimer = HeatingTable[self.Room].EndTimer + (DurationAwayStep * 60)
			HeatingTable[self.Room].EndTimer = HeatingTable[self.Room].EndTimer - (HeatingTable[self.Room].EndTimer % (DurationAwayStep * 60))
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - DateTime, HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)

		elseif HeatingTable[self.Room].Mode == 'Off' then
			if debug then
				self:debug('Mode Off: nothing to do')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_OFF
			TargetString = ' '
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change

		end
		
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
		
--------------------------------------Duration Fast Up---------------------------------------------
	elseif key.elementName == '23' then
		if debug then
			self:debug('Duration fast up requested')
		end	

		if HeatingTable[self.Room].Mode == 'Auto' then
			if debug then
				self:debug('Mode Auto: nothing to do')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_AUTO
			if HeatingTable[self.Room].Thermometer then
				TargetString = 'Target:   '..string.format('%.1f', HeatingTable[self.Room].TargetAuto)..' ºC'
			else
				TargetString = ' '
			end
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change

		elseif HeatingTable[self.Room].Mode == 'Manual' then
			if debug then
				self:debug('Increasing Manual Duration fast')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_MANU
			
			if (HeatingTable[self.Room].HeatingType=='Fire' or HeatingTable[self.Room].HeatingType=='Fire-Inverter') then
				TargetString = 'Flames:   '..tostring(HeatingTable[self.Room].FlamesManu)
			else
				TargetString = ' '
			end

			DateTime = os.time()
			Duration =  math.floor(((HeatingTable[self.Room].EndTimer - DateTime)/60) + 0.5)	-- duration left rounded to the closest minute
			Duration = Duration + DurationManualHighStep 
			Duration = Duration - (Duration % DurationManualHighStep)	-- round down the remaining duration to a multiple of the increasing step
			DurationString = setDurationString(Duration * 60, DateTime + (Duration * 60), HeatingTable[self.Room].Mode)

			-- updates HeatingTable structure
			HeatingTable[self.Room].EndTimer = DateTime + (Duration * 60)


		elseif HeatingTable[self.Room].Mode == 'Away' then
			if debug then
				self:debug('Increasing Away Duration fast')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_AWAY

			if HeatingTable[self.Room].Thermometer then
				TempTarget = HeatingTable[self.Room].TargetAway
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = 'Hors gel'
			end

			DateTime = os.time()
			
			HeatingTable[self.Room].EndTimer = HeatingTable[self.Room].EndTimer + (DurationAwayHighStep * 60)
			HeatingTable[self.Room].EndTimer = HeatingTable[self.Room].EndTimer - (HeatingTable[self.Room].EndTimer % (DurationAwayStep * 60))
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - DateTime, HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)

		elseif HeatingTable[self.Room].Mode == 'Off' then
			if debug then
				self:debug('Mode Off: nothing to do')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_OFF
			TargetString = ' '
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change

		end
		
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
		
-------------------------------------- Export to all ---------------------------------------------
	elseif key.elementName == '40' then
		if debug then
			self:debug('Export to all requested')
		end

		if HeatingTable[self.Room].Mode == 'Auto' then
			if debug then
				self:debug('Mode Auto: switching all systems in Auto mode')
			end

			for room = 1, getNumberOfRooms(HeatingTable) do
				if room ~= self.Room then
					if debug then
						self:debug('Switching room '..room..' to Auto')
					end
					self:updateView("Export", "text", 'Exporting Auto mode to room '..room)
					HeatingTrigger[room].Mode = 'Auto'
					fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))
					fibaro.sleep(1*1000)
				end
			end

			self:updateView("Export", "text", ' ')

			-- updates the VD UI variables
			ModeString = MODE_STRING_AUTO
			if HeatingTable[self.Room].Thermometer then
				TargetString = 'Target:   '..string.format('%.1f', HeatingTable[self.Room].TargetAuto)..' ºC'
			else
				TargetString = ' '
			end
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change

		elseif HeatingTable[self.Room].Mode == 'Manual' then
			if debug then self:debug('Mode manual. Nothing to do')
			end

			-- updates the VD UI variables
			ModeString = MODE_STRING_MANU
			
			if (HeatingTable[self.Room].HeatingType=='Fire' or HeatingTable[self.Room].HeatingType=='Fire-Inverter') then
				TargetString = 'Flames:   '..tostring(HeatingTable[self.Room].Flames)
			else
				TargetString = ' '
			end

			DateTime = os.time()
			Duration =  math.floor(((HeatingTable[self.Room].EndTimer - DateTime)/60) + 0.5)	-- duration left rounded to the closest minute
			DurationString = setDurationString(Duration * 60, DateTime + (Duration * 60), HeatingTable[self.Room].Mode)

			-- No need to update HeatingTable structure as there is no change

		elseif HeatingTable[self.Room].Mode == 'Away' then
			if debug then
				self:debug('Mode Away: switching all systems to Away mode')
			end
			
			for room = 1, getNumberOfRooms(HeatingTable) do
				if room ~= self.Room then
					if debug then
						self:debug('Switching room '..room..' to Away')
					end
					self:updateView("Export", "text", 'Exporting Away mode to room '..room)
					HeatingTrigger[room].Mode = 'Away'
					HeatingTable[room].EndTimer = HeatingTable[self.Room].EndTimer + 60*room	-- different delays to avoid all end interrupts at the same time
					HeatingTable[room].TargetAway = HeatingTable[self.Room].TargetAway
					fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))
					fibaro.sleep(1*1000)
				end
			end
			fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))

			self:updateView("Export", "text", ' ')

			-- updates the VD UI variables
			ModeString = MODE_STRING_AWAY

			if HeatingTable[self.Room].Thermometer then
				TempTarget = HeatingTable[self.Room].TargetAway
				TargetString = 'Target:   '..string.format('%.1f', TempTarget)..' ºC'
			else
				TargetString = 'Hors gel'
			end

			DateTime = os.time()
			DurationString = setDurationString(HeatingTable[self.Room].EndTimer - DateTime, HeatingTable[self.Room].EndTimer, HeatingTable[self.Room].Mode)
			
			-- No need to update HeatingTable structure as there is no change

		elseif HeatingTable[self.Room].Mode == 'Off' then
			if debug then
				self:debug('Mode Off: switching all systems to Off mode')
			end

			for room = 1, getNumberOfRooms(HeatingTable) do
				if room ~= self.Room then
					if debug then
						self:debug('Switching room '..room..' to Off')
					end
					self:updateView("Export", "text", 'Exporting Off mode to room '..room)
					HeatingTrigger[room].Mode = 'Off'
					fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))
					fibaro.sleep(1*1000)
				end
			end
			self:updateView("Export", "text", ' ')
			self:updateView("Export", "text", ' ')

			-- updates the VD UI variables
			ModeString = self.MODE_STRING_OFF
			TargetString = ' '
			DurationString = ' '

			-- No need to update HeatingTable structure as there is no change
			
		end

-----------------------------------------Unknown key!---------------------------------------------
	else 
		if debug then
			self:debug('Unknown key requested')
		end

	end

	-------------------------------------Updating the VD display and Global Variable--------------------------------------------

	if debug then
		self:debug('Updating VD display and HEATING_DATA and HEATING_TRIGGER global variable')
	end

	if HeatingTable[self.Room].Thermometer then
		TempString = 'Temperature:   '..HeatingTable[self.Room].LastTemp..' °C'
	else
		TempString = ' '
	end
	
    self:updateView("Temp", "text", TempString)
	self:updateView("Mode", "text", ModeString)
    self:updateView("Target", "text", TargetString)
    self:updateView("Duration", "text", DurationString)
--    fibaro.emitCustomEvent("HVD")
end


function QuickApp:testCall(value)
	self:debug("Function testCall. Value = "..value)
end