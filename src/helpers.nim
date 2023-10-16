import asyncdispatch, asyncnet, strutils, strformat, net, times
import ./data
import ./responses

proc sendClient*(c: Client, text: string) {.async.} =
  await c.socket.send(text & "\c\L")

proc getEpochTime*(): int =
  let time = split($epochTime(), ".")
  
  return parseInt(time[0])

proc pingClient*(c: Client) =
  discard c.sendClient("PING")

  c.timestamp = getEpochTime()

proc checkLiveliness*(c: Client) {.async.} =
  while true:
    # if now is 60 more than timestamp
    if getEpochTime() - c.timestamp > 60:
      c.pingClient()
    
    # check every 10 sec
    await sleepAsync(10000)

# sendTopic
# Sends the TOPIC command output
proc sendTopic*(c: Client, ch: ChatChannel) {.async.} =
  echo "Send topic TODO"
  # :irc.example.com 332 your_nickname #example :Welcome to the #example channel! Join us to discuss IRC.
  let msg = fmt":{s.name} 332 {c.nickname} {ch.name} :{ch.topic}"
  echo fmt"sent: {msg}"
  discard sendClient(c, msg)

# getChannelNamesList
# Get a list of nicknames in a channel
proc getChannelNamesList(ch: ChatChannel): string =
  var output: string
  for a in ch.clients:
    output = output & a.nickname & " "
  return output

# createChannel
# Creates a new channel on the server
proc createChannel*(channelName: string): ChatChannel =
  echo fmt"Creating new channel named {channelName}"
  let channel = new(ChatChannel)
  channel.name = channelName

  # Add the channel to the list
  s.channels.add(channel)
  return channel

# sendNames
# Sends the NAMES command output
proc sendNames*(c: Client, ch: ChatChannel) {.async.} =
  let mStart = fmt":{s.name} 353 {c.nickname} = {ch.name} :{getChannelNamesList(ch)}"
  let mEnd = fmt":{s.name} 366 {c.nickname} {ch.name} :End of /NAMES list."
  discard sendClient(c, mStart)
  discard sendClient(c, mEnd)

# sendLuser
# Sends the LUSER command output to a connected client
proc sendLuser*(c: Client) {.async.} =
  let userCount = 0
  let invisibleCount = 0
  let onlineOperCount = 0
  let unknownConnectionCount = 0
  let channelCount = 0
  let serverCount = 0
  let uName = c.nickname

  var part: array[5, string]
  part[0] = fmt":{s.name} 251 {uName} :There are {userCount} users and {invisibleCount} invisible on {serverCount} servers"
  part[1] = fmt":{s.name} 252 {uName} {onlineOperCount} :operator(s) online"
  part[2] = fmt":{s.name} 253 {uName} {unknownConnectionCount} :unknown connection(s)"
  part[3] = fmt":{s.name} 254 {uName} {channelCount} :channels formed"
  part[4] = fmt":{s.name} 255 {uName} :I have {userCount} clients and {serverCount} servers"
  
  for line in part:
    discard sendClient(c, line)

# sendMotd
# Sends the MOTD to a connected client
proc sendMotd*(c: Client) {.async.} =
  let filename = "../data/motd.txt"
  let file = open(filename)

  let uName = c.nickname
  let mStart = fmt":{s.name} 375 {uName} :- {s.name} Message of the Day -"
  let mEnd = fmt":{s.name} 376 {uName} :End of /MOTD command."

  discard sendClient(c, mStart)
  if file.isNil:
    echo "Failed to load MOTD file."
    let errResp = fmt":{s.name} 422 {uName} :MOTD File is missing"
    discard sendClient(c, errResp)
  else:
    for line in lines(file):
      discard sendClient(c, line)

    discard sendClient(c, mEnd)
    close(file)

proc clientErr*(c: Client, err: ErrorReply, text: string) {.async.} =
  await c.socket.send("Error: " & $int(err) & " " & text & "\c\L")

proc errAlreadyRegistered*(c: Client) =
  discard clientErr(c, ERR_ALREADYREGISTRED, "User already registered")

proc errNeedMoreParams*(c: Client) =
  discard clientErr(c, ERR_NEEDMOREPARAMS, "Need more parameters")

proc removeClientbyIp*(ip: string) =
  var toRem: Client

  for a in s.clients:
    if a.ipAddr == ip:
      toRem = a
  
  if toRem != nil:
    s.clients.delete(s.clients.find(toRem))

# getClientbyNickname
# Finds a connected client by nickname
proc getClientbyNickname*(nick: string): Client =
  for a in s.clients:
    if a.nickname == nick:
      return a
  return nil

proc removeClientbyNickname*(nick: string) =
  var toRem: Client

  for a in s.clients:
    if a.nickname == nick:
      toRem = a
  
  if toRem != nil:
    s.clients.delete(s.clients.find(toRem))

# getChannelByName
# Finds a channel on the server
proc getChannelByName*(name: string): ChatChannel =
  for a in s.channels:
    if a.name == name:
      return a
  return nil

# isClientInChannel
# Finds a client in a channel
proc isClientInChannel*(channel: string, nickname: string): bool =
  for a in s.channels:
    for b in a.clients:
      if b.nickname == nickname:
        return true
  return false