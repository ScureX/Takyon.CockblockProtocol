global function CockblockProtocolInit

struct PlayerData{
    entity player
    int blockedMessageCount = 0 // keep track of how many messages of this user have been blocked -> the more blocked, the higher the weights
    float lastKillTime
    float lastDeathTime
    string lastVictim
}

array<PlayerData> playerData
array<string> niceMessages = ["ns", "nice", "nice shot", "wow", "cool", "pog"] // if one of these has been in the last few messages it will allow a nice answer
array<string> niceAnswers = ["ty", "thanks", "nice shot", "nice"] // allowed nice answers -> what player can respond to stuff like ns
array<string> lastMessages
int lastMessageSaveAmount = 5

float maxSusThreshhold = 4.0 // if this threshhold is reached the message is very sus and will be blocked
float instantTimeWindow = 0.5 // messages may be sent a second later, this is to adjust how long after a kill messages are considered instant 
bool allowNiceMessages = true // could be abused with sarcastic messages?
float blockedMessageWeightMultiplier = 1.1 // 

// weights -> higher = more weight
float weightMoving = 1.5
float weightInstant = 3.0
float weightFullName = 2.0
float weightLastVictim = 1.5

/*
 *  INIT 
 */

void function CockblockProtocolInit(){
    AddCallback_OnReceivedSayTextMessage(ChatCallback)
    AddCallback_OnPlayerKilled(PlayerKilledCallback)
    AddCallback_OnClientDisconnected(OnPlayerDisconnected)
}

/*
 *  CALLBACKS 
 */

ClServer_MessageStruct function ChatCallback(ClServer_MessageStruct message) {
    float sussyMeter = 0

    float multiplier = 1.0
    if(GetPlayerData(message.player).blockedMessageCount != 0)
        multiplier = GetPlayerData(message.player).blockedMessageCount * blockedMessageWeightMultiplier    


    // debug
    bool move = false
    bool instant = false
    bool fullName = false
    bool lastName = false

    // was person moving while writing
    if(WasMovingWhenSending(message.player)){
        sussyMeter += weightMoving * multiplier
        move = true
    }

    // was message instanly after kill
    if(WasInstantAfterKill(message.player)){
        sussyMeter += weightInstant * multiplier
        instant = true
    }

    // is a players full name mentined
    if(FullPlayernameInMessage(message.message)){
        sussyMeter += weightFullName * multiplier
        fullName = true
        // was name last victim
        if(IsSentNameLastVictim(message.player, message.message)){
            sussyMeter += weightLastVictim * multiplier
            lastName = true
        }
    }

    // debug
    string debug =  "\n\n\nMessage Detected from: " + message.player.GetPlayerName() + "\n" +
                    "Message: " + message.message + "\n" +
                    "WAS MOViNG " + move + "\n" +
                    "INSTANT " + instant + "\n" +
                    "FULL NAME " + fullName + "\n" +
                    "LAST VICTIM " + lastName + "\n" +
                    "Sussiness: " + sussyMeter + "\n\n\n"
    print(debug)
    
    
    // should block based of sussyness
    if(sussyMeter >= maxSusThreshhold){
        // will allow the msg if there has been something like "nice shot" in the last 16 messages 
        if(allowNiceMessages && niceAnswers.contains(message.message.tolower())){ // is msg nice
            if(WereLastMessagesNice()){
                message.shouldBlock = false
                UpdateLastMessages(message.message)
                return message
            }
        }

        // block the message
        message.shouldBlock = true
        SendHudMessage(message.player, "Automated Message Blocked", -1, 0.48, 255, 200, 200, 255, 0.15, 2, 1 )
        // Chat_PrivateMessage(message.player, message.player, "Automated message blocked", true) // 1.6
        UpdateLastMessages(message.message)
        AddBlockedMessage(message.player)
        return message
    }
    UpdateLastMessages(message.message)
    return message
}

void function PlayerKilledCallback(entity victim, entity attacker, var damageInfo)
{
	float timeKilled = Time()
    bool attackerFound = false
    bool victimFound = false

    foreach(PlayerData pd in playerData){
        // for the attacker, add the lastKillTime and the victim
        if(pd.player == attacker){
            pd.lastKillTime = timeKilled
            pd.lastVictim = victim.GetPlayerName()
            attackerFound = true
        }

        // for the victim, add the lastDeathTime
        if(pd.player == victim){
            pd.lastDeathTime = timeKilled
            victimFound = true
        }
    }

    // players not yet in database -> create them
    if(!attackerFound){
        PlayerData atk
        atk.player = attacker
        atk.lastKillTime = timeKilled
        atk.lastVictim = victim.GetPlayerName()
        playerData.append(atk)
    }

    if(!victimFound){
        PlayerData vic
        vic.player = victim
        vic.lastDeathTime = timeKilled
        playerData.append(vic)
    }
}

void function OnPlayerDisconnected(entity player)
{
    RemovePlayerData(player)
}

/*
 *  HELPER FUNCTIONS 
 */

// returns empty PlayerData if not found
PlayerData function GetPlayerData(entity player){
    foreach(PlayerData pd in playerData){
        if(pd.player == player)
            return pd
    }
    
    // player not yet added, add new entry
    PlayerData temp
    temp.player = player
    playerData.append(temp)
    return temp
}

// saves the last x messages
void function UpdateLastMessages(string newMessage){
    if(lastMessages.len() >= lastMessageSaveAmount){
        lastMessages.remove(0)
    }
    lastMessages.append(newMessage)
    print("last msg: " + lastMessages.len())
}

// increase number of blocked messages for player (will increase weightings for that player)
void function AddBlockedMessage(entity player){
    foreach(PlayerData pd in playerData){
        if(pd.player == player){
            pd.blockedMessageCount++
        }
    }
}

// checks if the last x messages were nice (like nice shot) and only then allows a nice message to go thru (like thanks)
bool function WereLastMessagesNice(){
    foreach(string lm in lastMessages){
        array<string> lmSplit = split(lm, " ") // split words to avoid bad matching

        foreach(string word in lmSplit){ // checking for each word in the last message if its a nice work
            if(niceMessages.contains(word))
                return true
        }
    }
    return false
}

// checks if player was moving while sending message
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

// checks if the sent name was of the person last killed
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

// checks if the message was sent instantly after killing someone
bool function WasInstantAfterKill(entity player){
    foreach(PlayerData pd in playerData){
        if(pd.player == player){
            if(Time() - pd.lastKillTime <= instantTimeWindow || Time() - pd.lastDeathTime <= instantTimeWindow)
                return true
        }
    }
    return false
}

// removing playerdata on disconnect to save resources, reset blocked messages if everything gets blocked etc
void function RemovePlayerData(entity player){
    for(int i = 0; i < playerData.len(); i++){
        if(playerData[i].player == player){
            playerData.remove(i)
            return
        }
    }
}