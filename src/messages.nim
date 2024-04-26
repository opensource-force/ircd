import std/[strutils, strformat]
import ./[common, helpers]

## Client Messages ##
# https://www.rfcreader.com/#rfc1459_line616
# <password>
proc passMsg(c: Client, params: seq[string]) =
    c.pass = params[0] # ignored for now

# https://www.rfcreader.com/#rfc1459_line639
# <nickname> [hopcount] [:old_nick]
proc nickMsg(c: Client, params: seq[string]) =
    c.nick = params[0]
    
    if len(params[0]) > 0:
        c.gotNick = true

    if len(params) > 1:
        c.hopcount = parseInt(params[1])

# https://www.rfcreader.com/#rfc1459_line671
# <username> <hostname> <servername> <:realname>
proc userMsg(c: Client, params: seq[string], context: string) =
    c.user = params[0]
    c.host = params[1]
    c.server = params[2]
    c.real = context

    if len(params) > 2 and len(context) > 0:
        c.gotUser = true

# https://www.rfcreader.com/#rfc1459_line885
# <channel...> [key...] [:user]
proc joinMsg(c: Client, params: seq[string], context: string) =
    let chanNames = params[0].split(",")

    for name in chanNames:
        let chan = makeChan(name)

        if c notin chan.clients:
            chan.clients.add(c)
            discard c.send(fmt":{c.nick} JOIN {chan.name}")

# https://www.rfcreader.com/#rfc1459_line1480
# <recipient...> <:text>
proc privMsg(c: Client, params: seq[string], context: string) =
    let recip = params[0]
    
    if recip.startsWith("#"):
        c.sendChan(recip, context)
        return

    c.sendNick(recip, context)

proc msgHandler*(c: Client, msg: string, params: seq[string], context: string) =
    case msg
    of "PASS":
        c.passMsg(params)
    of "NICK":
        c.nickMsg(params)
    of "USER":
        c.userMsg(params, context)
    of "PONG":
        c.epoch = getEpoch()
    of "JOIN":
        c.joinMsg(params, context)
    of "PRIVMSG":
        c.privMsg(params, context)

    echo(fmt"{msg} par{params} con:{context}")

    if c.gotNick and c.gotUser and not c.registered:
        c.registered = true

        echo("Client registered!")

## Server Messages ##
# https://www.rfcreader.com/#rfc1459_line1705
# [server|nickname] [servers...]
proc pingMsg*(c: Client, interval: int) =
    discard c.send(fmt"PING {c.nick}")

    if getEpoch() - c.epoch > interval:
        c.dropClient()