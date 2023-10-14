import asyncdispatch, asyncnet, strutils, strformat, net
import ./data
import ./responses

proc sendClient*(c: Client, text: string) {.async.} =
  await c.socket.send(text & "\c\L")

# sendMotd
# Sends the MOTD to a connected client
proc sendMotd*(c: Client) {.async.} =
  let filename = "../data/motd.txt"
  let file = open(filename)

  #:server.example.com 375 your_nickname :- server.example.com Message of the Day -
  #:server.example.com 372 your_nickname :- Welcome to our IRC network!
  #:server.example.com 376 your_nickname :End of /MOTD command.

  var sName = getPrimaryIPAddr()
  let uName = c.nickname
  let mStart = fmt":{sName} 375 {uName} :- {sName} Message of the Day -"
  let mEnd = fmt":{sName} 376 {uName} :End of /MOTD command."

  discard sendClient(c, mStart)
  if file.isNil:
    echo "Failed to load MOTD file."
    let errResp = fmt":{sName} 422 {uName} :MOTD File is missing"
    discard sendClient(c, errResp)
  else:
    for line in lines(file):
      discard sendClient(c, line)

    discard sendClient(c, mEnd)
    close(file)

proc clientErr*(c: Client, err: ErrorReply, text: string) {.async.} =
  await c.socket.send("Error: " & $int(err) & " " & text & "\c\L")

proc errAlreadyRegistered*(c: Client) =
  discard clientErr(c, ERR_ALREADYREGISTRED, "User already registered")

proc errNeedMoreParams*(c: Client) =
  discard clientErr(c, ERR_NEEDMOREPARAMS, "Need more parameters")