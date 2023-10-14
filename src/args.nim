import strutils
import ./data
import ./helpers

proc setPass(c: Client, args: seq[string]) =
  if c.registered:
    errAlreadyRegistered(c)
    return

  if args.len == 0:
    errNeedMoreParams(c)
    return

  c.gotPass = true
  
  echo(args)

proc setNick(c: Client, args: seq[string]) =
  if args.len == 0:
    errNeedMoreParams(c)
    return
  
  c.gotNick = true

  echo(args)

proc setUser(c: Client, args: seq[string]) =
  if c.registered:
    return
  
  if args.len < 4:
    errNeedMoreParams(c)
    return

  if not startsWith(args[3], ":"):
    discard sendClient(c, "Error: " & "Realname must be prefixed with ':'")
    return

  c.gotUser = true

  echo(args)

proc cmdHandler*(c: Client, command: string, args: seq[string]) =
  case command:
  of "PASS": setPass(c, args)
  of "NICK": setNick(c, args)
  of "USER": setUser(c, args)

  if c.gotPass and c.gotNick and c.gotUser and c.registered == false:
    c.registered = true
    
    echo("Registered!")
    discard sendClient(c, "Registered!")