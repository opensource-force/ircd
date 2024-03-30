import std/[asyncdispatch, strutils]
import ./src/[common, helpers, messages]

const ListenPort = Port(6667)
const ListenAddr = "127.0.0.1"

var s = new(Server)

proc handle(c: Client, s: Server) {.async.} =
    s.clients.add(c)

    echo("Connection recieved!")
    echo("Clients: ", s.clients.len)

    while true:
        let line = await c.socket.recvLine()
            
        if len(line) == 0:
            return

        let
            parts = split(line, ":")
            args = splitWhitespace(parts[0])
            msg = args[0]
            params = args[1..^1]
            context = join(parts[1..^1], " ")
        
        c.msgHandler(msg, params, context)

proc exec(s: Server) {.async.} =
    s.socket = newAsyncSocket()
    s.socket.setSockOpt(OptReuseAddr, true)
    s.socket.bindAddr(ListenPort, ListenAddr)
    s.socket.listen()

    while true:
        let
            (ipAddr, socket) = await s.socket.acceptAddr()
            c = Client(
                socket: socket,
                ipAddr: ipAddr,
                epoch: getEpoch() # not implemented
            )
        
        asyncCheck c.handle(s)

asyncCheck s.exec()
runForever()