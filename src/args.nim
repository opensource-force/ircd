import strutils
import ./data
import ./helpers

proc setPass(args: seq[string]) =
  if c.registered:
    errAlreadyRegistered()
    return

  if args.len == 0:
    errNeedMoreParams()
    return

  c.gotPass = true
  
  echo(args)

proc setNick(args: seq[string]) =
  if args.len == 0:
    errNeedMoreParams()
    return
  
  c.gotNick = true

  echo(args)

proc setUser(args: seq[string]) =
  if c.registered:
    return
  
  if args.len < 4:
    errNeedMoreParams()
    return

  if not startsWith(args[3], ":"):
    discard sendClient("Error: " & "Realname must be prefixed with ':'")
    return

  c.gotUser = true

  echo(args)

proc cmdHandler*(command: string, args: seq[string]) =
  case command:
  of "PASS": setPass(args)
  of "NICK": setNick(args)
  of "USER": setUser(args)

  if c.gotPass and c.gotNick and c.gotUser and c.registered == false:
    c.registered = true
    
    echo("Registered!")
    discard sendClient("Registered!")