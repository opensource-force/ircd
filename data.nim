import asyncnet

type
  Server* = object
    socket*: AsyncSocket
    clients*: seq[Client]
    channels*: seq[ChatChannel]
  ChatChannel* = ref object
    name*: string
    clients*: seq[Client]
  Client* = ref object
    socket*: AsyncSocket
    password*: string
    nickname*: string
    hopcount*: int
    username*, hostname*, servername*, realname*: string
    gotPass*, gotNick*, gotUser*: bool
    registered*: bool

var s*: Server