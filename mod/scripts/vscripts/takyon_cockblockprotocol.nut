global function CockblockProtocolInit

struct PlayerData{
    entity player
    float lastKillTime
    string lastVictim
}

array<PlayerData> playerData
array<string> niceMessages = ["ty", "thanks"]

void function CockblockProtocolInit(){
    AddCallback_OnReceivedSayTextMessage(ChatCallback)
    AddCallback_OnPlayerKilled(PlayerKilledCallback)
}

ClServer_MessageStruct function ChatCallback(ClServer_MessageStruct message) {
    int sussyMeter = 0
    // was person moving while writing
    if(WasMovingWhenSending(message.player)){
        sussyMeter++
        printl("WAS MOViNG")
    }

    // was message instanly after kill
    if(WasInstantAfterKill(message.player)){
        sussyMeter++
        printl("INSTANT")
    }

    // is a players full name mentined
    if(FullPlayernameInMessage(message.message)){
        sussyMeter++
        printl("FULL NAME")
        // was name last victim
        if(IsSentNameLastVictim(message.player, message.message)){
            sussyMeter++
            printl("LAST VICTIM")
        }
    }
    
    // is msg nice

    // should block based of sussyness

    return message
}

bool function WasMovingWhenSending(entity player){
    vector playerVelV = player.GetVelocity()
    float playerVel = sqrt(playerVelV.x * playerVelV.x + playerVelV.y * playerVelV.y)
    float playerVelNormal = playerVel * (0.274176/3)

    if(playerVelNormal > 2)
        return true
    return false
}

// find full playername in msg
bool function FullPlayernameInMessage(string msg){
    foreach(entity player in GetPlayerArray()){
        if(msg.find(player.GetPlayerName()))
            return true
    } 
    return false
}

bool function IsSentNameLastVictim(entity player, string msg){
    string name = ""
    foreach(entity player in GetPlayerArray()){
        if(msg.find(player.GetPlayerName()))
            name = player.GetPlayerName()
    } 

    foreach(PlayerData pd in playerData){
        if(pd.player == player)
            if(pd.lastVictim == name)
                return true
    }
    return false
}

bool function WasInstantAfterKill(entity player){
    foreach(PlayerData pd in playerData){
        if(pd.player == player){
            if(Time() - pd.lastKillTime < 1)
                return true
        }
    }
    return false
}

void function PlayerKilledCallback(entity victim, entity attacker, var damageInfo)
{
	float timeKilled = Time()
    
    foreach(PlayerData pd in playerData){
        if(pd.player == attacker){
            pd.lastKillTime = timeKilled
            pd.lastVictim = victim.GetPlayerName()
        }
    }
}