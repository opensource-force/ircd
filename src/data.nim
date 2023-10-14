import asyncnet

type
  Server* = object
    socket*: AsyncSocket
    clients*: seq[Client]
  Client* = ref object
    socket*: AsyncSocket
    gotPass*, gotNick*, gotUser*: bool
    registered*: bool
    nickname*: string
    username*: string
    hostname*: string
    realname*: string
    ipAddr*: string

var
  s*: Server