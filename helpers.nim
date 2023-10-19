import asyncnet, asyncdispatch
import strutils, strformat, times
import ./data

proc send*(c: Client, msg: string) {.async.} =
  await c.socket.send(msg & "\c\L")

proc getClientByNickname*(nick: string): Client =
  for a in s.clients:
    if a.nickname == nick:
      return a

proc getChannelByName*(name: string): ChatChannel =
  for a in s.channels:
    if a.name == name:
      return a

proc sendNick*(c: Client, target: string, msg: string) =
  let
    sender = fmt"{c.nickname}!{c.username}@{c.hostname}"
    target = getClientByNickname(target)
    message = fmt":{sender} PRIVMSG {target.nickname} :{msg}"

  echo(fmt"Sending: '{msg}' to {target.nickname}")
  discard send(target, message)

proc createChannel*(c: Client, name: string): ChatChannel =
  for channel in s.channels:
    if channel.name == name:
      return channel
  
  let newChannel = ChatChannel(name: name, clients: @[])
  s.channels.add(newChannel)
  
  return newChannel

proc joinChannel*(c: Client, ch: ChatChannel, name: string) =
  if ch in s.channels:
    ch.clients.add(c)
    discard c.send(fmt":{c.nickname} JOIN {name}")

proc sendChannel*(c: Client, target: string, msg: string) =
  let
    sender = fmt"{c.nickname}!{c.username}@{c.hostname}"
    target = getChannelByName(target)
    message = fmt":{sender} PRIVMSG {target.name} :{msg}"
  
  for client in target.clients:
    if client.nickname != c.nickname:
      discard client.send(message)

  echo(fmt"Sending: '{msg}' to {target.name}")

proc getEpochTime*(): int =
  let time = split($epochTime(), ".")
  
  return parseInt(time[0])

proc updateTimestamp*(c: Client) = c.timestamp = getEpochTime()

proc pingClient*(c: Client) = discard c.send("PING " & c.nickname)

proc checkLiveliness*(c: Client, interval: int) {.async.} =
  while true:
    if getEpochTime() - c.timestamp >= interval:
      c.pingClient()
      
    await sleepAsync(0)