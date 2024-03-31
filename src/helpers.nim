import std/[asyncdispatch, strutils, times]
import ./common

proc send*(c: Client, msg: string) {.async.} =
    await c.socket.send(msg & "\n\r")

proc getEpoch*(): int =
    return parseInt(split($epochTime(), ".")[0])