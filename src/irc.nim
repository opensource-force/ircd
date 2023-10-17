import asyncnet, asyncdispatch, strutils, net, strformat
import ./data
import ./args
import ./helpers

proc clientHandler(c: Client) {.async.} =
  removeClientByIp(c.ipAddr)
  echo "Received connection from ", c.ipAddr

  s.clients.add(c)
  while true:
    let
      line = await c.socket.recvLine()
      parts = line.split(':')
      args = splitWhitespace(parts[0])
    
    var message: string = ""

    asyncCheck(c.checkLiveliness(60))

    if len(args) == 0: return

    echo(fmt"{c.timestamp}: {args}")

    if len(parts) > 1:
      message = parts[1]
    
    c.cmdHandler(args[0], args[1..^1], message)

proc serve() {.async.} =
  s.name = fmt"{getPrimaryIPAddr()}"
  s.socket = newAsyncSocket()
  s.socket.setSockOpt(OptReuseAddr, true)
  s.socket.bindAddr(Port(6667))
  s.socket.listen()
  echo "Listening on port 6667"
  
  while true:
    var
      (ip, client) = await s.socket.acceptAddr()
      c = Client(
        ipAddr: ip,
        socket: client,
        timestamp: getEpochTime()
      )
    
    asyncCheck clientHandler(c)

asyncCheck(serve())
runForever()