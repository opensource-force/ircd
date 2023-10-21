import
  asyncdispatch, nativesockets,
  strutils, strformat,
  ./data, ./helpers

const port = Port(6667)

proc passMsg(c: Client, params: seq[string]) =
  c.password = params[0]
  
  c.gotPass = true

proc nickMsg(c: Client, params: seq[string]) =
  c.nickname = params[0]
  
  if len(params) > 1:
    c.hopcount = parseInt(params[1])
  
  c.gotNick = true

proc userMsg(c: Client, params: seq[string], msg: string) =
  c.username = params[0]
  c.hostname = params[1]
  c.servername = params[2]
  
  if len(params) > 3:
    c.realname = msg
  
  c.gotUser = true

proc joinMsg(c: Client, params: seq[string]) =
  let
    name = params[0]
    channel = c.createChannel(name)
    
  c.joinChannel(channel, name)

proc privMsg(c: Client, params: seq[string], msg: string) =
  let target = params[0]

  if target.startsWith("#"):
    c.sendChannel(target, msg)
    return

  c.sendNick(target, msg)

proc listMsg(c: Client, params: seq[string]) =
  if len(params) > 0:
    for a in s.channels:
      if a.name in params:
        discard c.send(fmt"{a.name}: {a.topic}")

    return

  for a in s.channels:
    discard c.send(fmt"{a.name}: {a.topic}")

proc clientRegistrar(c: Client) =
  if not c.registered and c.gotPass and c.gotNick and c.gotUser:
    c.registered = true
    echo(fmt"{c.nickname} registered")
    discard c.send("Registered")

    c.sendMotd()
    c.sendLuser()

proc cmdHandler(c: Client, cmd: string, params: seq[string], msg: string) {.async.} =
  case cmd
  of "PASS":
    c.hasArgs(1): c.passMsg(params)
  of "NICK":
    c.hasArgs(1): c.nickMsg(params)
  of "USER":
    c.hasArgs(3): c.userMsg(params, msg)
  of "JOIN":
    c.hasArgs(1): c.joinMsg(params)
  of "PRIVMSG":
    c.hasArgs(2): c.privMsg(params, msg)
  of "PONG": c.updateTimestamp()
  of "LIST": c.listMsg(params)

  c.clientRegistrar()

  echo(cmd, params, msg)

proc argHandler(c: Client, line: string) =
  let
    parts = split(line, ":")
    args = splitWhitespace(parts[0])
    cmd = args[0]
    params = args[1..^1]
  
  var msg: string
  
  if len(args) > 1:
    msg = join(parts[1..^1], " ")
  
  discard c.cmdHandler(cmd, params, msg)

proc clientHandler(c: Client) {.async.} =
  s.clients.add(c)
  echo("Connection recieved")

  asyncCheck c.checkLiveliness(60)

  while not c.socket.isClosed():
    try:
      let line = await c.socket.recvLine()
      if len(line) == 0: return

      c.argHandler(line)
    except:
      continue

proc serve() {.async.} =
  s.socket = newAsyncSocket()
  s.socket.setSockOpt(OptReuseAddr, true)
  s.socket.bindAddr(port)
  s.socket.listen()
  echo(fmt"Listening on {port}")

  while true:
    let
      (ipAddr, socket) = await s.socket.acceptAddr()
      c = Client(
        ipAddr: ipAddr,
        socket: socket,
        timestamp: getEpochTime()
      )
    
    asyncCheck c.clientHandler()

asyncCheck serve()
runForever()