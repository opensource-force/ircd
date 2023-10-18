import asyncnet

type
  Server* = object
    socket*: AsyncSocket
    clients*: seq[Client]
    channels*: seq[ChatChannel]
  Client* = ref object
    socket*: AsyncSocket
    password*: string
    nickname*: string
    hopcount*: int
    username*, hostname*, servername*, realname*: string
    gotPass*, gotNick*, gotUser*: bool
    registered*: bool
  ChatChannel* = ref object
    name*: string
    clients*: seq[Client]

var s*: Server