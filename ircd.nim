import asyncnet, asyncdispatch, nativesockets
import strutils, strformat
import ./data
import ./helpers

const
  port = Port(6667)
  ipAddr = "192.168.1.16"

proc passMsg(c: Client, params: seq[string]) =
  if len(params) == 0:
    discard c.send("Not enough params")
    return

  c.password = params[0]
  c.gotPass = true

proc nickMsg(c: Client, params: seq[string]) =
  if len(params) == 0:
    discard c.send("Not enough params")
    return

  c.nickname = params[0]
  
  if len(params) > 1:
    c.hopcount = parseInt(params[1])
  
  c.gotNick = true

proc userMsg(c: Client, params: seq[string], msg: string) =
  if len(params) < 3:
    discard c.send("Not enough params")
    return

  c.username = params[0]
  c.hostname = params[1]
  c.servername = params[2]
  
  if len(params) > 3:
    c.realname = join(params[3..^1], " ")
  
  c.gotUser = true

proc joinMsg(c: Client, params: seq[string]) =
  let name = params[0]
  var channel = c.createChannel(name)
  c.joinChannel(channel, name)

proc privMsg(c: Client, params: seq[string], msg: string) =
  let target = params[0]

  if target.startsWith("#"):
    c.sendChannel(target, msg)
    return

  c.sendNick(target, msg)

proc cmdHandler(c: Client, cmd: string, params: seq[string], msg: string) {.async.} =
  case cmd
  of "PASS": c.passMsg(params)
  of "NICK": c.nickMsg(params)
  of "USER": c.userMsg(params, msg)
  of "JOIN": c.joinMsg(params)
  of "PRIVMSG": c.privMsg(params, msg)
  of "PONG": c.updateTimestamp()

  echo(fmt"{cmd} {params} :{msg}")

  c.updateTimestamp()
  if not c.registered and c.gotPass and c.gotNick and c.gotUser:
    c.registered = true
    echo(fmt"{c.nickname} registered")
    discard c.send("Registered")

proc argHandler(c: Client, line: string) =
  let
    parts = split(line, ":")
    args = splitWhitespace(parts[0])
    cmd = args[0]
    params = args[1..^1]
  
  var msg: string
  
  if args.len > 1:
    msg = join(parts[1..^1], " ")
  
  discard c.cmdHandler(cmd, params, msg)

proc clientHandler(c: Client) {.async.} =
  s.clients.add(c)
  echo("Client connection recieved")

  asyncCheck c.checkLiveliness(60)

  while not c.socket.isClosed():
    let line = await c.socket.recvLine()
    if len(line) == 0: return

    c.argHandler(line)

proc serve() {.async.} =
  s.socket = newAsyncSocket()
  s.socket.setSockOpt(OptReuseAddr, true)
  s.socket.bindAddr(port)
  s.socket.listen()
  echo(fmt"Listening at {ipAddr}:{port}")

  while true:
    let c = Client(
      ipAddr: ipAddr,
      socket: await s.socket.accept(),
      timestamp: getEpochTime()
    )
    
    asyncCheck c.clientHandler()

asyncCheck serve()
runForever()