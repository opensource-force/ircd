import asyncnet, asyncdispatch, strutils, net
import ./data
import ./args
import ./helpers

proc clientHandler(c: Client) {.async.} =
  removeClientByIp(c.ipAddr)
  echo "Received connection from ", c.ipAddr

  s.clients.add(c)
  while true:
    let data = await c.socket.recvLine()
    let parts = data.split(':')
    let args = splitWhitespace(parts[0])
    var message: string = ""

    if args.len == 0: return

    if len(parts) > 1:
      message = parts[1]
    
    cmdHandler(c, args[0], args[1..^1], message)

proc serve() {.async.} =
  s.socket = newAsyncSocket()
  s.socket.setSockOpt(OptReuseAddr, true)
  s.socket.bindAddr(Port(6667))
  s.socket.listen()
  echo "Listening on port 6667"
  
  while true:
    var
      (ip, client) = await s.socket.acceptAddr()
      c = Client(ipAddr: ip, socket: client)
    
    asyncCheck clientHandler(c)

asyncCheck serve()
runForever()