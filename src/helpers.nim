import asyncdispatch, asyncnet, strutils
import ./data
import ./responses

proc sendClient*(text: string) {.async.} =
  await c.socket.send(text & "\c\L")

proc clientErr*(err: ErrorReply, text: string) {.async.} =
  await c.socket.send("Error: " & $int(err) & " " & text & "\c\L")

proc errAlreadyRegistered*() =
  discard clientErr(ERR_ALREADYREGISTRED, "User already registered")

proc errNeedMoreParams*() =
  discard clientErr(ERR_NEEDMOREPARAMS, "Need more parameters")