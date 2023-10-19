import asyncnet

type
  Server* = object
    socket*: AsyncSocket
    clients*: seq[Client]
    channels*: seq[ChatChannel]
  Client* = ref object
    ipAddr*: string
    socket*: AsyncSocket
    password*: string
    nickname*: string
    hopcount*: int
    username*, hostname*, servername*, realname*: string
    gotPass*, gotNick*, gotUser*: bool
    registered*: bool
    timestamp*: int
  ChatChannel* = ref object
    name*: string
    clients*: seq[Client]

var s*: Server