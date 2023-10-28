import
  std/[asyncdispatch, nativesockets, strutils, strformat, tables],
  ./src/[data, helpers]

const
  #listenAddr = "192.168.1.16"
  port = Port(6667)

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
    names = params[0].split(",")
    
  for name in names:
    let ch = c.createChannel(name)
    ch.clients.add(c)
    
    if c in ch.clients:
      discard c.send(fmt":{c.nickname} JOIN {ch.name}")

    c.sendTopic(ch)
    c.sendNames(ch)

proc topicMsg(c: Client, params: seq[string], msg: string) =
  let
    name = params[0]
    ch = getChannelByName(name)

  if startsWith(name, "#"):
    if len(msg) == 0:
      discard c.send(ch.topic)
      return

    ch.topic = msg

proc privMsg(c: Client, params: seq[string], msg: string) =
  if len(msg) == 0:
    discard c.send("No message specified")
    return

  let target = params[0]

  if target.startsWith("#"):
    c.sendChannel(target, msg)
    return

  c.sendNick(target, msg)

proc notice(c: Client, params: seq[string], msg: string) = 
  if len(msg) == 0:
    discard c.send("No message specified")
    return

  let target = params[0]

  if target.startsWith("#"):
    return
  
  c.sendNotice(target, msg)

proc listMsg(c: Client, params: seq[string]) =
  if len(params) == 0:
    for ch in s.channels:
      if c in ch.clients:
        discard c.send(fmt"{ch.name} {ch.topic}")

    return
  
  let chs = params[0].split(",")

  for ch in s.channels:
    if c in ch.clients and ch.name in chs:
      discard c.send(fmt"{ch.name}: {ch.topic}")

proc clientRegistrar(c: Client) =
  if c.gotPass and c.gotNick and c.gotUser and not c.registered:
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
  of "TOPIC":
    c.hasArgs(1): c.topicMsg(params, msg)
  of "PRIVMSG":
    c.hasArgs(1): c.privMsg(params, msg)
  of "NOTICE":
    c.hasArgs(1): c.notice(params, msg)

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
        timestamp: getEpochTime(),
        modes: initTable[string, string]()
      )
    
    asyncCheck c.clientHandler()

asyncCheck serve()
runForever()