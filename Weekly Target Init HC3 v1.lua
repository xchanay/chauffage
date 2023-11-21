--[[ Initialize WEEKLY_TARGET and RDPC global variable 

WeeklyTarget: structure; 	
	WeeklyTarget[room][day][period].Time: Start time of Period period (in minutes between 0 and 24*60 - 1)
	WeeklyTarget[room][day][period].Target: Temperature Target of Period period (decimal number)
		day: from 1 to 7
		period: from 1 to NUMBER_OF_PERIODS
--]]

local FULL_RESET = false
local NUMBER_OF_PERIODS = 4
local MAX_NUMBER_OF_ROOMS = 12
local DAY_LEN = 12
local WEEK_DAY = {}
	WEEK_DAY[1]='Lundi'	
	WEEK_DAY[2]='Mardi'
	WEEK_DAY[3]='Mercredi'
	WEEK_DAY[4]='Jeudi'
	WEEK_DAY[5]='Vendredi'
	WEEK_DAY[6]='Samedi'
	WEEK_DAY[7]='Dimanche'

for i = 1, 7 do	-- pad the name of the day to DAY_LEN with spaces
	nb_loop = DAY_LEN - string.len(WEEK_DAY[i])
	for j = 1, nb_loop do
		WEEK_DAY[i] = WEEK_DAY[i]..' '
	end
end

for i = 1, 7 do
	fibaro.debug('WeeklyTargetInit','Length of '..WEEK_DAY[i]..' is '..string.len(WEEK_DAY[i]))
end

fibaro.debug('WeeklyTargetInit','Starting global variables tests')

local data, status = api.get('/globalVariables/WEEKLY_TARGET')
if status ~= 200 then
	fibaro.debug('WeeklyTargetInit','No WEEKLY_TARGET global variable. Creating it first.')
	local requestData = {
		name = 'WEEKLY_TARGET',
		isEnum = false,
		readOnly = false,
		value = 'Creation'
	}
	local responseData, status = api.post('/globalVariables', requestData)
end

fibaro.debug('WeeklyTargetInit','Max number of rooms = '..MAX_NUMBER_OF_ROOMS)

local WeeklyTarget = {}; 
for room = 1, MAX_NUMBER_OF_ROOMS do
	WeeklyTarget[room] = {}
	for i=1,7 do
		WeeklyTarget[room][i] = {}
		for j=1, NUMBER_OF_PERIODS do
			WeeklyTarget[room][i][j] = {}
				WeeklyTarget[room][i][j].Time = j
				WeeklyTarget[room][i][j].Target = 18
				WeeklyTarget[room][i][j].DayName = WEEK_DAY[i]
				WeeklyTarget[room][i][j].Time = math.floor(j*24*60/(NUMBER_OF_PERIODS+1))
				WeeklyTarget[room][i][j].Target = 18.5
		end
	end
end
	
if not FULL_RESET and fibaro.getGlobalVariable('WEEKLY_TARGET') ~= 'Creation' then
	-- variable exists and has already been initialized
	fibaro.debug('WeeklyTargetInit','WEEKLY_TARGET already initialized')
	fibaro.debug('WeeklyTargetInit','Retrieving previous values as not a full reset')

	local PreviousWeeklyTarget = json.decode(fibaro.getGlobalVariable('WEEKLY_TARGET'))
    room, _ = next(PreviousWeeklyTarget, nil)
	while room do
        for i=1,7 do
			for j=1, NUMBER_OF_PERIODS do
				WeeklyTarget[room][i][j].Time = PreviousWeeklyTarget[room][i][j].Time
				WeeklyTarget[room][i][j].Target = PreviousWeeklyTarget[room][i][j].Target
			end
		end
        room, _ = next (PreviousWeeklyTarget, room)
	end
end

fibaro.setGlobalVariable('WEEKLY_TARGET', json.encode(WeeklyTarget))
fibaro.debug('WeeklyTargetInit','WEEKLY_TARGET initialized')

local test = json.decode(fibaro.getGlobalVariable('WEEKLY_TARGET'))
for room = 1, MAX_NUMBER_OF_ROOMS do
	fibaro.debug('WeeklyTargetInit','test['..room..'] Day '..(((room-1)%7)+1)..'   Period '..(((room-1)%4)+1)..' Time = '..(test[room][((room-1)%7)+1][((room-1)%4)+1].Time))
end


local data, status = api.get('/globalVariables/RDPC')
if status ~= 200 then
	fibaro.debug('WeeklyTargetInit','No RDPC global variable. Creating it first.')
	local requestData = {
		name = 'RDPC',
		isEnum = false,
		readOnly = false,
		value = 'Creation'
	}
	local responseData, status = api.post('/globalVariables', requestData)
end

local RDPC = {}
		RDPC.PreviousRoom = 1
		RDPC.Room = 1
		RDPC.Day = 1
		RDPC.Period = 1
		RDPC.Copy = 0
		

if not FULL_RESET and fibaro.getGlobalVariable('RDPC') ~= 'Creation' then
	-- variable exists and has already been initialized
	fibaro.debug('WeeklyTargetInit','RDPC already initialized')
	fibaro.debug('WeeklyTargetInit','Retrieving previous values as not a full reset')

	local temp = fibaro.getGlobalVariable('RDPC')
	local PreviousRDPC = json.decode(temp)

  	fibaro.debug('WeeklyTargetInit','Not a full reset. Retrieving RDPC pevious data')
	RDPC.PreviousRoom = PreviousRDPC.PreviousRoom
	RDPC.Room = PreviousRDPC.Room
	RDPC.Day = PreviousRDPC.Day
	RDPC.Period = PreviousRDPC.Period
	RDPC.Copy = RDPC.Copy
else
	fibaro.debug('WeeklyTargetInit','Full reset or RDPC not initialized. Initializing')
	local Room = 0
	repeat
		Room = Room + 1
	until not HeatingTable[Room].Thermostat	-- Room contains the first room with no physical thermostat
	RDPC.PreviousRoom = Room
	RDPC.Room = Room
	RDPC.Day = 1
	RDPC.Period = 1
	RDPC.Copy = 0
end
fibaro.setGlobalVariable('RDPC', json.encode(RDPC))

temp = fibaro.getGlobalVariable('RDPC')
RDPC = json.decode(temp)
fibaro.debug('WeeklyTargetInit','PreviousRoom = '..RDPC.PreviousRoom..'  Room = '..RDPC.Room..'  Day = '..RDPC.Day..'  Period = '..RDPC.Period..'  Copy = '..RDPC.Copy)


fibaro.debug('WeeklyTargetInit','Global variables WEEKLY_TARGET and RDPC initialized')