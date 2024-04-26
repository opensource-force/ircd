import std/[asyncdispatch, times, strutils, strformat]
import ./common

proc send*(c: Client, msg: string) {.async.} =
    await c.socket.send(msg & "\n\r")

proc getEpoch*(): int =
    return parseInt(split($epochTime(), ".")[0])

proc dropClient*(c: Client) =
    for i, _ in s.clients:
        if s.clients[i] == c:
            s.clients.del(i)
            c.socket.close()

            echo(fmt"Client closed. {s.clients.len} clients remain")
            break

proc makeChan*(name: string): Chan =
    for chan in s.channels:
        if chan.name == name:
            return chan
    
    let chan = Chan(name: name)

    s.channels.add(chan)
    return chan

proc chanByName*(name: string): Chan =
    for chan in s.channels:
        if chan.name == name:
            return chan

proc sendChan*(c: Client, recipient: string, text: string) =
    let chan = chanByName(recipient)

    for client in chan.clients:
        if client.nick != c.nick:
            discard client.send(fmt":{c.nick}!{c.user}@{c.host} PRIVMSG {chan.name} :{text}")

proc clientByNick*(nick: string): Client =
    for client in s.clients:
        if client.nick == nick:
            return client

proc sendNick*(c: Client, nick: string, text: string) =
    let client = clientByNick(nick)
    discard client.send(fmt":{c.nick}!{c.user}@{c.host} PRIVMSG {client.nick} :{text}")