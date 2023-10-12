import asyncnet, asyncdispatch, strutils
import ./data
import ./args

proc clientHandler(c: Client) {.async.} =
  echo "Received connection from ", c.socket.getPeerAddr
  while true:
    let args = splitWhitespace(await c.socket.recvLine())
    
    if args.len > 0: cmdHandler(args[0], args[1..^1])

proc serve() {.async.} =
  s.socket = newAsyncSocket()
  s.socket.setSockOpt(OptReuseAddr, true)
  s.socket.bindAddr(Port(6667))
  s.socket.listen()
  echo "Listening on port 6667"

  while true:
    c.socket = await s.socket.accept()
    s.clients.add(c)
    
    asyncCheck c.clientHandler()

asyncCheck serve()
runForever()