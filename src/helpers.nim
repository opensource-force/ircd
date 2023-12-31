import
  std/[asyncdispatch, strutils, sequtils, strformat, times],
  ./data

template hasArgs*(c: Client, minArgs: int, code: untyped) =
  if len(params) < minArgs:
    discard c.send("Not enough arguments")
  else:
    code
    c.updateTimestamp()

# User Modes
proc hasMode*(c: Client, mode: char): bool =
  return mode in c.modes

proc getMode*(c: Client, mode: char): char =
  if c.hasMode(mode):
    return mode

proc setModes*(c: Client, modes: string, value: string) =
  for mode in modes:
    c.modes[mode] = value

proc removeModes*(c: Client, modes: string) =
  for mode in modes:
    if mode in c.modes:
      c.modes.del(mode)

# Channel Modes
proc hasMode*(ch: ChatChannel, mode: char): bool =
  return mode in ch.modes

proc getMode*(ch: ChatChannel, mode: char): (bool, char) =
  if not ch.hasMode(mode):
    return(false, '_') # o_0

  return(true, mode)

proc setModes*(ch: ChatChannel, modes: string, value: string) =
  for mode in modes:
    ch.modes[mode] = value

proc removeModes*(ch: ChatChannel, modes: string) = 
  for mode in modes:
    if mode in ch.modes:
      ch.modes.del(mode)

proc send*(c: Client, msg: string) {.async.} =
  await c.socket.send(msg & "\n\r")

proc getClientByNickname*(nick: string): Client =
  for client in s.clients:
    if client.nickname == nick:
      return client

proc getChannelByName*(name: string): ChatChannel =
  for ch in s.channels:
    if ch.name == name:
      return ch

proc removeClient*(c: Client) =
  echo("Connection closed")
  c.socket.close()
  
  for i, _ in s.clients:
    if s.clients[i] == c:
      s.clients.del(i)
      break

proc getSenderHostname(c: Client): string =
  return fmt"{c.nickname}!{c.username}@{c.hostname}"

proc sendNick*(c: Client, target: string, msg: string) =
  let
    sender = c.getSenderHostname()
    client = getClientByNickname(target)

  if client.isNil:
    return
  let message = fmt":{sender} PRIVMSG {client.nickname} :{msg}"

  discard client.send(message)

proc sendNotice*(c: Client, target: string, msg: string) = 
  let 
    sender = c.getSenderHostname()
    client = getClientByNickname(target)

  if client.isNil:
    return
  let message = fmt":{sender} NOTICE {client.nickname} :{msg}"
  
  discard client.send(message)

proc createChannel*(c: Client, name: string): ChatChannel =
  for ch in s.channels:
    if ch.name == name:
      return ch
  
  let newCh = ChatChannel(name: name, topic: "unset", modes: initTable[char, string]())
  s.channels.add(newCh)
  
  return newCh

proc sendTopic*(c: Client, ch: ChatChannel) =
  let msg = if ch.topic == "":
    ":No topic set"
  else:
    fmt":{ch.topic}"

  let topic = fmt":{c.servername} 332 {ch.name} :{msg}"

  discard c.send(topic)

proc sendNames*(c: Client, ch: ChatChannel) =
  let
    names = ch.clients.mapIt(it.nickname)
    namesList = join(names, " ")
    msg = [
      fmt":{c.servername} 353 {c.nickname} = {ch.name} :{namesList}",
      fmt":{c.servername} 366 {ch.name} :End of /NAMES list"
    ]

  discard c.send(join(msg, "\n"))

proc sendChannel*(c: Client, target: string, msg: string) =
  let 
    sender = fmt"{c.nickname}!{c.username}@{c.hostname}"
    ch = getChannelByName(target)
    message = fmt":{sender} PRIVMSG {ch.name} :{msg}"
  
  for client in ch.clients:
    if client.nickname != c.nickname:
      discard client.send(message)

proc getEpochTime*(): int =
  let time = split($epochTime(), ".")
  
  return parseInt(time[0])

proc updateTimestamp*(c: Client) = c.timestamp = getEpochTime()

proc pingClient*(c: Client) = discard c.send(fmt"PING {c.nickname}")

proc checkLiveliness*(c: Client, interval: int) {.async.} =
  var skip: bool

  while true:
    if getEpochTime() - c.timestamp >= interval * 2:
      c.removeClient()
      return
    
    if skip: c.pingClient()
    skip = true

    await sleepAsync(interval * 1000)

proc sendMotd*(c: Client) =
  let motd = """
    MOTD: Welcome to the server!
    x-----------------------x
    x       OSFIRCd         x
    x-----------------------x
  """

  discard c.send(motd)

proc sendLuser*(c: Client) =
  let
    userCount = s.clients.len()
    invisibleCount = 0
    onlineOperCount = 0
    unknownConnectionCount = 0
    channelCount = s.channels.len()
    serverCount = 1
    luser = @[
      fmt":{c.servername} 251 {c.nickname} :There are {userCount} users and {invisibleCount} invisible on {serverCount} servers",
      fmt":{c.servername} 252 {c.nickname} {onlineOperCount} :operator(s) online",
      fmt":{c.servername} 253 {c.nickname} {unknownConnectionCount} :unknown connection(s)",
      fmt":{c.servername} 254 {c.nickname} {channelCount} :channels formed",
      fmt":{c.servername} 255 {c.nickname} :I have {userCount} clients and {serverCount} servers"
    ]
  
  discard c.send(join(luser, "\n"))