import 
  asynchttpserver, 
  asyncdispatch, 
  os, strutils, 
  mimetypes, 
  times, 
  parseopt,
  strutils,
  uri,
  strformat

from httpcore import HttpMethod, HttpHeaders

import
  static_server/config


const 
  name = pkgTitle
  version = pkgVersion
  style = "style.css".slurp
  description = pkgDescription
  author = pkgAuthor

let usage = """ $1 v$2 - $3
  (c) 2014-2018 $4

  Usage:
    static_server [-p:port] [directory]

  Arguments:
    directory      The directory to serve (default: current directory).

  Options:
    -p, --port     The port to listen to (default: 1337).
    -a, --address  The address to listen to (default: 127.0.0.1).
""" % [name, version, description, author]
import finder

type 
  NimHttpResponse* = tuple[
    code: HttpCode,
    content: string,
    headers: HttpHeaders]
  NimHttpSettings* = object
    logging*: bool
    finder*: Finder
    mimes*: MimeDb
    port*: Port
    address*: string
    name: string
    version*: string

proc h_page(settings:NimHttpSettings, content: string, title=""): string =
  var footer = """<div id="footer">$1 v$2</div>""" % [settings.name, settings.version]
  result = """
<!DOCTYPE html>
<html>
  <head>
    <title>$1</title>
    <style type="text/css">$2</style>
    <meta charset="UTF-8">
  </head>
  <body>
    <h1>$1</h1>
    $3
    $4
  </body>
</html>
  """ % [title, style, content, footer]

proc relativePath(path, cwd: string): string =
  var path2 = path
  if cwd == "/":
    return path
  else:
    path2.delete(0, cwd.len-1)
  var relpath = path2.replace("\\", "/")
  if (not relpath.endsWith("/")) and (not path.existsFile):
    relpath = relpath&"/"
  if not relpath.startsWith("/"):
    relpath = "/"&relpath
  return relpath

proc sendNotFound(settings: NimHttpSettings, path: string): NimHttpResponse = 
  var content = "<p>The page you requested cannot be found.<p>"
  return (code: Http404, content: h_page(settings, content, $Http404), headers: newHttpHeaders())

proc sendNotImplemented(settings: NimHttpSettings, path: string): NimHttpResponse =
  var content = "<p>This server does not support the functionality required to fulfill the request.</p>"
  return (code: Http501, content: h_page(settings, content, $Http501), headers: newHttpHeaders())

proc sendStaticFile(settings: NimHttpSettings,path:string, content: string): NimHttpResponse =
  let mimes = settings.mimes
  var ext = path.splitFile.ext
  if ext == "":
    ext = ".txt"
  ext = ext[1 .. ^1]
  let mimetype = mimes.getMimetype(ext.toLowerAscii)
  return (code: Http200, content: content, headers: {"Content-Type": mimetype}.newHttpHeaders)


proc printReqInfo(settings: NimHttpSettings, req: Request) =
  if not settings.logging:
    return
  echo getTime().local, " - ", req.hostname, " ", req.reqMethod, " ", req.url.path

proc handleCtrlC() {.noconv.} =
  echo "\nExiting..."
  quit()

setControlCHook(handleCtrlC)

proc serve*(settings: NimHttpSettings) =
  var server = newAsyncHttpServer()
  proc handleHttpRequest(req: Request): Future[void] {.async.} =
    printReqInfo(settings, req)
    var path = req.url.path.replace("%20", " ").decodeUrl()
    if len(path) <= 1:
      path = (path / "index.html")
    let stripedPath = path.strip(leading=true,trailing=false,chars={'/'})
    var res: NimHttpResponse 
    if req.reqMethod != HttpGet:
      res = sendNotImplemented(settings, path)
    else:
      if settings.logging:
        echo &"get content by path:{stripedPath}" 
      try:
        let content = settings.finder.get(stripedPath)
        res = sendStaticFile(settings,stripedPath,content)
      except:
        res = sendNotFound(settings, path)
    await req.respond(res.code, res.content, res.headers)
  echo settings.name, " v", settings.version, " started on port ", int(settings.port), "." 
  asyncCheck server.serve(settings.port, handleHttpRequest, settings.address)

when isMainModule:

  var port = Port(1337)
  var address = ""
  var logging = false
  var www = getCurrentDir()
  
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "log", "l":
        logging = true
      of "help", "h":
        echo usage
        quit(0)
      of "version", "v":
        echo version
        quit(0)
      of "address", "a":
        address = val
      of "port", "p":
        try:
          port = Port(val.parseInt)
        except:
          if val == "":
            echo "Port not set."
            quit(2)
          else:
            echo "Error: Invalid port: '", val, "'"
            echo "Running on default port instead."
      else:
        discard
    of cmdArgument:
      var dir: string
      if key.isAbsolute:
        dir = key
      else:
        dir = www/key
      if dir.existsDir:
        www = expandFilename dir
      else:
        echo "Error: Directory '"&dir&"' does not exist."
        quit(1)
    else: 
      discard
  
  var settings: NimHttpSettings
  settings.finder = Finder(fType:FinderType.fs)
  initFinder(settings.finder,www)
  settings.logging = logging
  settings.mimes = newMimeTypes()
  settings.mimes.register("htm", "text/html")
  settings.address = address
  settings.name = name
  settings.version = version
  settings.port = port

  serve(settings)
  runForever()
