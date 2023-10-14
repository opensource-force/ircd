import asyncnet

type
  Server* = object
    socket*: AsyncSocket
    clients*: seq[Client]
  Client* = ref object
    socket*: AsyncSocket
    gotPass*, gotNick*, gotUser*: bool
    registered*: bool

var
  s*: Server