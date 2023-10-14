import asyncnet, asyncdispatch, strutils, net
import ./data
import ./args
import ./helpers

proc clientHandler(c: Client) {.async.} =
  let ipAddr = c.socket.getPeerAddr()[0]
  c.ipAddr = ipAddr 
  
  removeClientByIp(ipAddr)
  echo "Received connection from ", c.ipAddr

  s.clients.add(c)
  while true:
    let args = splitWhitespace(await c.socket.recvLine())
    if args.len > 0: cmdHandler(c, args[0], args[1..^1])

proc serve() {.async.} =
  s.socket = newAsyncSocket()
  s.socket.setSockOpt(OptReuseAddr, true)
  s.socket.bindAddr(Port(6667))
  s.socket.listen()
  echo "Listening on port 6667"
  
  while true:
    var c = Client(socket: await s.socket.accept()) 
    asyncCheck clientHandler(c)

asyncCheck serve()
runForever()