import std/[nativesockets, asyncdispatch, strutils, strformat]
import src/[common, messages, helpers]

const ListenPort = Port(6667)
const ListenAddr = "192.168.1.11"

proc liveliness*(c: Client, interval: int) {.async.} =
    while not c.socket.isClosed():
        echo("Checking liveliness..")
        
        await sleepAsync(interval * 1000)
        c.pingMsg(interval)

proc clientHandler*(c: Client, s: Server) {.async.} =
    s.clients.add(c)

    echo(fmt"New connection recieved! {s.clients.len} client(s) detected")

    asyncCheck c.liveliness(60)

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
    echo(fmt"Listening on {ListenPort} at {ListenAddr}")

    while true:
        let
            (ipAddr, socket) = await s.socket.acceptAddr()
            c = Client(
                socket: socket,
                ipAddr: ipAddr,
                epoch: getEpoch()
            )
        
        asyncCheck c.clienthandler(s)

asyncCheck s.run()
runForever()