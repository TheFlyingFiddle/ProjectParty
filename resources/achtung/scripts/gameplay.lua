local sensorNetworkID = 1
function GamePlay()
	local gamePlay = {}
	function gamePlay.enter()
	end
	function gamePlay.exit()
	end
	function gamePlay.render()
	end
	function gamePlay.update()	
		log("We are updating")
		updateTime();

		cfuns.C.networkSend(Network)

		if not cfuns.C.networkIsAlive(Network) then
			log("We are not connected :(")
			return;
		end

		if useButtons then
			--Send le buttons
		else
			Out.writeShort(25)
			Out.writeByte(sensorNetworkID)
			Out.writeVec3(Sensors.acceleration)
			Out.writeVec3(Sensors.gyroscope)
		end

		cfuns.C.networkSend(Network)
	end
	return gamePlay
end