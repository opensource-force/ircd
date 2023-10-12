import strutils
import ./data
import ./helpers

proc setCmd(pass: var Pass, args: seq[string]) =
  if c.registered:
    errAlreadyRegistered()
    return

  if args.len == 0:
    errNeedMoreParams()
    return

  pass.password = args[0]

  echo(pass)

proc setCmd(nick: var Nick, args: seq[string]) =
  if args.len == 0:
    errNeedMoreParams()
    return
  
  nick.nickname = args[0]
  
  if args.len > 1: nick.hopname = parseInt(args[1])

  echo(nick)

proc setCmd(user: var User, args: seq[string]) =
  if c.registered:
    return
  
  if args.len < 4:
    errNeedMoreParams()
    return

  if not startsWith(args[3], ":"):
    discard sendClient("Error: " & "Realname must be prefixed with ':'")
    return
  
  user.username = args[0]
  user.hostname = args[1]
  user.servername = args[2]
  user.realname = args[3..^1]

  echo(user)

proc cmdHandler*(command: string, args: seq[string]) =
  case command:
  of "PASS": cmd.pass.setCmd(args)
  of "NICK": cmd.nick.setCmd(args)
  of "USER": cmd.user.setCmd(args)

  if cmd.pass.password.len > 0 and
  cmd.nick.nickname.len > 0 and
  cmd.user.username.len > 0 and
  c.registered == false:
    c.registered = true
    echo("User ", cmd.user.username, " registered!")
    discard sendClient("User " & cmd.user.username & " registered!")