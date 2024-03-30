import std/[strutils, times]

proc getEpoch*(): int =
    return parseInt(split($epochTime(), ".")[0])