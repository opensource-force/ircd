import asyncnet, asyncdispatch
import strutils, strformat

type
  Server = object
    socket: AsyncSocket
    clients: seq[Client]
  Client = ref object
    socket: AsyncSocket
    password: string
    nickname: string
    hopcount: int
    username, hostname, servername, realname: string
    gotPass, gotNick, gotUser: bool
    registered: bool

var s: Server

proc send(c: Client, msg: string) {.async.} =
  await c.socket.send(msg & "\c\L")

proc setPass(c: Client, params: seq[string]) =
  if len(params) == 0:
    discard c.send("Not enough params")
    return

  c.password = params[0]
  c.gotPass = true

proc setNick(c: Client, params: seq[string]) =
  if len(params) == 0:
    discard c.send("Not enough params")
    return

  c.nickname = params[0]
  
  if len(params) > 1:
    c.hopcount = parseInt(params[1])
  
  c.gotNick = true

proc setUser(c: Client, params: seq[string], msg: string) =
  if len(params) < 3:
    discard c.send("Not enough params")
    return

  c.username = params[0]
  c.hostname = params[1]
  c.servername = params[2]
  
  if len(params) > 3:
    c.realname = join(params[3..^1], " ")
  
  c.gotUser = true

proc getClientbyNickname(nick: string): Client =
  for a in s.clients:
    if a.nickname == nick:
      return a

proc msgUser(c: Client, sender: string, target: string, msg: string) =
  let
    recipient = getClientbyNickname(target)
    message = fmt":{sender} PRIVMSG {recipient.nickname} :{msg}"

  echo fmt"Sending: {message} to {recipient.nickname}"
  discard send(recipient, message)

proc privMsg(c: Client, params: seq[string], msg: string) =
  let
    sender = fmt"{c.nickname}!{c.username}@{c.hostname}"
    target = params[0]

  c.msgUser(sender, target, msg)

proc cmdHandler(c: Client, cmd: string, params: seq[string], msg: string) {.async.} =
  case cmd
  of "PASS": c.setPass(params)
  of "NICK": c.setNick(params)
  of "USER": c.setUser(params, msg)
  of "PRIVMSG": c.privMsg(params, msg)

  echo(fmt"{cmd} {params} :{msg}")

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
  while true:
    let line = await c.socket.recvLine()
    if len(line) == 0: return

    c.argHandler(line)

proc serve() {.async.} =
  s.socket = newAsyncSocket()
  s.socket.setSockOpt(OptReuseAddr, true)
  s.socket.bindAddr(Port(6667))
  s.socket.listen()
  
  while true:
    let c = Client(socket: await s.socket.accept())
    s.clients.add(c)
    asyncCheck clientHandler(c)

asyncCheck serve()
runForever()