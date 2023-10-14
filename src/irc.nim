import asyncnet, asyncdispatch, strutils, net
import ./data
import ./args
import ./helpers

proc clientHandler(c: Client) {.async.} =
  removeClientByIp(c.ipAddr)
  echo "Received connection from ", c.ipAddr

  s.clients.add(c)
  while true:
    let args = splitWhitespace(await c.socket.recvLine())
    
    if args.len == 0: return
    
    cmdHandler(c, args[0], args[1..^1])

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