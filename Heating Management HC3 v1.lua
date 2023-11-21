--[[ 	v2  2023/11/21
]]--

{
  conditions = { {
      isTrigger = true,
      operator = "anyValue",
      property = "CHECKTEMP",
      type = "global-variable"
    }, {
      isTrigger = true,
      operator = "anyValue",
      property = "HEATING_TRIGGER",
      type = "global-variable"
    }, {
      id = 0,
      isTrigger = true,
      operator = "anyValue",
      property = "value",
      type = "device"
    }, {
      id = 0,
      isTrigger = true,
      operator = "anyValue",
      property = "value",
      type = "device"
    } },
  operator = "any"
}


--[[

 Scene managing heating by the heating system in the rooms (fireplace, convector or inverter)
launched by 
- a change of the global variables HEATING_TRIGGER. This variable needs to be entered below "globals" above, or
- the change of the Global Variable CHECKTEMP (changes value when it is time to measure the temperature in the room i.e. every 5 minutes), or
- the change of the target temperature coming from the thermostat (physical) of the room. The thermostat ID needs to be inserted below "properties" above, or
- the change of a device controlled by "Alexa" for voice activation. This device Id needs to be enterered in "properties" above


Uses Global Variables:

	HEATING_TRIGGER
	HEATING_TABLE
	CHECKTEMP
	
	
HEATING_TRIGGER is the following structure transformed into a string by function json.encode for each room 
		.Mode: contains 'Auto', 'Manual', 'Away', 'Eco' or 'Off'
		.FlamesManu: integer between 0 and 9. Flames height in 'Manual' mode
		.TargetAuto: temperature target in °C (decimal number)in 'Auto' mode
		
HEATING_TABLE is the following structure transformed into a string by function json.encode for each room:
		.Mode: contains 'Auto', 'Manual', 'Away' or 'Off'
		.FlamesManu: integer between 0 and 9. Flames height in 'Manual' mode
		.TargetAuto: temperature target in °C (decimal number)in 'Auto' or 'Eco' mode
		.TargetTVD: temperature target in °C (decimal number)in 'Auto' or 'Eco' mode set by the Virtual Thermostat
		.TargetAway: temperature target in °C (decimal number)in 'Away' mode
		.Flames: integer between 0 and 9. Flames height in 'Auto' or 'Away' modes
		.EndTimer: system time at which the timer of 'Manual' mode will end (in seconds)
		.LastTemp: last measured temperature in °C (decimal number)
		.PreviousMode: mode in which the system was before going to 'Manual'
		.MoveDetectorTimer: date/time of the end of the timer after a move detection
		.VoiceActivationStatus: -1 if Flames were just switched off, +1 if Flames were just switched on, 0 otherwise
								used to set the value of the switch "VoiceActivation" in line with the flames status
								without starting the VoiceActivation process
		
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
		.LastRoom: boolean true if this is the last room
		
CHECKTEMP contains 0 or 1 and changes every x minutes (managed by the scene "Heating Timer"

--]]

-------------------------------------------------------------------------------------------------------------
----------------------------- below variables have to be adjusted -------------------------------------------
-------------------------------------------------------------------------------------------------------------

local PERIOD = 5	-- duration in minutes between 2 temperature checks. Must be the same as in "Heating Timer"


-------------------------------------------------------------------------------------------------------------
----------------------- below variables can be adjusted if wished -------------------------------------------
-------------------------------------------------------------------------------------------------------------

local debug = true	-- mode debug

local VOICE_ACTIVATION_DURATION_ON = 60	-- duration of fire_on voice activation in minutes
local VOICE_ACTIVATION_DURATION_OFF = 5	-- duration of fire_off voice activation in minutes

local PEAK_HOURS = {}	-- off peak hours in the country to use in priority to save energy
		for i = 1, 2 do
			PEAK_HOURS[i] = {}
				PEAK_HOURS[i].Off = 0
				PEAK_HOURS[i].On = 0
		end
		
PEAK_HOURS[1].Off = 02*60	-- start time of 1st off-peak period in minutes
PEAK_HOURS[1].On = 07*60	-- end time of 1st off-peak period in minutes
PEAK_HOURS[2].Off = 14*60	-- start time of 2nd off-peak period in minutes
PEAK_HOURS[2].On = 17*60	-- end time of 2nd off-peak period in minutes

local DAY_TIME_START = 07*60		-- time of start of the "day" in minutes
local DAY_TIME_END = 23*60		-- time of end of the "day" in minutes

local TempEco = 2			--  target temperature decrease except during off-peak hours for electric heating



-------------------------------------------------------------------------------------------------------------
---------------------------          no more customization below        -------------------------------------
-------------------------------------------------------------------------------------------------------------

local FLAMES_MAX = 8
local FLAMES_ECO = 9
local CONVECTOR_RATIO_MIN = 0
local CONVECTOR_RATIO_MAX = 9

local INVERTER_OFF = '0'
local INVERTER_HEAT = '1'
local INVERTER_COLD = '2'




-------------------------------------------------------------------------------------------------------------------
------------------------------------------------------- Functions -------------------------------------------------
-------------------------------------------------------------------------------------------------------------------


--[[Function:  setDurationString(duration, endTimer, mode)

Set the content of the duration string based on:
- the timer duration left (in seconds)
- the timer end time (in seconds in system time)
- the mode in which the system is (manual or away as there is no duration string for other modes)

Call: DurationString = setDurationString (duration, endTimer, mode) where DurationString is a string.

--]]

function setDurationString(duration, endTimer, mode)

	local setDurationStringDebug = false

	if setDurationStringDebug then fibaro.debug('HeatingManagement','Function setDurationString.')
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
	
		if setDurationStringDebug then fibaro.debug('HeatingManagement','DurationString = '..durationString)
		end
		return durationString

	
end	-- end of Function setDurationString

--[[getNumberOfRooms(HeatingTable)
This function checks the number of rooms with a controlled heating system

Call: numberOfRooms = getNumberOfRooms(HeatingTable)
--]]

--[[getNumberOfRooms(HeatingTable)
This function checks the number of rooms with a controlled heating system

Call: numberOfRooms = getNumberOfRooms(HeatingTable)
--]]

function getNumberOfRooms(HD)
local numberOfRooms = 0
local room, t = next(HD, nil)
while room do
	numberOfRooms = room
	room, t = next(HD, room)
end
return (numberOfRooms)
	
end -- of function getNumberOfRooms

--[[isOffPeak(timeOfTheDay)
This function checks wether time is off-peak or not
Returns true if off-peak, false otherwise

Call: offPeak = isOffPeak(timeOfTheDay) where timeOfTheDay is the time of the day in minutes
--]]

function isOffPeak(timeOfTheDay)

	for i = 1, 2 do
		if timeOfTheDay > PEAK_HOURS[1].Off and timeOfTheDay < PEAK_HOURS[1].On then
			return (true)
		end
	end
	
	return (false)
	
end -- of function isOffPeak


--[[isDayTime(timeOfTheDay)
This function checks wether time is during the day or not
Returns true if day time, false otherwise

Call: DayTime = isDayTime(timeOfTheDay) where timeOfTheDay is the time of the day in minutes
--]]

function isDayTime(timeOfTheDay)

	if timeOfTheDay > DAY_TIME_START and timeOfTheDay < DAY_TIME_END then
		return (true)
	else
		return (false)
	end
end -- of function isDayTime


--[[setConvector (room, OnOff)
This function sets the convector in room number "room" to On or Off.
It uses the "fil pilote" of the convector connected to a Fibaro switch through a diode so that when the
switch is Off, the convector is working normally, using its own thermostat to regulate the temperature, and 
when the switch is On, the "pilot wire" only sees a half alternance, putting it in "hors gel" status (maintaining
the temperature slightly above 0°C). The "logic" is thus inverted.

Call: status = setConvector(room, OnOff)
where room is the number of the room and OnOff either 'On' or 'Off' and status is true or false
--]]

function setConvector(room, OnOff)

local HD = json.decode(fibaro.getGlobalVariable('HEATING_TABLE'))


	if (OnOff == 'Off' or OnOff == 'off') then
---------------------------------------------- Off---------------------------------------------
		if debug then fibaro.debug('HeatingManagement','Switching converctor off')
		end
		fibaro.call (HD[room].PilotId, 'turnOn')	-- inverted logic

	elseif (OnOff == 'On' or OnOff == 'on') then
----------------------------------------------- On ---------------------------------------------
		if debug then fibaro.debug('HeatingManagement','Switching convector on')
		end
		fibaro.call (HD[room].PilotId, 'turnOff')	-- inverted logic
		
	else
		if debug then fibaro.debug('HeatingManagement','Wrong parameter. OnOff must contain the string On or Off')
		end
		return false
	end
	return true
end-- of function setConvector





--[[adjustConvector (room, convectorRatio, convectorRatioMax)
This function set the convectorRatio level at "convectorRatio" in the room number "room" after checking that convectorRatio is between CONVECTOR_RATIO_MIN
and convectorRatioMax.
To set the convector at convectorRatio, the function switches the convector on and programs a timer to switch it off after a time computed:
	[convectorRatio/convectorRatioMax] * PERIOD
where PERIOD is the time between 2 temperature checks.
If convectorRatio = convectorRatioMax, then the function does not program a timer, thus the convector is always on.
If convectorRatio = 0, then the function switches off the convector that will remain off until the next temperature check
Otherwise, the convector will be switched on the percentage of time defined by [convectorRatio/convectorRatioMax]
--]]

function adjustConvector(room, convectorRatio, convectorRatioMax)

local HD = json.decode(fibaro.getGlobalVariable('HEATING_TABLE'))

	if (convectorRatio > convectorRatioMax) then
		convectorRatio = convectorRatioMax
	end
	if (convectorRatio < CONVECTOR_RATIO_MIN) then
		convectorRatio = CONVECTOR_RATIO_MIN
	end
	if debug then
		fibaro.debug('HeatingManagement','AdjustConvector fct: Setting convectorRatio level in room number '..room..' at '..convectorRatio..'. ConvectorId = '..HD[room].PilotId)
	end

	if (convectorRatio == 0) then
		if debug then fibaro.debug('HeatingManagement','AdjustConvector fct: Switching off convectorRatio.')
		end
		setConvector(room, 'off')

    else
		if debug then
		fibaro.debug('HeatingManagement','AdjustConvector fct: Changing Convector setting at '..convectorRatio)
		end
		setConvector(room, 'on')
		if convectorRatio < convectorRatioMax then	
			-- use of the setTimeout function which is: setTimeout(function, timer)
			-- here, we use the anonymous function: [function() <code here> end] in order to be able to pass parameters (here, 'room' and 'off')
			-- The duration of the timer is linked with the duration between 2 "CHECKTEMP"
			setTimeout(	function()
							setConvector(room, 'off')
						end,
						math.floor(convectorRatio * PERIOD *60*1000/convectorRatioMax))
		end
				
	end
	
	return true
end		-- end of Function adjustConvector




--[[computeConvectorAdjustment (targetTemp, previousTemp, temp)
This function computes the convector-on ratio adjustment to be applied

Call: DeltaConvectorRatio = computeConvectorAdjustment (targetTemp, previousTemp, temp)
where temp is the last measured temperature, previousTemp the previously measured temperature and targetTemp the temperature target in the room.
--]]

function computeConvectorAdjustment (targetTemp, previousTemp, temp)

local DELTA_TEMP_REF_UP = 0.04		-- change of temperature in Celsius over 5 minutes: considered as fast above and slow below for increase
local DELTA_TEMP_REF_DOWN = 0.02	-- change of temperature in Celsius over 5 minutes: considered as fast above and slow below for decrease
local STEP_1 = 1/4				-- temperature steps to decide on the heating algorithm
local STEP_2 = 1/2
local STEP_3 = 1
local DELTA_RATIO_MIN = -100
local DELTA_RATIO_MAX = 100

local deltaConvectorRatio = 0

---------------------------------------------------------------------------------------------------------------------------------------------
--			Parametrage selon tableau PPT                                                                  
---------------------------------------------------------------------------------------------------------------------------------------------

local IFP4 = DELTA_RATIO_MIN
local IFP3 = DELTA_RATIO_MIN
local IFP2 = -1
local IFP1 = -1
local IFM1 = -2
local IFM2 = -2
local IFM3 = -1
local IFM4 = DELTA_RATIO_MAX

local ISP4 = DELTA_RATIO_MIN
local ISP3 = -1
local ISP2 = -1
local ISP1 = -1
local ISM1 = 0
local ISM2 = 0
local ISM3 = 1
local ISM4 = DELTA_RATIO_MAX

local DSP4 = DELTA_RATIO_MIN
local DSP3 = -1
local DSP2 = 0
local DSP1 = 0
local DSM1 = 1
local DSM2 = 2
local DSM3 = DELTA_RATIO_MAX
local DSM4 = DELTA_RATIO_MAX

local DFP4 = DELTA_RATIO_MIN
local DFP3 = 1
local DFP2 = 2
local DFP1 = 2
local DFM1 = 1
local DFM2 = 2
local DFM3 = DELTA_RATIO_MAX
local DFM4 = DELTA_RATIO_MAX


	if not temp then
		temp = previousTemp
	end
	
	if debug then
        fibaro.debug('HeatingManagement','computeConvectorAdjustment fct; target = '..targetTemp..', previous temp = '..previousTemp..', temp = '..temp)
	end

	if (temp > previousTemp) then
-------------------------------------------- the temperature in the room is increasing ---------------------------------
		if debug then
			fibaro.debug('HeatingManagement','ComputeConvectorAdjustment fct: Room temperature is increasing')
		end

		if ((temp - previousTemp) > DELTA_TEMP_REF_UP) then --fast increase: 
			if debug then
				fibaro.debug('HeatingManagement','ComputeConvectorAdjustment fct: Fast increase.')
			end 
			if ((temp - targetTemp) > STEP_3) then
				deltaConvectorRatio = IFP4
			elseif ((temp - targetTemp) > STEP_2) then 
				deltaConvectorRatio = IFP3
			elseif ((temp - targetTemp) > STEP_1) then 
				deltaConvectorRatio = IFP2
			elseif ((temp - targetTemp) > 0) then 
				deltaConvectorRatio = IFP1
			elseif ((targetTemp - temp) < STEP_1) then 
				deltaConvectorRatio = IFM1
			elseif ((targetTemp - temp) < STEP_2) then 
				deltaConvectorRatio = IFM2
			elseif ((targetTemp - temp) < STEP_3) then 
				deltaConvectorRatio = IFM3
			else
				deltaConvectorRatio = IFM4
			end	
			
		else			-- slow increase
			if debug then
				fibaro.debug('HeatingManagement','ComputeConvectorAdjustment fct: Slow increase.')
			end 
			if ((temp - targetTemp) > STEP_3) then
				deltaConvectorRatio = ISP4
			elseif ((temp - targetTemp) > STEP_2) then 
				deltaConvectorRatio = ISP3
			elseif ((temp - targetTemp) > STEP_1) then 
				deltaConvectorRatio = ISP2
			elseif ((temp - targetTemp) > 0) then 
				deltaConvectorRatio = ISP1
			elseif ((targetTemp - temp) < STEP_1) then 
				deltaConvectorRatio = ISM1
			elseif ((targetTemp - temp) < STEP_2) then 
				deltaConvectorRatio = ISM2
			elseif ((targetTemp - temp) < STEP_3) then 
				deltaConvectorRatio = ISM3
			else
				deltaConvectorRatio = ISM4
			end
		end


	else
-------------------------------------------- the temperature in the room is decreasing ---------------------------------
		if debug then
			fibaro.debug('HeatingManagement','ComputeConvectorAdjustment fct: Room temperature is decreasing')
		end

		if ((previousTemp - temp) > DELTA_TEMP_REF_DOWN) then --fast decrease: 
			if debug then
				fibaro.debug('HeatingManagement','ComputeConvectorAdjustment fct: Fast decrease.')
			end 
			if ((temp - targetTemp) > STEP_3) then
				deltaConvectorRatio = DFP4
			elseif ((temp - targetTemp) > STEP_2) then 
				deltaConvectorRatio = DFP3
			elseif ((temp - targetTemp) > STEP_1) then 
				deltaConvectorRatio = DFP2
			elseif ((temp - targetTemp) > 0) then 
				deltaConvectorRatio = DFP1
			elseif ((targetTemp - temp) < STEP_1) then 
				deltaConvectorRatio = DFM1
			elseif ((targetTemp - temp) < STEP_2) then 
				deltaConvectorRatio = DFM2
			elseif ((targetTemp - temp) < STEP_3) then 
				deltaConvectorRatio = DFM3
			else
				deltaConvectorRatio = DFM4
			end	

		else			-- slow decrease
			if debug then
				fibaro.debug('HeatingManagement','ComputeConvectorAdjustment fct: Slow decrease.')
			end 
			if ((temp - targetTemp) > STEP_3) then
				deltaConvectorRatio = DSP4
			elseif ((temp - targetTemp) > STEP_2) then 
				deltaConvectorRatio = DSP3
			elseif ((temp - targetTemp) > STEP_1) then 
				deltaConvectorRatio = DSP2
			elseif ((temp - targetTemp) > 0) then 
				deltaConvectorRatio = DSP1
			elseif ((targetTemp - temp) < STEP_1) then 
				deltaConvectorRatio = DSM1
			elseif ((targetTemp - temp) < STEP_2) then 
				deltaConvectorRatio = DSM2
			elseif ((targetTemp - temp) < STEP_3) then 
				deltaConvectorRatio = DSM3
			else
				deltaConvectorRatio = DSM4
			end
		end
	end
	if debug then
		fibaro.debug('HeatingManagement','ComputeConvectorAdjustment fct: deltaConvectorRatio = '..deltaConvectorRatio)
	end 
	return deltaConvectorRatio
	
end	--end of function computeConvectorAdjustment




--[[setUpRelay (room, OnOff)
This function sets the relay to On or Off

Call: status = setUpRelay(room, OnOff)
where room is the number of the room and OnOff either 'On' or 'Off' and status is true or false
--]]

function setUpRelay(room, OnOff)

local OFF = 0
local ON = 255

local HD = json.decode(fibaro.getGlobalVariable('HEATING_TABLE'))


	if (OnOff == 'Off') then
-----------------------------------------------Off---------------------------------------------
		if debug then
			fibaro.debug('HeatingManagement','Fct setUpRelay. Off mode requested')
			fibaro.debug('HeatingManagement','Fct setUpRelay. Flames Id = '..HD[room].FlamesId)
--			fibaro.debug('HeatingManagement','Setting R1 to Reset i.e. no signal transmitted to O+ & O-')
		end
	fibaro.call (HD[room].FlamesId, 'setR', ON)
	fibaro.sleep (500)
	fibaro.call (HD[room].FlamesId, 'setR', OFF)
	
	HD[room].VoiceActivationStatus = -1		-- indicates that the VoiceActivation switch will be turned off	by the scene
	fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HD))
	fibaro.call (HD[room].VoiceActivationId, 'turnOff')	-- switch off VoiceActivation switch

-----------------------------------------------Auto---------------------------------------------
	elseif (OnOff == 'On') then
		if debug then
			fibaro.debug('HeatingManagement','Fct setUpRelay. Non-Off mode requested')
--			fibaro.debug('HeatingManagement','Setting R1 to Set i.e. signal transmitted to O+ & O-')
		end
		fibaro.call (HD[room].FlamesId, 'setG', ON)
		fibaro.sleep (500)
		fibaro.call (HD[room].FlamesId, 'setG', OFF)
		
	else
		if debug then
			fibaro.debug('HeatingManagement','Fct setUpRelay. Wrong parameter. OnOff must contain the string On or Off')
		end
		return false
	end
	return true
end-- of function setUpRelay





--[[adjustFlames (room, flames, flamesMax)
This function set the flames level at "flames" in the room number "room" after checking that flames is between 0 and flamesMax
--]]

function adjustFlames(room, flames, flamesMax, previousFlames)

local FLAMES_OFF = 84  -- command to fully switch off the fire
local FLAMES_OFF_AMBERS_ON = 116  -- command to switch off the fire but light the ambers
local FLAMES_SETTING = {123, 138, 153, 168, 182, 200, 220, 235, 250}

local HD = json.decode(fibaro.getGlobalVariable('HEATING_TABLE'))

	if (flames > flamesMax) then
		flames = flamesMax
	end
	if (flames < 0) then
		flames = 0
	end
	if debug then
		fibaro.debug('HeatingManagement','AdjustFlames fct: Setting flames level in room number '..room..' at '..flames..'. FlamesId = '..HD[room].FlamesId)
	end
	
	if ((previousFlames == 0) and (flames == 1)) then
		if debug then
			fibaro.debug('HeatingManagement','AdjustFlames fct: Switching Fireplace on at '..flames..'. Flames at 3.')
		end
		
		HD[room].VoiceActivationStatus = 1		-- indicates that the VoiceActivation switch will be turned on by the scene
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HD))
		fibaro.call (HD[room].VoiceActivationId, 'turnOn')	-- switch on VoiceActivation switch	to reflect the Flames status
		
		fibaro.call (HD[room].FlamesId, 'setW', FLAMES_SETTING [3])

	elseif (flames == 0) then
		if debug then fibaro.debug('HeatingManagement','AdjustFlames fct: Switching off flames. FlamesSetting = 0')
		end
		
		HD[room].VoiceActivationStatus = -1		-- indicates that the VoiceActivation switch will be turned off	by the scene
		fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HD))
		fibaro.call (HD[room].VoiceActivationId, 'turnOff')	-- switch off VoiceActivation switch
		
		fibaro.call (HD[room].FlamesId, 'setW', FLAMES_OFF)

    else
		if debug then fibaro.debug('HeatingManagement','AdjustFlames fct: Changing Flames setting at '..flames..' FlamesSetting = '..FLAMES_SETTING [flames])
		end
		fibaro.call (HD[room].FlamesId, 'setW', FLAMES_SETTING [flames])
	end
	
	return true
end		-- end of Function adjustFlames



--[[computeFlamesAdjustment (targetTemp, previousTemp, temp)
This function computes the flames level adjustment to be applied

Call: DeltaFlames = computeFlamesAdjustment (targetTemp, previousTemp, temp)
where temp is the last measured temperature, previousTemp the previously measured temperature and targetTemp the temperature target in the room.
--]]

function computeFlamesAdjustment (targetTemp, previousTemp, temp)

local DELTA_TEMP_REF_UP = 0.04		-- change of temperature in Celsius over 5 minutes: considered as fast above and slow below for increase
local DELTA_TEMP_REF_DOWN = 0.02	-- change of temperature in Celsius over 5 minutes: considered as fast above and slow below for increase
local STEP_1 = 1/4				-- temperature steps to decide on the heating algorithm
local STEP_2 = 1/2
local STEP_3 = 1
local FLAMES_MIN = -100
local FLAMES_MAX = 100

---------------------------------------------------------------------------------------------------------------------------------------------
--			Parametrage selon tableau PPT                                                                  
---------------------------------------------------------------------------------------------------------------------------------------------

local IFP4 = FLAMES_MIN
local IFP3 = FLAMES_MIN
local IFP2 = -1
local IFP1 = -1
local IFM1 = -2
local IFM2 = -2
local IFM3 = -1
local IFM4 = FLAMES_MAX

local ISP4 = FLAMES_MIN
local ISP3 = -1
local ISP2 = -1
local ISP1 = -1
local ISM1 = 0
local ISM2 = 0
local ISM3 = 1
local ISM4 = FLAMES_MAX

local DSP4 = FLAMES_MIN
local DSP3 = -1
local DSP2 = 0
local DSP1 = 0
local DSM1 = 1
local DSM2 = 2
local DSM3 = FLAMES_MAX
local DSM4 = FLAMES_MAX

local DFP4 = FLAMES_MIN
local DFP3 = 1
local DFP2 = 2
local DFP1 = 2
local DFM1 = 1
local DFM2 = 2
local DFM3 = FLAMES_MAX
local DFM4 = FLAMES_MAX


	if not temp then
		temp = previousTemp
	end
	
	if debug then
        fibaro.debug('HeatingManagement','computeFlamesAdjustment fct; target = '..targetTemp..', previous temp = '..previousTemp..', temp = '..temp)
	end

	if (temp > previousTemp) then
-------------------------------------------- the temperature in the room is increasing ---------------------------------
		if debug then
			fibaro.debug('HeatingManagement','ComputeFlamesAdjustment fct: Room temperature is increasing')
		end

		if ((temp - previousTemp) > DELTA_TEMP_REF_UP) then --fast increase: 
			if debug then
				fibaro.debug('HeatingManagement','ComputeFlamesAdjustment fct: Fast increase.')
			end 
			if ((temp - targetTemp) > STEP_3) then
				deltaFlames = IFP4
			elseif ((temp - targetTemp) > STEP_2) then 
				deltaFlames = IFP3
			elseif ((temp - targetTemp) > STEP_1) then 
				deltaFlames = IFP2
			elseif ((temp - targetTemp) > 0) then 
				deltaFlames = IFP1
			elseif ((targetTemp - temp) < STEP_1) then 
				deltaFlames = IFM1
			elseif ((targetTemp - temp) < STEP_2) then 
				deltaFlames = IFM2
			elseif ((targetTemp - temp) < STEP_3) then 
				deltaFlames = IFM3
			else
				deltaFlames = IFM4
			end	
			
		else			-- slow increase
			if debug then
				fibaro.debug('HeatingManagement','ComputeFlamesAdjustment fct: Slow increase.')
			end 
			if ((temp - targetTemp) > STEP_3) then
				deltaFlames = ISP4
			elseif ((temp - targetTemp) > STEP_2) then 
				deltaFlames = ISP3
			elseif ((temp - targetTemp) > STEP_1) then 
				deltaFlames = ISP2
			elseif ((temp - targetTemp) > 0) then 
				deltaFlames = ISP1
			elseif ((targetTemp - temp) < STEP_1) then 
				deltaFlames = ISM1
			elseif ((targetTemp - temp) < STEP_2) then 
				deltaFlames = ISM2
			elseif ((targetTemp - temp) < STEP_3) then 
				deltaFlames = ISM3
			else
				deltaFlames = ISM4
			end
		end


	else
-------------------------------------------- the temperature in the room is decreasing ---------------------------------
		if debug then
			fibaro.debug('HeatingManagement','ComputeFlamesAdjustment fct: Room temperature is decreasing')
		end

		if ((previousTemp - temp) > DELTA_TEMP_REF_DOWN) then --fast decrease: 
			if debug then
				fibaro.debug('HeatingManagement','ComputeFlamesAdjustment fct: Fast decrease.')
			end 
			if ((temp - targetTemp) > STEP_3) then
				deltaFlames = DFP4
			elseif ((temp - targetTemp) > STEP_2) then 
				deltaFlames = DFP3
			elseif ((temp - targetTemp) > STEP_1) then 
				deltaFlames = DFP2
			elseif ((temp - targetTemp) > 0) then 
				deltaFlames = DFP1
			elseif ((targetTemp - temp) < STEP_1) then 
				deltaFlames = DFM1
			elseif ((targetTemp - temp) < STEP_2) then 
				deltaFlames = DFM2
			elseif ((targetTemp - temp) < STEP_3) then 
				deltaFlames = DFM3
			else
				deltaFlames = DFM4
			end	

		else			-- slow decrease
			if debug then
				fibaro.debug('HeatingManagement','ComputeFlamesAdjustment fct: Slow decrease.')
			end 
			if ((temp - targetTemp) > STEP_3) then
				deltaFlames = DSP4
			elseif ((temp - targetTemp) > STEP_2) then 
				deltaFlames = DSP3
			elseif ((temp - targetTemp) > STEP_1) then 
				deltaFlames = DSP2
			elseif ((temp - targetTemp) > 0) then 
				deltaFlames = DSP1
			elseif ((targetTemp - temp) < STEP_1) then 
				deltaFlames = DSM1
			elseif ((targetTemp - temp) < STEP_2) then 
				deltaFlames = DSM2
			elseif ((targetTemp - temp) < STEP_3) then 
				deltaFlames = DSM3
			else
				deltaFlames = DSM4
			end
		end
	end
	if debug then
		fibaro.debug('HeatingManagement','ComputeFlamesAdjustment fct: deltaFlames = '..deltaFlames)
	end 
	return deltaFlames
	
end	--end of function computeFlamesAdjustment



-------------------------------------------------------------------------------------------------------------------
--------------------------------------------------- End of functions ----------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------


local Flames, DeltaFlames = 0
local ConvectorRatio, DeltaConvectorRatio = 0
local TargetTemp, MeasuredTemp, LastMeasuredTemp = 0
local RoomNumber = 0
local RoomName = ' '
local Trigger = 'TRIGGER'
local FireInverterMode = ' '


local HeatingTable = json.decode(fibaro.getGlobalVariable('HEATING_TABLE'))
local HeatingTrigger = json.decode(fibaro.getGlobalVariable('HEATING_TRIGGER'))

local NumberOfRooms = getNumberOfRooms(HeatingTable)
if debug then
	fibaro.debug('HeatingManagement','\n\nBeginning of the scene.\n')
	fibaro.debug('HeatingManagement','Number of Rooms = '..NumberOfRooms)
end

local Source = sourceTrigger -- Source of the trigger
local DateTime = os.date("*t", os.time())
local Time = (DateTime.hour * 60) + DateTime.min

if debug then 
    fibaro.debug('HeatingManagement','Trigger = '..json.encode(Source))
end	

if Source.type == 'property' then
-------------------------------------------------------------------------------------------------------------------
------------------ Trigger is a change of a device property. Coming from the thermostats or voice activation ------
-------------------------------------------------------------------------------------------------------------------

	if debug then
		fibaro.debug('HeatingManagement','Trigger = Property.')
	end	

	local TriggerID = tonumber (Source.deviceID)
	
	RoomNumber = 0
	for i = 1, NumberOfRooms do		-- looking for the room which voice activation device would have triggererd the scene
		if TriggerID == HeatingTable[i].VoiceActivationId then
			RoomNumber = i
		end
	end
	
	if RoomNumber ~= 0 then	
	
-------------------------------------------------------------------------------------------------------------------
------------------ Trigger is a change of a device property coming from  voice activation -------------------------
-------------------------------------------------------------------------------------------------------------------
														
		RoomName = HeatingTable[RoomNumber].RoomName
		if debug then
			fibaro.debug('HeatingManagement','Voice activation of the fire in room '..RoomName)
		end
		
		if HeatingTable[RoomNumber].VoiceActivationStatus ~= 0 then		-- VoiceActivationStatus is not 0. So the switch was modified to reflect the status
																		-- of the Flames (switched off or on by the scene) and not by voice activation
			if debug then
				fibaro.debug('HeatingManagement','VoiceActivationStatus is: '..HeatingTable[RoomNumber].VoiceActivationStatus..'. Aborting.')
			end
			HeatingTable[RoomNumber].VoiceActivationStatus = 0	-- Reset VoiceActivationStatus
			fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
--			fibaro.abort()
			fibaro.scene('kill', sceneId)
		end		

		if HeatingTable[RoomNumber].HeatingType == 'Fire' or HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' then
			
			local ValueSwitch = tonumber(fibaro.getValue(TriggerID, 'value'))
			if debug then
				fibaro.debug('HeatingManagement','Switch feu in room '..RoomName..' at '..ValueSwitch)
			end
			if  ValueSwitch == 0 then	-- swithing fire off for VOICE_ACTIVATION_DURATION_OFF
				if debug then
					fibaro.debug('HeatingManagement','Switching fire off for '..VOICE_ACTIVATION_DURATION_OFF..' min in room '..RoomName)
				end
				HeatingTrigger[RoomNumber].FlamesManu = 0
				HeatingTable[RoomNumber].EndTimer = os.time()+ VOICE_ACTIVATION_DURATION_OFF * 60
			else
				if debug then
					fibaro.debug('HeatingManagement','Switching fire on for '..VOICE_ACTIVATION_DURATION_ON..' min in room '..RoomName)
				end
				HeatingTable[RoomNumber].EndTimer = os.time() + VOICE_ACTIVATION_DURATION_ON * 60	-- setting the duration of the fire
				HeatingTrigger[RoomNumber].Mode = 'Manual'		-- switching to "manual" mode
				HeatingTrigger[RoomNumber].FlamesManu = FLAMES_ECO
			end
			fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
			fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))
		end	-- end if heating type is "Fire"
		
		
	else	-- trigger was not a voice activation device			

	
		RoomNumber = 0
		for i = 1, NumberOfRooms do		-- looking for the room which thermostat would have triggererd the scene
			if TriggerID == HeatingTable[i].ThermostatId then
				RoomNumber = i
			end
		end
		
		if RoomNumber ~= 0 then

-------------------------------------------------------------------------------------------------------------------
------------------ Trigger is a change of a device property coming from a thermostat   ----------------------------
-------------------------------------------------------------------------------------------------------------------	

		
			if debug then
				fibaro.debug('HeatingManagement','The scene was launched from Thermostat in room '..HeatingTable[RoomNumber].RoomName)
			end	
			
			HeatingTrigger[RoomNumber].TargetAuto = fibaro.getValue (TriggerID, 'value')	-- get the new target temperature
			fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))	-- save it in HEATING_TRIGGER to relaunch the scene
		else

-------------------------------------------------------------------------------------------------------------------
------------------ Trigger is neither coming from a thermostat nor a voice activation device  ---------------------
-------------------------------------------------------------------------------------------------------------------			
			
			if debug then
				fibaro.debug('HeatingManagement','The scene was launched neither from a Thermostat nor from a voice activation device. Aborting')
			end	
			fibaro.scene('kill', sceneId)
		end
	end


elseif Source.type == 'global-variable' then 
-------------------------------------------------------------------------------------------------------------------
------------------------------------ Trigger is a change in a global variable -------------------------------------
-------------------------------------------------------------------------------------------------------------------

	if debug then
		fibaro.debug('HeatingManagement','Trigger = global-variable')
	end


	if Source.property == 'CHECKTEMP' then 

-------------------------------------------------------------------------------------------------------------------
------------------------- Trigger is a request to check temperature in the room -----------------------------------
-------------------------------------------------------------------------------------------------------------------

		if debug then
			fibaro.debug('HeatingManagement','Room temperature measurement requested')
		end
		
		for RoomNumber = 1, NumberOfRooms do
			RoomName = HeatingTable[RoomNumber].RoomName
			if HeatingTable[RoomNumber].Thermometer then
                if debug then  
					fibaro.debug('HeatingManagement','Thermometer Id = '..HeatingTable[RoomNumber].ThermometerId)
                end
				MeasuredTemp = tonumber (fibaro.getValue (HeatingTable[RoomNumber].ThermometerId, 'value'))
				MeasuredTemp = (math.floor((MeasuredTemp * 100) + 0.5)) / 100	-- rounding Measured temp to the closest 2nd decimal
				LastMeasuredTemp = HeatingTable[RoomNumber].LastTemp
				HeatingTable[RoomNumber].LastTemp = MeasuredTemp	--put the new measured temperature in the global variable
			
				if debug then
					fibaro.debug('HeatingManagement', 'New '..RoomName..' room temperature is '..MeasuredTemp)
					fibaro.debug('HeatingManagement', 'Previous temperature was '..LastMeasuredTemp)
				end
			end

----------------------------- only adjust heating system if Auto, Eco or Away mode ----------------------------------------------	
---------------------------------------------- Auto mode ------------------------------------------------------------------------			
			if HeatingTable[RoomNumber].Mode == 'Auto' then

				TargetTemp = HeatingTable[RoomNumber].TargetAuto
				
				if HeatingTable[RoomNumber].Thermometer then
					if HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' then
						if (isOffPeak(Time) and (not isDayTime(Time))) then	-- off-peak period not during the day
							FireInverterMode = 'Inverter'
							HeatingTable[RoomNumber].PreviousInverterMode = 'Inverter'
						else
							FireInverterMode = 'Fire'
							if HeatingTable[RoomNumber].PreviousInverterMode == 'Inverter' then
								fibaro.call(HeatingTable[RoomNumber].IRIdMode1, "setMode", INVERTER_OFF)
								if HeatingTable[RoomNumber].IRIdMode2 ~= 0 then	-- 2 inverters in the room
									fibaro.call(HeatingTable[RoomNumber].IRIdMode2, "setMode", INVERTER_OFF)
								end
								HeatingTable[RoomNumber].PreviousInverterMode = 'Fire'
							end
						end
					end

					if (HeatingTable[RoomNumber].HeatingType == 'Fire') 
						or (HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' and FireInverterMode == 'Fire') then
						
						DeltaFlames = computeFlamesAdjustment ( TargetTemp, LastMeasuredTemp, MeasuredTemp)
						Flames = HeatingTable[RoomNumber].Flames + DeltaFlames
				
						if debug then
							fibaro.debug('HeatingManagement','Target temperature is '..TargetTemp..', Previous Flames = '..HeatingTable[RoomNumber].Flames..', New Flames = '..Flames..', DeltaFlames = '..DeltaFlames)
						end
						if (Flames > FLAMES_MAX) then
							Flames = FLAMES_MAX
						end
						if (Flames < 0) then
							Flames = 0
						end
						adjustFlames(RoomNumber, Flames, FLAMES_MAX, HeatingTable[RoomNumber].Flames)
						HeatingTable[RoomNumber].Flames = Flames
						
						
					elseif (HeatingTable[RoomNumber].HeatingType == 'Inverter')
						or (HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' and FireInverterMode == 'Inverter') then
						fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", HeatingTable[RoomNumber].TargetTemp)
						if HeatingTable[RoomNumber].IRIdTemp2 ~= 0 then	-- 2 inverters in the room
							fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", HeatingTable[RoomNumber].TargetTemp)
						end
					
					
					elseif (HeatingTable[RoomNumber].HeatingType == 'Convector') then

						DeltaConvectorRatio = computeConvectorAdjustment ( TargetTemp, LastMeasuredTemp, MeasuredTemp)
						ConvectorRatio = HeatingTable[RoomNumber].Flames + DeltaConvectorRatio
				
						if debug then
							fibaro.debug('HeatingManagement','Target temperature is '..TargetTemp..', Previous ConvectorRatio = '..HeatingTable[RoomNumber].Flames..', New ConvectorRatio = '..ConvectorRatio..', DeltaConvectorRatio = '..DeltaConvectorRatio)
						end
						if (ConvectorRatio >= CONVECTOR_RATIO_MAX) then
							ConvectorRatio = CONVECTOR_RATIO_MAX
							setConvector(RoomNumber, 'On')
						elseif (ConvectorRatio <= CONVECTOR_RATIO_MIN) then
							ConvectorRatio = CONVECTOR_RATIO_MIN
							setConvector(RoomNumber, 'Off')
						else
							adjustConvector(RoomNumber, ConvectorRatio, CONVECTOR_RATIO_MAX)
						end
						HeatingTable[RoomNumber].Flames = ConvectorRatio
						
					end
				else
					if debug then  
					fibaro.debug('HeatingManagement','Thermometer Id = '..HeatingTable[RoomNumber].ThermometerId)
                end
				MeasuredTemp = tonumber (fibaro.getValue (HeatingTable[RoomNumber].ThermometerId, 'value'))
				MeasuredTemp = (math.floor((MeasuredTemp * 100) + 0.5)) / 100	-- rounding Measured temp to the closest 2nd decimal
				LastMeasuredTemp = HeatingTable[RoomNumber].LastTemp
				HeatingTable[RoomNumber].LastTemp = MeasuredTemp	--put the new measured temperature in the global variable
			
				if debug then
					fibaro.debug('HeatingManagement', 'New '..RoomName..' room temperature is '..MeasuredTemp)
					fibaro.debug('HeatingManagement', 'Previous temperature was '..LastMeasuredTemp)
				end
			end

----------------------------- only adjust heating system if Auto, Eco or Away mode ----------------------------------------------	
---------------------------------------------- Auto mode ------------------------------------------------------------------------			
			if HeatingTable[RoomNumber].Mode == 'Auto' then

				TargetTemp = HeatingTable[RoomNumber].TargetAuto
				
				if HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' then
					if (isOffPeak(Time) and (not isDayTime(Time))) then	-- off-peak period not during the day
						FireInverterMode = 'Inverter'
						HeatingTable[RoomNumber].PreviousInverterMode = 'Inverter'
					else
						FireInverterMode = 'Fire'
						if HeatingTable[RoomNumber].PreviousInverterMode == 'Inverter' then
							fibaro.call(HeatingTable[RoomNumber].IRIdMode1, "setMode", INVERTER_OFF)
							if HeatingTable[RoomNumber].IRIdMode2 ~= 0 then	-- 2 inverters in the room
								fibaro.call(HeatingTable[RoomNumber].IRIdMode2, "setMode", INVERTER_OFF)
							end
							HeatingTable[RoomNumber].PreviousInverterMode = 'Fire'
						end
					end
				end

				if (HeatingTable[RoomNumber].HeatingType == 'Fire') 
					or (HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' and FireInverterMode == 'Fire') then
					
					DeltaFlames = computeFlamesAdjustment ( TargetTemp, LastMeasuredTemp, MeasuredTemp)
					Flames = HeatingTable[RoomNumber].Flames + DeltaFlames
			
					if debug then
						fibaro.debug('HeatingManagement','Target temperature is '..TargetTemp..', Previous Flames = '..HeatingTable[RoomNumber].Flames..', New Flames = '..Flames..', DeltaFlames = '..DeltaFlames)
					end
					if (Flames > FLAMES_MAX) then
						Flames = FLAMES_MAX
					end
					if (Flames < 0) then
						Flames = 0
					end
					adjustFlames(RoomNumber, Flames, FLAMES_MAX, HeatingTable[RoomNumber].Flames)
					HeatingTable[RoomNumber].Flames = Flames
					
					
				elseif (HeatingTable[RoomNumber].HeatingType == 'Inverter')
					or (HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' and FireInverterMode == 'Inverter') then
					fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", HeatingTable[RoomNumber].TargetTemp)
					if HeatingTable[RoomNumber].IRIdTemp2 ~= 0 then	-- 2 inverters in the room
						fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", HeatingTable[RoomNumber].TargetTemp)
					end
				
				
				elseif (HeatingTable[RoomNumber].HeatingType == 'Convector') then
					if HeatingTable[RoomNumber].Thermometer then
						DeltaConvectorRatio = computeConvectorAdjustment ( TargetTemp, LastMeasuredTemp, MeasuredTemp)
						ConvectorRatio = HeatingTable[RoomNumber].Flames + DeltaConvectorRatio
				
						if debug then
							fibaro.debug('HeatingManagement','Target temperature is '..TargetTemp..', Previous ConvectorRatio = '..HeatingTable[RoomNumber].Flames..', New ConvectorRatio = '..ConvectorRatio..', DeltaConvectorRatio = '..DeltaConvectorRatio)
						end
						if (ConvectorRatio >= CONVECTOR_RATIO_MAX) then
							ConvectorRatio = CONVECTOR_RATIO_MAX
							setConvector(RoomNumber, 'On')
						elseif (ConvectorRatio <= CONVECTOR_RATIO_MIN) then
							ConvectorRatio = CONVECTOR_RATIO_MIN
							setConvector(RoomNumber, 'Off')
						else
							adjustConvector(RoomNumber, ConvectorRatio, CONVECTOR_RATIO_MAX)
						end
						HeatingTable[RoomNumber].Flames = ConvectorRatio
					else	-- no thermometer in the room. Switching the convector on or off
						if TargetTemp == 'OFF' then
							if debug then
								fibaro.debug('HeatingManagement','Target temperature is '..TargetTemp..'. Switching-off convector ')
							end
							setConvector(RoomNumber, 'Off')
						else
							if debug then
								fibaro.debug('HeatingManagement','Target temperature is '..TargetTemp..'. Switching-on convector ')
							end
							setConvector(RoomNumber, 'On')
						end
					end
				end
					
				
---------------------------------------------- Eco mode ------------------------------------------------------------------------			
			elseif HeatingTable[RoomNumber].Mode == 'Eco' then

				TargetTemp = HeatingTable[RoomNumber].TargetAuto
				if (HeatingTable[RoomNumber].HeatingType == 'Fire') or (not isOffPeak(Time)) then	
					-- in Eco mode, the target temperature is decreased by TempEco degrees unless in off-peak hours for electric heating
					TargetTemp = TargetTemp - TempEco
				end

				if (HeatingTable[RoomNumber].HeatingType == 'Fire') then
					DeltaFlames = computeFlamesAdjustment ( TargetTemp, LastMeasuredTemp, MeasuredTemp)
					Flames = HeatingTable[RoomNumber].Flames + DeltaFlames
			
					if debug then
						fibaro.debug('HeatingManagement','Target temperature is '..TargetTemp..', Previous Flames = '..HeatingTable[RoomNumber].Flames..', New Flames = '..Flames..', DeltaFlames = '..DeltaFlames)
					end
					if (Flames > FLAMES_MAX) then
						Flames = FLAMES_MAX
					end
					if (Flames < 0) then
						Flames = 0
					end
					adjustFlames(RoomNumber, Flames, FLAMES_MAX, HeatingTable[RoomNumber].Flames)
					HeatingTable[RoomNumber].Flames = Flames
					
					
				elseif (HeatingTable[RoomNumber].HeatingType == 'Inverter') or (HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter') then
					-- Fire-Inverter always in Inverter mode in Eco mode
					fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", TargetTemp)
					if HeatingTable[RoomNumber].IRIdTemp2 ~= 0 then	-- 2 inverters in the room
						fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", TargetTemp)
					end
				
				elseif HeatingTable[RoomNumber].HeatingType == 'Convector' then
					if HeatingTable[RoomNumber].Thermometer then	
						DeltaConvectorRatio = computeConvectorAdjustment ( HeatingTable[RoomNumber].TargetAuto, HeatingTable[RoomNumber].LastTemp)
						ConvectorRatio = HeatingTable[RoomNumber].Flames + DeltaConvectorRatio
				
						if debug then
							fibaro.debug('HeatingManagement','Target temperature is '..HeatingTable[RoomNumber].TargetAuto..', Previous ConvectorRatio = '
								..HeatingTable[RoomNumber].Flames..', New ConvectorRatio = '..ConvectorRatio..', DeltaConvectorRatio = '..DeltaConvectorRatio)
						end
						if (ConvectorRatio >= CONVECTOR_RATIO_MAX) then	-- temperature much below target. Switch on the convector
							ConvectorRatio = CONVECTOR_RATIO_MAX
							setConvector(RoomNumber, 'On')
						elseif (ConvectorRatio <= CONVECTOR_RATIO_MIN) then	-- temperature much above target. Switch off the convector
							ConvectorRatio = CONVECTOR_RATIO_MIN
							setConvector(RoomNumber, 'Off')
						end
						HeatingTable[RoomNumber].Flames = ConvectorRatio
					else	-- no thermometer in the room. Switching the convector on or off
						if TargetTemp == 'OFF' then
							if debug then
								fibaro.debug('HeatingManagement','Target temperature is '..TargetTemp..'. Switching-off convector ')
							end
							setConvector(RoomNumber, 'Off')
						else
							if debug then
								fibaro.debug('HeatingManagement','Target temperature is '..TargetTemp..'. Switching-on convector ')
							end
							setConvector(RoomNumber, 'On')
						end
					end
				
				end						

---------------------------------------------- Away mode ------------------------------------------------------------------------					
			elseif HeatingTable[RoomNumber].Mode == 'Away' then
				TargetTemp = HeatingTable[RoomNumber].TargetAway

				if (HeatingTable[RoomNumber].HeatingType == 'Fire') then
					
					DeltaFlames = computeFlamesAdjustment ( TargetTemp, LastMeasuredTemp, MeasuredTemp)
					Flames = HeatingTable[RoomNumber].Flames + DeltaFlames
			
					if debug then
						fibaro.debug('HeatingManagement','Target temperature is '..TargetTemp..', Previous Flames = '..HeatingTable[RoomNumber].Flames..', New Flames = '..Flames..', DeltaFlames = '..DeltaFlames)
					end
					if (Flames > FLAMES_MAX) then
						Flames = FLAMES_MAX
					end
					if (Flames < 0) then
						Flames = 0
					end
					adjustFlames(RoomNumber, Flames, FLAMES_MAX, HeatingTable[RoomNumber].Flames)
					HeatingTable[RoomNumber].Flames = Flames
					
					
				elseif (HeatingTable[RoomNumber].HeatingType == 'Inverter')
					or (HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter') then
					
					if isOffPeak(Time) then	-- off-peak period. Heat the room at TargetAway
						fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", TargetTemp)
						if HeatingTable[RoomNumber].IRIdTemp2 ~= 0 then	-- 2 inverters in the room
							fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", TargetTemp)
						end
					else
						-- switch off the Inverter
						fibaro.call(HeatingTable[RoomNumber].IRIdMode1, "setMode", INVERTER_OFF)
						if HeatingTable[RoomNumber].IRIdTemp2 ~= 0 then	-- 2 inverters in the room
							fibaro.call(HeatingTable[RoomNumber].IRIdMode2, "setMode", INVERTER_OFF)
						end						
					end	
	
				elseif HeatingTable[RoomNumber].HeatingType == 'Convector' then
					if isOffPeak(Time) then 	-- heats only during off-peak hours
						if HeatingTable[RoomNumber].Thermometer then
							DeltaConvectorRatio = computeConvectorAdjustment ( HeatingTable[RoomNumber].TargetAway, HeatingTable[RoomNumber].LastTemp)
							ConvectorRatio = HeatingTable[RoomNumber].Flames + DeltaConvectorRatio
							if debug then
								fibaro.debug('HeatingManagement','Target temperature is '..HeatingTable[RoomNumber].TargetAuto..', Previous ConvectorRatio = '
									..HeatingTable[RoomNumber].Flames..', ConvectorRatio = '..ConvectorRatio..', DeltaConvectorRatio = '..DeltaConvectorRatio)
							end
							if (ConvectorRatio >= CONVECTOR_RATIO_MAX) then	-- temperature much below target. Switch on the convector
								ConvectorRatio = CONVECTOR_RATIO_MAX
								setConvector(RoomNumber, 'On')
							elseif (ConvectorRatio <= CONVECTOR_RATIO_MIN) then	-- temperature much above target. Switch off the convector
								ConvectorRatio = CONVECTOR_RATIO_MIN
								setConvector(RoomNumber, 'Off')
							end
							HeatingTable[RoomNumber].Flames = ConvectorRatio
						else	-- no thermometer in the room. Switching the convector off
							setConvector(RoomNumber, 'Off')
						end

					else	-- not off-peak hours: switching off the convector
						setConvector(RoomNumber, 'Off')
					end
				end		
								
			else
				if debug then
					fibaro.debug('HeatingManagement','Room '..RoomName..' not in Auto, Eco or Away mode')
				end
			end
			
			fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
				
		end		-- end of "for" loop.



	else
	
-------------------------------------------------------------------------------------------------------------------
---------------------------------- Trigger is NOT CHECKTEMP: it is HEATING_TRIGGER --------------------------------
-------------------------------------------------------------------------------------------------------------------
		
		
		if debug then
			fibaro.debug('HeatingManagement','The trigger is the variable: HEATING_TRIGGER')
		end
		
		-- looking for the room and the trigger
		RoomNumber = 1
		local TriggerRoomNumber = 0
		local Trigger = ""
		
		while RoomNumber <= NumberOfRooms do
			if HeatingTrigger[RoomNumber].Mode ~= HeatingTable[RoomNumber].Mode then
				TriggerRoomNumber = RoomNumber
				Trigger = "Mode"
				break
			elseif HeatingTrigger[RoomNumber].FlamesManu ~= HeatingTable[RoomNumber].FlamesManu then
				TriggerRoomNumber = RoomNumber
				Trigger = "FlamesManu"
				break
			elseif HeatingTrigger[RoomNumber].TargetAuto ~= HeatingTable[RoomNumber].TargetAuto then
				TriggerRoomNumber = RoomNumber
				Trigger = "TargetAuto"
				break
			end
			RoomNumber = RoomNumber + 1
		end
		if TriggerRoomNumber == 0 then
			if debug then
				fibaro.debug('HeatingManagement','Could not find a change in Mode, FlamesManu or TargetAuto in any room. Aborting')
			end
		elseif Trigger == "Mode" then

-------------------------------------------------------------------------------------------------------------------
------------------------------------------- Trigger is a change of Mode -------------------------------------------
-------------------------------------------------------------------------------------------------------------------
			
			RoomName = HeatingTable[RoomNumber].RoomName
			if debug then
				fibaro.debug('HeatingManagement','Change of mode in '..RoomName..'. New mode = '..HeatingTrigger[RoomNumber].Mode..'\n')
			end
			HeatingTable[RoomNumber].PreviousMode = HeatingTable[RoomNumber].Mode	-- save the previous mode (to go back to it 
																				-- at the end of the "Manual" timer)
			HeatingTable[RoomNumber].Mode = HeatingTrigger[RoomNumber].Mode	-- storing the new mode
			fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
			

-----------------------------------------------Off---------------------------------------------

			if (HeatingTrigger[RoomNumber].Mode == 'Off') then
				if debug then
					fibaro.debug('HeatingManagement','Off mode requested')
				end
				
				if HeatingTable[RoomNumber].HeatingType == 'Fire' then
					-- switch off the fire
					setUpRelay(RoomNumber, 'Off')
					
				elseif HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' then
					-- switch off the fire
					setUpRelay(RoomNumber, 'Off')
					-- switch off Inverter
					fibaro.call(HeatingTable[RoomNumber].IRIdMode1, "setMode", INVERTER_OFF)
					if HeatingTable[RoomNumber].IRIdTemp2 ~= 0 then	-- 2 inverters in the room
						fibaro.call(HeatingTable[RoomNumber].IRIdMode2, "setMode", INVERTER_OFF)
					end

				elseif HeatingTable[RoomNumber].HeatingType == 'Inverter' then
					-- switch off the Inverter
					fibaro.call(HeatingTable[RoomNumber].IRIdMode1, "setMode", INVERTER_OFF)
					if HeatingTable[RoomNumber].IRIdTemp2 ~= 0 then	-- 2 inverters in the room
						fibaro.call(HeatingTable[RoomNumber].IRIdMode2, "setMode", INVERTER_OFF)
					end
					
				elseif HeatingTable[RoomNumber].HeatingType == 'Convector' then
					-- switch off the convector
					setConvector(RoomNumber, 'Off')
				end
	
-----------------------------------------------Auto---------------------------------------------

			elseif (HeatingTrigger[RoomNumber].Mode == 'Auto') then
				if debug then
					fibaro.debug('HeatingManagement','Automatic mode requested')
				end
				
				if HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' then
					if (isOffPeak(Time) and (not isDayTime(Time))) then	-- off-peak period not during the day
						FireInverterMode = 'Inverter'
						HeatingTable[RoomNumber].PreviousInverterMode = 'Inverter'
					else
						FireInverterMode = 'Fire'
						if HeatingTable[RoomNumber].PreviousInverterMode == 'Inverter' then
							fibaro.call(HeatingTable[RoomNumber].IRIdMode1, "setMode", INVERTER_OFF)
							if HeatingTable[RoomNumber].IRIdMode2 ~= 0 then	-- 2 inverters in the room
								fibaro.call(HeatingTable[RoomNumber].IRIdMode2, "setMode", INVERTER_OFF)
							end
							HeatingTable[RoomNumber].PreviousInverterMode = 'Fire'
						end
					end
				end				
			
				if (HeatingTable[RoomNumber].HeatingType == 'Fire') 
					or (HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' and FireInverterMode == 'Fire') then
					setUpRelay(RoomNumber, 'On')

					DeltaFlames = computeFlamesAdjustment(HeatingTable[RoomNumber].TargetAuto, HeatingTable[RoomNumber].LastTemp)
					Flames = HeatingTable[RoomNumber].Flames + DeltaFlames
					if (Flames > FLAMES_MAX) then
						Flames = FLAMES_MAX
					end
					if (Flames < 0) then
						Flames = 0
					end

					adjustFlames(RoomNumber, Flames, FLAMES_MAX, HeatingTable[RoomNumber].Flames)
					HeatingTable[RoomNumber].Flames = Flames
					fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
					
					
				elseif (HeatingTable[RoomNumber].HeatingType == 'Inverter')
						or (HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' and FireInverterMode == 'Inverter') then
					fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", HeatingTable[RoomNumber].TargetAuto)
					if HeatingTable[RoomNumber].IRIdTemp2 ~= 0 then	-- 2 inverters in the room
						fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", HeatingTable[RoomNumber].TargetAuto)
					end
					
					
				elseif HeatingTable[RoomNumber].HeatingType == 'Convector' then
				
					if HeatingTable[RoomNumber].Thermometer then
							DeltaConvectorRatio = computeConvectorAdjustment ( HeatingTable[RoomNumber].TargetAuto, HeatingTable[RoomNumber].LastTemp)
							ConvectorRatio = HeatingTable[RoomNumber].Flames + DeltaConvectorRatio
							if debug then
								fibaro.debug('HeatingManagement','Target temperature is '..HeatingTable[RoomNumber].TargetAuto..', Previous ConvectorRatio = '
									..HeatingTable[RoomNumber].Flames..', New ConvectorRatio = '..ConvectorRatio..', DeltaConvectorRatio = '..DeltaConvectorRatio)
							end
							if (ConvectorRatio >= CONVECTOR_RATIO_MAX) then	-- temperature much below target. Switch on the convector
								ConvectorRatio = CONVECTOR_RATIO_MAX
								setConvector(RoomNumber, 'On')
							elseif (ConvectorRatio <= CONVECTOR_RATIO_MIN) then	-- temperature much above target. Switch off the convector
								ConvectorRatio = CONVECTOR_RATIO_MIN
								setConvector(RoomNumber, 'Off')
							end
							HeatingTable[RoomNumber].Flames = ConvectorRatio
							fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
					else
						if HeatingTable[RoomNumber].TargetAuto == 'OFF' then
							if debug then
								fibaro.debug('HeatingManagement','Target temperature is '..HeatingTable[RoomNumber].TargetAuto..'. Switching-off convector ')
							end
							setConvector(RoomNumber, 'Off')
						else
							if debug then
								fibaro.debug('HeatingManagement','Target temperature is '..HeatingTable[RoomNumber].TargetAuto..'. Switching-on convector ')
							end
							setConvector(RoomNumber, 'On')
						end
					end
				end

-----------------------------------------------Eco---------------------------------------------

			elseif HeatingTrigger[RoomNumber].Mode == 'Eco' then

				TargetTemp = HeatingTable[RoomNumber].TargetAuto
				if (HeatingTable[RoomNumber].HeatingType == 'Fire') or (not isOffPeak(Time)) then
					-- in Eco mode, the target temperature is decreased by TempEco degrees unless in off-peak hours for electric heating
					TargetTemp = TargetTemp - TempEco
				end

				if (HeatingTable[RoomNumber].HeatingType == 'Fire') then
					DeltaFlames = computeFlamesAdjustment ( TargetTemp, LastMeasuredTemp, MeasuredTemp)
					Flames = HeatingTable[RoomNumber].Flames + DeltaFlames
			
					if debug then
						fibaro.debug('HeatingManagement','Target temperature is '..TargetTemp..', Previous Flames = '..HeatingTable[RoomNumber].Flames..', New Flames = '..Flames..', DeltaFlames = '..DeltaFlames)
					end
					if (Flames > FLAMES_MAX) then
						Flames = FLAMES_MAX
					end
					if (Flames < 0) then
						Flames = 0
					end
					adjustFlames(RoomNumber, Flames, FLAMES_MAX, HeatingTable[RoomNumber].Flames)
					HeatingTable[RoomNumber].Flames = Flames
					fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
					
					
				elseif (HeatingTable[RoomNumber].HeatingType == 'Inverter') or (HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter') then
					fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", TargetTemp)
					if HeatingTable[RoomNumber].IRIdTemp2 ~= 0 then	-- 2 inverters in the room
						fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", TargetTemp)
					end
				
				elseif HeatingTable[RoomNumber].HeatingType == 'Convector' then
				
					if HeatingTable[RoomNumber].Thermometer then
						DeltaConvectorRatio = computeConvectorAdjustment ( HeatingTable[RoomNumber].TargetAuto, HeatingTable[RoomNumber].LastTemp)
						ConvectorRatio = HeatingTable[RoomNumber].Flames + DeltaConvectorRatio
				
						if debug then
							fibaro.debug('HeatingManagement','Target temperature is '..HeatingTable[RoomNumber].TargetAuto..', Previous ConvectorRatio = '
								..HeatingTable[RoomNumber].Flames..', New ConvectorRatio = '..ConvectorRatio..', DeltaConvectorRatio = '..DeltaConvectorRatio)
						end
						if (ConvectorRatio >= CONVECTOR_RATIO_MAX) then	-- temperature much below target. Switch on the convector
							ConvectorRatio = CONVECTOR_RATIO_MAX
							setConvector(RoomNumber, 'On')
						elseif (ConvectorRatio <= CONVECTOR_RATIO_MIN) then	-- temperature much above target. Switch off the convector
							ConvectorRatio = CONVECTOR_RATIO_MIN
							setConvector(RoomNumber, 'Off')
						end
						HeatingTable[RoomNumber].Flames = ConvectorRatio
						fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
						
					else
						if HeatingTable[RoomNumber].TargetAuto == 'OFF' then
							if debug then
								fibaro.debug('HeatingManagement','Target temperature is '..HeatingTable[RoomNumber].TargetAuto..'. Switching-off convector ')
							end
							setConvector(RoomNumber, 'Off')
						else
							if debug then
								fibaro.debug('HeatingManagement','Target temperature is '..HeatingTable[RoomNumber].TargetAuto..'. Switching-on convector ')
							end
							setConvector(RoomNumber, 'On')
						end
					end
				end

-----------------------------------------------Manual---------------------------------------------

			elseif (HeatingTrigger[RoomNumber].Mode == 'Manual') then
				if debug then
					fibaro.debug('HeatingManagement','Manual mode requested')
				end
				
				if (HeatingTable[RoomNumber].HeatingType == 'Fire' or HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter') then
					setUpRelay(RoomNumber, 'On')

					adjustFlames(RoomNumber, HeatingTable[RoomNumber].FlamesManu, FLAMES_ECO, 0)
					
				elseif (HeatingTable[RoomNumber].HeatingType == 'Inverter') then
					-- setting the Inverter
					
				elseif HeatingTable[RoomNumber].HeatingType == 'Convector' then
					-- setting the convector to manual mode i.e. controlled by its own thermostat
					setConvector(RoomNumber, 'On')
				end
				
					
-----------------------------------------------Away---------------------------------------------

			elseif (HeatingTrigger[RoomNumber].Mode == 'Away') then
				if debug then
					fibaro.debug('HeatingManagement','Away mode requested')
				end

				if (HeatingTable[RoomNumber].HeatingType == 'Fire') then
					
					setUpRelay(RoomNumber, 'On')
					DeltaFlames = computeFlamesAdjustment(HeatingTable[RoomNumber].TargetAway, HeatingTable[RoomNumber].LastTemp)
					Flames = HeatingTable[RoomNumber].Flames + DeltaFlames
					if (Flames > FLAMES_MAX) then
						Flames = FLAMES_MAX
					end
					if (Flames < 0) then
						Flames = 0
					end

					adjustFlames(RoomNumber, Flames, FLAMES_MAX, HeatingTable[RoomNumber].Flames)
					HeatingTable[RoomNumber].Flames = Flames
					fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
					
					
				elseif (HeatingTable[RoomNumber].HeatingType == 'Inverter' or HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter') then
					if isOffPeak(Time) then		-- heat only during off-peak hours
						fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", HeatingTable[RoomNumber].TargetAway)
						if HeatingTable[RoomNumber].IRIdTemp2 ~= 0 then	-- 2 inverters in the room
							fibaro.call(HeatingTable[RoomNumber].IRIdTemp1, "setThermostatSetpoint", "1", HeatingTable[RoomNumber].TargetAway)
						end	
					else
						fibaro.call(HeatingTable[RoomNumber].IRIdMode1, "setMode", INVERTER_OFF)
						if HeatingTable[RoomNumber].IRIdTemp2 ~= 0 then	-- 2 inverters in the room
							fibaro.call(HeatingTable[RoomNumber].IRIdMode2, "setMode", INVERTER_OFF)
						end
					end
					
				elseif HeatingTable[RoomNumber].HeatingType == 'Convector' then
					if isOffPeak(Time) then 	-- heats only during off-peak hours
						if HeatingTable[RoomNumber].Thermometer then
							DeltaConvectorRatio = computeConvectorAdjustment ( HeatingTable[RoomNumber].TargetAway, HeatingTable[RoomNumber].LastTemp)
							ConvectorRatio = HeatingTable[RoomNumber].Flames + DeltaConvectorRatio
					
							if debug then
								fibaro.debug('HeatingManagement','Target temperature is '..HeatingTable[RoomNumber].TargetAuto..', Previous ConvectorRatio = '
									..HeatingTable[RoomNumber].Flames..', ConvectorRatio = '..ConvectorRatio..', DeltaConvectorRatio = '..DeltaConvectorRatio)
							end
							if (ConvectorRatio >= CONVECTOR_RATIO_MAX) then	-- temperature much below target. Switch on the convector
								ConvectorRatio = CONVECTOR_RATIO_MAX
								setConvector(RoomNumber, 'On')
							elseif (ConvectorRatio <= CONVECTOR_RATIO_MIN) then	-- temperature much above target. Switch off the convector
								ConvectorRatio = CONVECTOR_RATIO_MIN
								setConvector(RoomNumber, 'Off')
							end
							HeatingTable[RoomNumber].Flames = ConvectorRatio
							fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
						else
							-- switch the convector to 'hors gel'
							setConvector(RoomNumber, 'Off')
						end
						
					else	-- not off-peak hours: switching off the convector
						setConvector(RoomNumber, 'Off')
					end
				end
			end	-- end of all possible modes
		
		
		elseif Trigger == 'TargetAuto' then 
			
-------------------------------------------------------------------------------------------------------------------
------------------------------------------- Trigger is a change of TargetAuto -------------------------------------
-------------------------------------------------------------------------------------------------------------------

			RoomName = HeatingTable[RoomNumber].RoomName
			HeatingTable[RoomNumber].TargetAuto = HeatingTrigger[RoomNumber].TargetAuto	-- storing the new target
			fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
			if debug then
				fibaro.debug('HeatingManagement','Change of the Room target temperature in room '..RoomName)
			end
			
			-- No adjustment unless Mode is Auto
			if HeatingTable[RoomNumber].Mode == 'Auto' then
			
				if HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' then
					if (isOffPeak(Time) and (not isDayTime(Time))) then	-- off-peak period not during the day
						FireInverterMode = 'Inverter'
						HeatingTable[RoomNumber].PreviousInverterMode = 'Inverter'
					else
						FireInverterMode = 'Fire'
						if HeatingTable[RoomNumber].PreviousInverterMode == 'Inverter' then
							fibaro.call(HeatingTable[RoomNumber].IRIdMode1, "setMode", INVERTER_OFF)
							if HeatingTable[RoomNumber].IRIdMode2 ~= 0 then	-- 2 inverters in the room
								fibaro.call(HeatingTable[RoomNumber].IRIdMode2, "setMode", INVERTER_OFF)
							end
							HeatingTable[RoomNumber].PreviousInverterMode = 'Fire'
						end
					end
				end					
			
				-- no immediate adjustment unless in fire mode
				if (HeatingTable[RoomNumber].HeatingType == 'Fire') 
					or (HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter' and FireInverterMode == 'Fire') then
					
					if debug then
						fibaro.debug('HeatingManagement','New target temp = '..HeatingTrigger[RoomNumber].TargetAuto..'. LastMeasuredTemp = '..HeatingTable[RoomNumber].LastTemp)
					end
					DeltaFlames = computeFlamesAdjustment(HeatingTrigger[RoomNumber].TargetAuto, HeatingTable[RoomNumber].LastTemp)
					Flames = HeatingTable[RoomNumber].Flames + DeltaFlames
					if (Flames > FLAMES_MAX) then
						Flames = FLAMES_MAX
					end
					if (Flames < 0) then
						Flames = 0
					end

					adjustFlames(RoomNumber, Flames, FLAMES_MAX, HeatingTable[RoomNumber].Flames)
					HeatingTable[RoomNumber].Flames = Flames
					fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
				end
			
			else
				-- Not in Auto mode. Nothing to do.
				if debug then
					fibaro.debug('HeatingManagement','Change of TargetAuto in room'..RoomName..' but Mode is not Auto. Nothing to do\n')
				end
			end
				
		
		elseif Trigger == "FlamesManu" then

-------------------------------------------------------------------------------------------------------------------
------------------------------------------- Trigger is a change of FlamesManu level -------------------------------
-------------------------------------------------------------------------------------------------------------------

			RoomName = HeatingTable[RoomNumber].RoomName	
			HeatingTable[RoomNumber].FlamesManu = HeatingTrigger[RoomNumber].FlamesManu	-- storing the new flames level
			fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
			if debug then
				fibaro.debug('HeatingManagement','Manual adjustment of the flames requested\n')
			end
			
			if (HeatingTable[RoomNumber].Mode == 'Manual' and (HeatingTable[RoomNumber].HeatingType == 'Fire' 
				or HeatingTable[RoomNumber].HeatingType == 'Fire-Inverter')) then
				if debug then
					fibaro.debug('HeatingManagement','Manual adjustment of the flames to '..HeatingTrigger[RoomNumber].FlamesManu.. 'in room '..RoomName..' requested\n')
				end
				adjustFlames(RoomNumber, HeatingTrigger[RoomNumber].FlamesManu, FLAMES_ECO)
			else
				-- Not in Manual mode or no fireplace in the room. Aborting.
				if debug then
					fibaro.debug('HeatingManagement','Mode is not Manual or there is no fireplace in room '..RoomName..'.\n')
				end
			end
		end	-- end of HEATING_TRIGGER treatment
		
	end	-- end of test of global variables

elseif Source['type'] == 'other' then 
	if debug then
		fibaro.debug('HeatingManagement','Trigger = Other. Aborting')
	end

else
	if debug then
		fibaro.debug('HeatingManagement','Trigger is Autostart or unknown. Aborting')
	end
end