import asyncdispatch, asyncnet, strutils
import ./data
import ./responses

proc sendClient*(c: Client, text: string) {.async.} =
  await c.socket.send(text & "\c\L")

proc clientErr*(c: Client, err: ErrorReply, text: string) {.async.} =
  await c.socket.send("Error: " & $int(err) & " " & text & "\c\L")

proc errAlreadyRegistered*(c: Client) =
  discard clientErr(c, ERR_ALREADYREGISTRED, "User already registered")

proc errNeedMoreParams*(c: Client) =
  discard clientErr(c, ERR_NEEDMOREPARAMS, "Need more parameters")