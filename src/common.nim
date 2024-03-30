import std/asyncnet
export asyncnet

type
    Server* = ref object
        socket*: AsyncSocket
        clients*: seq[Client]
    Client* = ref object
        socket*: AsyncSocket
        ipAddr*: string
        epoch*: int
        pass*: string
        nick*: string
        hopcount*: int
        user*, host*, server*, real*: string
        gotNick*, gotUser*, registered*: bool