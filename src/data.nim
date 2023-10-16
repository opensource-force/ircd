import asyncnet

type
  Server* = object
    socket*: AsyncSocket
    clients*: seq[Client]
    channels*: seq[ChatChannel]
  ChatChannel* = ref object
    name*: string
    topic*: string
    clients*: seq[Client]
  Client* = ref object
    socket*: AsyncSocket
    gotPass*, gotNick*, gotUser*: bool
    registered*: bool
    nickname*: string
    username*, hostname*, realname*: string
    ipAddr*: string

var
  s*: Server