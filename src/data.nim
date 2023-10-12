import asyncnet

type
  Server* = object
    socket*: AsyncSocket
    clients*: seq[Client]
  Client* = object
    socket*: AsyncSocket
    command*: Command
    registered*: bool = false
  Command* = object
    pass*: Pass
    nick*: Nick
    user*: User
  Pass* = object
    password*: string
  Nick* = object
    nickname*: string
    hopname*: int
  User* = object
    username*, hostname*, servername*: string
    realname*: seq[string]

var
  s*: Server
  c*: Client
  cmd*: Command