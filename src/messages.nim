import std/[strutils, strformat]
import ./[common, helpers]

# https://www.rfcreader.com/#rfc1459_line671
# <username> <hostname> <servername> <:realname>
proc userMsg(c: Client, params: seq[string], context: string) =
    c.user = params[0]
    c.host = params[1]
    c.server = params[2]
    c.real = context

    if len(params) > 2 and len(context) > 0:
        c.gotUser = true

# https://www.rfcreader.com/#rfc1459_line639
# <nickname> [hopcount] [:old_nick]
proc nickMsg(c: Client, params: seq[string]) =
    c.nick = params[0]
    
    if len(params[0]) > 0:
        c.gotNick = true

    if len(params) > 1:
        c.hopcount = parseInt(params[1])

# https://www.rfcreader.com/#rfc1459_line616
# <password>
proc passMsg(c: Client, params: seq[string]) =
    c.pass = params[0] # ignored for now

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

    echo(fmt"{msg} par{params} con:{context}")

    if c.gotNick and c.gotUser and not c.registered:
        c.registered = true

        echo("Client registered!")