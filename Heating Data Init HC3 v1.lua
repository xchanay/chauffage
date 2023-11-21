--[[ Scene setting the initial values of the global variables HEATING_TRIGGER and HEATING_TABLE			

v1  2023/03/21
	
HEATING_TRIGGER is the following structure transformed into a string by function json.encode for each room 
		.Mode: contains 'Auto', 'Manual', 'Away' or 'Off'
		.FlamesManu: integer between 0 and 9. Flames height in 'Manual' mode
		.TargetAuto: temperature target in °C (decimal number)in 'Auto' mode
		
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
		.VoiceActivationStatus: -1 if Flames were just switched off, +1 if Flames were just switched on, 0 otherwise
								used to set the value of the switch "VoiceActivation" in line with the flames status
								without starting the VoiceActivation process
		
		.RoomName: name of the room ('LIVING', 'PARENTS'...)
		.QAId: Id number (as a string) of the QuickApp in the room
		.SystemRoomNumber: number of the room in the HC2
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
		
		

--]]

-------------------------------------------------------------------------------------------------------------
----------------------------- below variables have to be adjusted -------------------------------------------
-------------------------------------------------------------------------------------------------------------

fibaro.debug('HeatingInit','Beginning of the scene')

local FULL_RESET = false

local HeatingTrigger = {}
local HeatingTable = {}


		
local HeatingTableInit = {}
		HeatingTableInit.Mode ='Off'
		HeatingTableInit.FlamesManu =0
		HeatingTableInit.TargetAuto =20
		HeatingTableInit.TargetTVD =20
		HeatingTableInit.TargetAway =15		
		HeatingTableInit.Flames =0
		HeatingTableInit.EndTimer =0 
		HeatingTableInit.LastTemp =0
		HeatingTableInit.PreviousMode ='Off'
		HeatingTableInit.MoveDetectorTimer =0
		HeatingTableInit.VoiceActivationStatus =0
		
local Room = 0
local NumberOfRooms = 0
local PreviousNumberOfRooms = 0
local RoomName=' '	

-------------------------------------------------------------------------------------------------------------
----------------------------------------------------    Room LIVING  ----------------------------------------
-------------------------------------------------------------------------------------------------------------
		
Room = 1

HeatingTable[Room] = {}
	HeatingTable[Room]['RoomName']= 'SEJOUR'
	HeatingTable[Room]['HeatingType']='Fire'
	HeatingTable[Room]['FlamesId']= 204
	HeatingTable[Room]['IRIdTemp1']=0
	HeatingTable[Room]['IRIdMode1']=0
	HeatingTable[Room]['IRIdTemp2']=0
	HeatingTable[Room]['IRIdMode2']=0
	HeatingTable[Room]['PreviousInverterMode']='Inverter'
	HeatingTable[Room]['Thermometer']=true
	HeatingTable[Room]['ThermometerId']=254
	HeatingTable[Room]['Thermostat']=false
	HeatingTable[Room]['ThermostatId']=0
	HeatingTable[Room]['VoiceActivation']=false
	HeatingTable[Room]['VoiceActivationId']=0
	HeatingTable[Room]['MoveDetector']=false
	HeatingTable[Room]['MoveDetectorId']=0
	HeatingTable[Room]['QAId'] = '0'

	HeatingTable[Room]['Mode']= HeatingTableInit.Mode
	HeatingTable[Room]['FlamesManu']= HeatingTableInit.FlamesManu
	HeatingTable[Room]['TargetAuto']= HeatingTableInit.TargetAuto
	HeatingTable[Room]['TargetTVD']= HeatingTableInit.TargetTVD
	HeatingTable[Room]['TargetAway']= HeatingTableInit.TargetAway
	HeatingTable[Room]['Flames']= HeatingTableInit.Flames
	HeatingTable[Room]['EndTimer']= HeatingTableInit.EndTimer
	HeatingTable[Room]['LastTemp']= HeatingTableInit.LastTemp
	HeatingTable[Room]['PreviousMode']= HeatingTableInit.PreviousMode
	HeatingTable[Room]['MoveDetectorTimer']= HeatingTableInit.MoveDetectorTimer
	HeatingTable[Room]['VoiceActivationStatus']= HeatingTableInit.VoiceActivationStatus


-------------------------------------------------------------------------------------------------------------
----------------------------------------------------    Room PARENTS  ---------------------------------------
-------------------------------------------------------------------------------------------------------------
	
Room = 2

HeatingTable[Room] = {}
    HeatingTable[Room]['RoomName']= 'PARENTS'
    HeatingTable[Room]['HeatingType']='Fire'
    HeatingTable[Room]['FlamesId']= 240
    HeatingTable[Room]['IRIdTemp1']=0
    HeatingTable[Room]['IRIdMode1']=0
    HeatingTable[Room]['IRIdTemp2']=0
    HeatingTable[Room]['IRIdMode2']=0
    HeatingTable[Room]['Thermometer']= true
    HeatingTable[Room]['ThermometerId']= 238
    HeatingTable[Room]['Thermostat']=false
    HeatingTable[Room]['ThermostatId']=0
    HeatingTable[Room]['VoiceActivation']=false
    HeatingTable[Room]['VoiceActivationId']=0
    HeatingTable[Room]['MoveDetector']=false
    HeatingTable[Room]['MoveDetectorId']=0
	HeatingTable[Room]['QAId'] = '0'

    HeatingTable[Room]['Mode']= HeatingTableInit.Mode
    HeatingTable[Room]['FlamesManu']= HeatingTableInit.FlamesManu
    HeatingTable[Room]['TargetAuto']= HeatingTableInit.TargetAuto
    HeatingTable[Room]['TargetTVD']= HeatingTableInit.TargetTVD
    HeatingTable[Room]['TargetAway']= HeatingTableInit.TargetAway
    HeatingTable[Room]['Flames']= HeatingTableInit.Flames
    HeatingTable[Room]['EndTimer']= HeatingTableInit.EndTimer
    HeatingTable[Room]['LastTemp']= HeatingTableInit.LastTemp
    HeatingTable[Room]['PreviousMode']= HeatingTableInit.PreviousMode
    HeatingTable[Room]['MoveDetectorTimer']= HeatingTableInit.MoveDetectorTimer
    HeatingTable[Room]['VoiceActivationStatus']= HeatingTableInit.VoiceActivationStatus
	
-------------------------------------------------------------------------------------------------------------
----------------------------------------------------    Room ANATOL  ----------------------------------------
-------------------------------------------------------------------------------------------------------------
			
Room = 3

HeatingTable[Room] = {}
    HeatingTable[Room]['RoomName']= 'ANATOL'
    HeatingTable[Room]['HeatingType']='Convector'
    HeatingTable[Room]['PilotId']= 260
    HeatingTable[Room]['Thermometer']=true
    HeatingTable[Room]['ThermometerId']= 224
    HeatingTable[Room]['Thermostat']=false
    HeatingTable[Room]['ThermostatId']=0
    HeatingTable[Room]['VoiceActivation']=false
    HeatingTable[Room]['VoiceActivationId']=0
    HeatingTable[Room]['MoveDetector']=false
    HeatingTable[Room]['MoveDetectorId']=0
	HeatingTable[Room]['QAId'] = '0'

    HeatingTable[Room]['Mode']= HeatingTableInit.Mode
    HeatingTable[Room]['FlamesManu']= HeatingTableInit.FlamesManu
    HeatingTable[Room]['TargetAuto']= HeatingTableInit.TargetAuto
    HeatingTable[Room]['TargetTVD']= HeatingTableInit.TargetTVD
    HeatingTable[Room]['TargetAway']= HeatingTableInit.TargetAway
    HeatingTable[Room]['Flames']= HeatingTableInit.Flames
    HeatingTable[Room]['EndTimer']= HeatingTableInit.EndTimer
    HeatingTable[Room]['LastTemp']= HeatingTableInit.LastTemp
    HeatingTable[Room]['PreviousMode']= HeatingTableInit.PreviousMode
    HeatingTable[Room]['MoveDetectorTimer']= HeatingTableInit.MoveDetectorTimer
    HeatingTable[Room]['VoiceActivationStatus']= HeatingTableInit.VoiceActivationStatus

-------------------------------------------------------------------------------------------------------------
----------------------------------------------------    Room OSCAR  -----------------------------------------
-------------------------------------------------------------------------------------------------------------
		
Room = 4

HeatingTable[Room] = {}
    HeatingTable[Room]['RoomName']= 'OSCAR'
    HeatingTable[Room]['HeatingType']='Convector'
    HeatingTable[Room]['PilotId']= 265
    HeatingTable[Room]['Thermometer']=false
    HeatingTable[Room]['ThermometerId']=0
    HeatingTable[Room]['Thermostat']=false
    HeatingTable[Room]['ThermostatId']=0
    HeatingTable[Room]['VoiceActivation']=false
    HeatingTable[Room]['VoiceActivationId']=0
    HeatingTable[Room]['MoveDetector']=false
    HeatingTable[Room]['MoveDetectorId']=0
	HeatingTable[Room]['QAId'] = '0'

    HeatingTable[Room]['Mode']= HeatingTableInit.Mode
    HeatingTable[Room]['FlamesManu']= HeatingTableInit.FlamesManu
    HeatingTable[Room]['TargetAuto']= HeatingTableInit.TargetAuto
    HeatingTable[Room]['TargetTVD']= HeatingTableInit.TargetTVD
    HeatingTable[Room]['TargetAway']= HeatingTableInit.TargetAway
    HeatingTable[Room]['Flames']= HeatingTableInit.Flames
    HeatingTable[Room]['EndTimer']= HeatingTableInit.EndTimer
    HeatingTable[Room]['LastTemp']= HeatingTableInit.LastTemp
    HeatingTable[Room]['PreviousMode']= HeatingTableInit.PreviousMode
    HeatingTable[Room]['MoveDetectorTimer']= HeatingTableInit.MoveDetectorTimer
    HeatingTable[Room]['VoiceActivationStatus']= HeatingTableInit.VoiceActivationStatus

-------------------------------------------------------------------------------------------------------------
----------------------------------------------------    Room CASSANDRE  -------------------------------------
-------------------------------------------------------------------------------------------------------------
	
Room = 5

HeatingTable[Room] = {}
    HeatingTable[Room]['RoomName']= 'CASSANDRE'
    HeatingTable[Room]['HeatingType']='Convector'
    HeatingTable[Room]['PilotId']= 196
    HeatingTable[Room]['Thermometer']=true
    HeatingTable[Room]['ThermometerId']= 212
    HeatingTable[Room]['Thermostat']=false
    HeatingTable[Room]['ThermostatId']=0
    HeatingTable[Room]['VoiceActivation']=false
    HeatingTable[Room]['VoiceActivationId']=0
    HeatingTable[Room]['MoveDetector']=false
    HeatingTable[Room]['MoveDetectorId']=0
	HeatingTable[Room]['QAId'] = '0'

    HeatingTable[Room]['Mode']= HeatingTableInit.Mode
    HeatingTable[Room]['FlamesManu']= HeatingTableInit.FlamesManu
    HeatingTable[Room]['TargetAuto']= HeatingTableInit.TargetAuto
    HeatingTable[Room]['TargetTVD']= HeatingTableInit.TargetTVD
    HeatingTable[Room]['TargetAway']= HeatingTableInit.TargetAway
    HeatingTable[Room]['Flames']= HeatingTableInit.Flames
    HeatingTable[Room]['EndTimer']= HeatingTableInit.EndTimer
    HeatingTable[Room]['LastTemp']= HeatingTableInit.LastTemp
    HeatingTable[Room]['PreviousMode']= HeatingTableInit.PreviousMode
    HeatingTable[Room]['MoveDetectorTimer']= HeatingTableInit.MoveDetectorTimer
    HeatingTable[Room]['VoiceActivationStatus']= HeatingTableInit.VoiceActivationStatus

-------------------------------------------------------------------------------------------------------------
----------------------------------------------------    Room Benjamin  -------------------------------------
-------------------------------------------------------------------------------------------------------------
	
Room = 6

    HeatingTable[Room] = {}
    HeatingTable[Room]['RoomName']= 'BENJAMIN'
    HeatingTable[Room]['HeatingType']='Convector'
    HeatingTable[Room]['PilotId']= 200
    HeatingTable[Room]['Thermometer']= true
    HeatingTable[Room]['ThermometerId']= 218
    HeatingTable[Room]['Thermostat']= false
    HeatingTable[Room]['ThermostatId']= 0
    HeatingTable[Room]['VoiceActivation']=false
    HeatingTable[Room]['VoiceActivationId']=0
    HeatingTable[Room]['MoveDetector']=false
    HeatingTable[Room]['MoveDetectorId']=0
	HeatingTable[Room]['QAId'] = '0'

    HeatingTable[Room]['Mode']= HeatingTableInit.Mode
    HeatingTable[Room]['FlamesManu']= HeatingTableInit.FlamesManu
    HeatingTable[Room]['TargetAuto']= HeatingTableInit.TargetAuto
    HeatingTable[Room]['TargetTVD']= HeatingTableInit.TargetTVD
    HeatingTable[Room]['TargetAway']= HeatingTableInit.TargetAway
    HeatingTable[Room]['Flames']= HeatingTableInit.Flames
    HeatingTable[Room]['EndTimer']= HeatingTableInit.EndTimer
    HeatingTable[Room]['LastTemp']= HeatingTableInit.LastTemp
    HeatingTable[Room]['PreviousMode']= HeatingTableInit.PreviousMode
    HeatingTable[Room]['MoveDetectorTimer']= HeatingTableInit.MoveDetectorTimer
    HeatingTable[Room]['VoiceActivationStatus']= HeatingTableInit.VoiceActivationStatus

-------------------------------------------------------------------------------------------------------------
----------------------------------------------------    Room SdJ        -------------------------------------
-------------------------------------------------------------------------------------------------------------
	
Room = 7

HeatingTable[Room] = {}
    HeatingTable[Room]['RoomName'] = 'SALLE DE JEUX'
    HeatingTable[Room]['HeatingType']='Convector'
    HeatingTable[Room]['PilotId']= 264
    HeatingTable[Room]['Thermometer']=false
    HeatingTable[Room]['ThermometerId']=0
    HeatingTable[Room]['Thermostat']=false
    HeatingTable[Room]['ThermostatId']=0
    HeatingTable[Room]['VoiceActivation']=false
    HeatingTable[Room]['VoiceActivationId']=0
    HeatingTable[Room]['MoveDetector']=false
    HeatingTable[Room]['MoveDetectorId']=0
	HeatingTable[Room]['QAId'] = '0'

    HeatingTable[Room]['Mode']= HeatingTableInit.Mode
    HeatingTable[Room]['FlamesManu']= HeatingTableInit.FlamesManu
    HeatingTable[Room]['TargetAuto']= HeatingTableInit.TargetAuto
    HeatingTable[Room]['TargetTVD']= HeatingTableInit.TargetTVD
    HeatingTable[Room]['TargetAway']= HeatingTableInit.TargetAway
    HeatingTable[Room]['Flames']= HeatingTableInit.Flames
    HeatingTable[Room]['EndTimer']= HeatingTableInit.EndTimer
    HeatingTable[Room]['LastTemp']= HeatingTableInit.LastTemp
    HeatingTable[Room]['PreviousMode']= HeatingTableInit.PreviousMode
    HeatingTable[Room]['MoveDetectorTimer']= HeatingTableInit.MoveDetectorTimer
    HeatingTable[Room]['VoiceActivationStatus']= HeatingTableInit.VoiceActivationStatus
	

-------------------------------------------------------------------------------------------------------------
----------------------------------------------------    Room SdB RdJ    -------------------------------------
-------------------------------------------------------------------------------------------------------------	


Room = 8

HeatingTable[Room] = {}
    HeatingTable[Room]['RoomName']= 'SALLE DE BAIN RDJ'
    HeatingTable[Room]['HeatingType']='Convector'
    HeatingTable[Room]['Thermometer']=false
    HeatingTable[Room]['ThermometerId']=0
    HeatingTable[Room]['Thermostat']=false
    HeatingTable[Room]['ThermostatId']=0
    HeatingTable[Room]['VoiceActivation']=false
    HeatingTable[Room]['VoiceActivationId']=0
    HeatingTable[Room]['MoveDetector']=false
    HeatingTable[Room]['MoveDetectorId']=0
	HeatingTable[Room]['QAId'] = '0'

    HeatingTable[Room]['Mode']= HeatingTableInit.Mode
    HeatingTable[Room]['FlamesManu']= HeatingTableInit.FlamesManu
    HeatingTable[Room]['TargetAuto']= HeatingTableInit.TargetAuto
    HeatingTable[Room]['TargetTVD']= HeatingTableInit.TargetTVD
    HeatingTable[Room]['TargetAway']= HeatingTableInit.TargetAway
    HeatingTable[Room]['Flames']= HeatingTableInit.Flames
    HeatingTable[Room]['EndTimer']= HeatingTableInit.EndTimer
    HeatingTable[Room]['LastTemp']= HeatingTableInit.LastTemp
    HeatingTable[Room]['PreviousMode']= HeatingTableInit.PreviousMode
    HeatingTable[Room]['MoveDetectorTimer']= HeatingTableInit.MoveDetectorTimer
    HeatingTable[Room]['VoiceActivationStatus']= HeatingTableInit.VoiceActivationStatus


--[[Room = 9

HeatingTable[Room] = {}
    HeatingTable[Room]['RoomName']= 'NOT_A_ROOM'
    HeatingTable[Room]['HeatingType']='Undefined'
    HeatingTable[Room]['FlamesId']=0
    HeatingTable[Room]['PilotId']=0
    HeatingTable[Room]['IRIdTemp1']=0
    HeatingTable[Room]['IRIdMode1']=0
    HeatingTable[Room]['IRIdTemp2']=0
    HeatingTable[Room]['IRIdMode2']=0
    HeatingTable[Room]['Thermometer']=false
    HeatingTable[Room]['ThermometerId']=0
    HeatingTable[Room]['Thermostat']=false
    HeatingTable[Room]['ThermostatId']=0
    HeatingTable[Room]['VoiceActivation']=false
    HeatingTable[Room]['VoiceActivationId']=0
    HeatingTable[Room]['MoveDetector']=false
    HeatingTable[Room]['MoveDetectorId']=0
	HeatingTable[Room]['QAId'] = '0'

    HeatingTable[Room]['Mode']= HeatingTableInit.Mode
    HeatingTable[Room]['FlamesManu']= HeatingTableInit.FlamesManu
    HeatingTable[Room]['TargetAuto']= HeatingTableInit.TargetAuto
    HeatingTable[Room]['TargetTVD']= HeatingTableInit.TargetTVD
    HeatingTable[Room]['TargetAway']= HeatingTableInit.TargetAway
    HeatingTable[Room]['Flames']= HeatingTableInit.Flames
    HeatingTable[Room]['EndTimer']= HeatingTableInit.EndTimer
    HeatingTable[Room]['LastTemp']= HeatingTableInit.LastTemp
    HeatingTable[Room]['PreviousMode']= HeatingTableInit.PreviousMode
    HeatingTable[Room]['MoveDetectorTimer']= HeatingTableInit.MoveDetectorTimer
    HeatingTable[Room]['VoiceActivationStatus']= HeatingTableInit.VoiceActivationStatus
]]--

-------------------------------------------------------------------------------------------------------------
---------------------------------- No more custom below. processing data ------------------------------------
-------------------------------------------------------------------------------------------------------------

local PreviousHeatingTable = {}

fibaro.debug('HeatingInit','Beggining tests.')
	
local data, status = api.get('/globalVariables/HEATING_TABLE')
if status ~= 200 then
	fibaro.debug('HeatingInit','No HEATING_TABLE global variable. Creating it first.')
	local requestData = {
		name = 'HEATING_TABLE',
		isEnum = false,
		readOnly = false,
		value = 'Creation'
	}
	local responseData, status = api.post('/globalVariables', requestData)
end

data, status = api.get('/globalVariables/HEATING_TRIGGER')
if status ~= 200 then
	fibaro.debug('HeatingInit','No HEATING_TRIGGER global variable. Creating it first.')
	local requestData = {
		name = 'HEATING_TRIGGER',
		isEnum = false,
		readOnly = false,
		value = 'Creation'
	}
	local responseData, status = api.post('/globalVariables', requestData)
end

if not FULL_RESET then	-- if not a full reset, check if previously initialized to retrieve previous values
	if fibaro.getGlobalVariable('HEATING_TABLE') ~= 'Creation' then
		-- variable exists and has already been initialized
		fibaro.debug('HeatingInit','HEATING_TABLE already initialized')
		fibaro.debug('HeatingInit','Retrieving previous values as not a full reset')
		
		PreviousHeatingTable = json.decode(fibaro.getGlobalVariable('HEATING_TABLE'))
		PreviousNumberOfRooms = 0
		local room, previousRoomTable = next(PreviousHeatingTable, nil)
		while room do
			HeatingTable[room]['Mode']				= previousRoomTable.Mode
			HeatingTable[room]['FlamesManu']		= previousRoomTable.FlamesManu
			HeatingTable[room]['TargetAuto']		= previousRoomTable.TargetAuto
			HeatingTable[room]['TargetTVD']			= previousRoomTable.TargetTVD
 			HeatingTable[room]['TargetAway']		= previousRoomTable.TargetAway
			HeatingTable[room]['Flames']			= previousRoomTable.Flames
			HeatingTable[room]['EndTimer']			= previousRoomTable.EndTimer
			HeatingTable[room]['LastTemp']			= previousRoomTable.LastTemp
			HeatingTable[room]['PreviousMode']		= previousRoomTable.PreviousMode
			HeatingTable[room]['MoveDetectorTimer']	= previousRoomTable.MoveDetectorTimer
			HeatingTable[room]['QAId'] 				= previousRoomTable.QAId
			
			PreviousNumberOfRooms = PreviousNumberOfRooms + 1
			room, previousRoomTable = next(PreviousHeatingTable, room)
		end
		
		fibaro.debug('HeatingInit', 'Number of rooms: '..Room..'   PreviousNumberOfRooms: '..PreviousNumberOfRooms)
	end	-- if not FULL_RESET then
		
end

fibaro.debug('HeatingInit','Setting HEATING_TRIGGER')

local room, t = next(HeatingTable, nil)
	while room do
        HeatingTrigger[room] = {}
            HeatingTrigger[room].Mode = HeatingTable[room].Mode
            HeatingTrigger[room].FlamesManu = HeatingTable[room].FlamesManu
            HeatingTrigger[room].TargetAuto = HeatingTable[room].TargetAuto

		room, t = next(HeatingTable, room)
	end

fibaro.setGlobalVariable('HEATING_TRIGGER', json.encode(HeatingTrigger))
fibaro.setGlobalVariable('HEATING_TABLE', json.encode(HeatingTable))
fibaro.debug('HeatingInit','Global variables HEATING_TRIGGER and HEATING_TABLE initialized')

local test = json.decode(fibaro.getGlobalVariable('HEATING_TABLE'))

local room, roomTable = next(test, nil)
while room do
	fibaro.debug('HeatingInit','\n')
	fibaro.debug('HeatingInit', 'Room: '..roomTable.RoomName..'    Room Number: '..room)
	fibaro.debug('HeatingInit', json.encode(roomTable))
	
	room, roomTable = next(test, room)
end
