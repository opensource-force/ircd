import asyncnet
import tables
export asyncnet

type
  Server* = object
    socket*: AsyncSocket
    clients*: seq[Client]
    channels*: seq[ChatChannel]
  Client* = ref object
    ipAddr*: string
    socket*: AsyncSocket
    modes*: Table[string, string]
    password*: string
    nickname*: string
    hopcount*: int
    username*, hostname*, servername*, realname*: string
    gotPass*, gotNick*, gotUser*: bool
    registered*: bool
    timestamp*: int
  ChatChannel* = ref object
    name*: string
    topic*: string
    clients*: seq[Client]
    modes*: Table[string, string]

var s*: Server