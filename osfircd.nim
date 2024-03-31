import std/[asyncdispatch, strutils, strformat]
import ./src/[common, helpers, messages]

const ListenPort = Port(6667)
const ListenAddr = "127.0.0.1"

var s = new(Server)

proc dropClient(c: Client) =
    for i, _ in s.clients:
        if s.clients[i] == c:
            s.clients.del(i)
            c.socket.close()

            echo(fmt"Client closed. {s.clients.len} clients remain")
            break

proc liveliness(c: Client, interval: int) {.async.} =
    while not c.socket.isClosed():
        await sleepAsync(interval * 1000)

        discard c.send(fmt"PING {c.nick}")
        echo("Checking liveliness..")

        if getEpoch() - c.epoch > interval:
            c.dropClient()

proc handle(c: Client, s: Server) {.async.} =
    s.clients.add(c)

    echo(fmt"New connection recieved! {s.clients.len} client(s) detected")

    asyncCheck c.liveliness(2)

    while not c.socket.isClosed():
        try:
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
        except:
            return

proc run(s: Server) {.async.} =
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

asyncCheck s.run()
runForever()