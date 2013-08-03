# Router object, invocation returns a function meant to dispatch  http requests.
Router = (options = {}) ->

# Required modules, all of them from standard node library, no external dependencies.	

  urlparse = require('url').parse
  querystring = require('querystring')
  fs       = require('fs')
  path_tools = require('path')
#  util      = require('util')
  spawn  = require('child_process').spawn

# End of required modules


# Constants.	

  mime_types =
    '':      'application/octet-stream'
    '.bin':   'application/octet-stream'
    '.com':   'application/x-msdownload'
    '.exe':   'application/x-msdownload'
    '.htm':  'text/html'
    '.html': 'text/html'
    '.txt':  'text/plain'
    '.css':  'text/css'
    '.mid':  'audio/midi'
    '.midi': 'audio/midi'
    '.wav':  'audio/x-wav'
    '.mp3':  'audio/mpeg'
    '.ogg':  'audio/ogg'
    '.mp4':  'video/mp4'
    '.mpeg': 'video/mpeg'
    '.avi':  'video/x-msvideo'
    '.pct':  'image/pict'
    '.pic':  'image/pict'
    '.pict': 'image/pict'
    '.ico' : 'image/x-icon'
    '.jpg':  'image/jpg'
    '.jpeg': 'image/jpg'
    '.png':  'image/png'
    '.gif' : 'image/gif'
    '.pcx':  'image/x-pcx'
    '.tiff': 'image/tiff'
    '.svg':  'image/svg+xml'
    '.xul':  'text/xul'
    '.rtf':  'application/rtf'
    '.xls':  'application/vnd.ms-excel'
    '.xml':  'application/xml'
    '.doc':  'application/msword'
    '.pdf':  'application/pdf'
    '.mobi': 'application/x-mobipocket-ebook'
    '.epub': 'application/epub+zip'
    '.js':   'application/x-javascript'
    '.json': 'application/json'
    '.sh':   'text/x-sh'
    '.py':   'text/x-python'
    '.rb':   'text/x-ruby'
    '.c':    'text/x-csrc'
    '.cpp':  'text/x-c++src'

  default_options =
    logging: true
    log: console.log
    static_route: "#{process.cwd()}/public"
    serve_static: true
    list_dir: true
    default_home: ['index.html', 'index.htm', 'default.htm']
    cgi_dir: "cgi-bin"
    serve_cgi: true
    served_by: 'Node Simple Router'
    version: '0.3.6'

  escaped_icon = '%89PNG%0D%0A%1A%0A%00%00%00%0DIHDR%00%00%00%20%00%00%00%20%08%06%00%00%00szz%F4%00%00%00%04sBIT%08%08%08%08%7C%08d%88%00%00%01fIDATX%85%EDWQ%AE%C4%20%08%1C%5E%F6%28%3D%28%07%ED%5D%D8%8F%D6%16%15%14l%93%FDy%93l%B2%A9%8A%E3%08C%0B%FC%E3%C7%A0%F2G%00Q%0F%C9%9E%DE%80E%E6sh%18k%8D@%B3%B1%F0%3D%9D%B8%E5%E4%84%E2c%E0%CF%1A%D3df%9B%F7%E3t%F2/%BF1%3E%DE%80%00%D2%29%D1n%7E%CBk%93b%83%01%D7s%5D%02CL%EE%D5_%D7%135%AF%A0%9C%7Cx%15/%C1%240%C4%EA%E9%B3%04%5C%15X%24T%7EO%09%98%D0%A7%7F%89%C8%90%80%A9B%7B%05%2C%D2%D7%BE%01%9D%80%AA%3A%9EU%81R%E0%26A%29U%C2W%60V%04%13%F5I%29%E8%A6%3A%A7%07%82V%5C%C6%3C%8B%AE%D6%8E%AC%D80%A6T%12%86%7C%E1RD%99%A4%E5%88%19%02%E1%EE%A8WT%A4%FCjI%1BQ%CE%1D%5B%22A+vB%BD%EA%80i%02%1Ao%F6%88%14%81%BC%0A%27%CF%CAAk%F2K%0A%9C%A1M%15%F6%7D%97j%F3%09%96%09%84q%B9%26L%15%D2%04%C81%AF%82m%DB%C8%94%BE%25%B1J%60%8Ah%87%3CUX%22%E0%A9%A0%1A%12%00R%F9Pm%5C%A9%F0%9A%02%A1%96l%20%D6%8E%0DY%DDzd%A2%22%EF%91%0F%A3%B8%90%B5%F7%81%06%D5%87Ir%ED%B3O3%F4%95@%C0%A1%C0%A0%03%02%B8%92%F0R%60%D5%EB%E9x%05ZK%00%06%7D%01Z%7E%83%C5%C9%DE%7C%81%00%00%00%00IEND%AEB%60%82'

# End of Constants.


# Auxiliary functions.	

  _extend = (obj_destiny, obj_src) ->
    for key, val of obj_src
      obj_destiny[key] = val
    obj_destiny

  _parsePattern = (pat) ->
    re = /\/:([A-Za-z0-9_]+)+/g
    m = pat.match(re)
    if m
      pars = (x.slice(2) for x in m)
      retpat = pat.replace(re, "/([A-Za-z0-9_\-]+)")
    else
      retpat = pat
      pars = null
    {pattern: retpat, params: pars}
  
  _make_request_wrapper = (cb) ->
    wrapper = (req, res) ->
      body = []
      req.setEncoding('binary')
      req.on 'data', (chunk) ->
        body.push chunk
      req.on 'end', () ->
        body = body.join('')
        contentType = 'application/x-www-form-urlencoded'
        if req.headers['content-type']
          contentType = req.headers['content-type']
        if contentType is 'text/plain'
          body = body.replace('\r\n', '')
        mp_index = contentType.indexOf('multipart/form-data')
        req.post = if mp_index is -1 then _bodyparser(body) else _multipartparser(body, contentType)
        req.body = _extend req.body, req.post
        try
          cb(req, res)
        catch e
          dispatch._500 req, res, req.url, e.toString()
    wrapper

# End of Auxiliary functions.	


# Dispatcher (router) function.	

  dispatch = (req, res) ->
    parsed = urlparse(req.url)
    pathname = parsed.pathname
    req.get = if parsed.query? then querystring.parse(parsed.query) else {}
    req.body = _extend {}, req.get
    method = req.method.toLowerCase()
    if dispatch.logging
      dispatch.log "#{req.client.remoteAddress} - [#{new Date().toLocaleString()}] - #{method.toUpperCase()} #{pathname} - HTTP #{req.httpVersion}"
    for route in dispatch.routes[method]
      m = pathname.match(route.pattern)
      if m isnt null
        if route.params
          req.params = {}
          args = m.slice(1)
          for param, index in route.params
            req.params[param] = args[index]
        return route.handler(req, res)

    if pathname is "/"
      for home_page in dispatch.default_home
        full_path = "#{dispatch.static_route}/#{home_page}"
        try
          if fs.existsSync full_path
            return dispatch.static "/#{home_page}", req, res
        catch error
          dispatch.log error.toString() unless not dispatch.logging
      if dispatch.list_dir
        return dispatch.directory dispatch.static_route, '.', res
      else
        return dispatch._404 req, res, pathname

    if dispatch.serve_static
      return dispatch.static pathname, req, res
    else
      return dispatch._404 req, res, pathname

# End of Dispatcher (router) function.	


# Extends default options with client provided ones, and then using that extends dispatcher function itself.	

  _extend(default_options, options)
  _extend(dispatch, default_options)

# End of Extends default options with client provided ones, and then using that extends dispatcher function itself.	


# Directory listing template	

  _dirlist_template = """
      <!DOCTYPE  html>
      <html>
        <head>
            <title>Directory listing for <%= @cwd %></title>
            <style type="text/css" media="screen">

            </style>
        </head>
        <body>
            <h2>Directory listing for <%= @cwd %></h2>
            <hr/>
            <ul id="dircontents">
              <%= @cwd_contents %>
            </ul>
            <hr/>
            <p><strong>Served by #{dispatch.served_by} v#{dispatch.version}</strong></p>
        </body>
      </html>
      """

# End of Directory listing template	


# Dispatch object methods, not meant to be called/used by the client.	

  _pushRoute = (pattern, callback, method) ->
    params = null
    if typeof pattern is "string"
      parsed = _parsePattern(pattern)
      pattern = new RegExp("^#{parsed.pattern}$")
      params = parsed.params
    dispatch.routes[method].push {pattern: pattern, handler: callback, params: params}
    dispatch.routes[method].sort (it1, it2) -> it2.pattern.toString().length > it1.pattern.toString().length


  _multipartparser = (body, content_type) ->
    resp = "multipart-data": []
    boundary = content_type.split(/;\s+/)[1].split('=')[1].trim()
    parts = body.split("--#{boundary}")
    for part in parts
      if part and part.match(/Content-Disposition:/i)
        #dispatch.log "PART: #{part}"
        obj = {}
        m = part.match(/Content-Disposition:\s+(.+?);/i)
        if m
          obj.contentDisposition = m[1]
        m = part.match(/name="(.+?)"/i)
        if m
          obj.fieldName = m[1]
        m = part.match(/filename="(.+?)"/i)
        if m
          obj.fileName = m[1]
        m = part.match(/Content-Type:\s+(.+?)\s/i)
        if m
          obj.contentType = m[1]
        else
          obj.contentType = 'text/plain'
        m = part.match(/Content-Length:\s+(\d+?)/i)
        if m
          obj.contentLength = m[1]

        m = part.match /\r\n\r\n/
        if m
          obj.fileData = part.slice(m.index + 4, -2)
          obj.fileLen = obj.fileData.length
        
        resp['multipart-data'].push obj     
    resp

  _bodyparser = (body) ->
    if body.indexOf('=') isnt -1
      try
        return querystring.parse(body)
      catch e
        dispatch.log e unless not dispatch.logging
    try
      return JSON.parse(body)
    catch e
      dispatch.log e unless not dispatch.logging
    body

# End of Dispatch object methods, not meant to be called/used by the client.	


# Dispatch function properties and methods 	

  dispatch.routes =
    get:  []
    post: []
    put:  []
    delete:  []

  dispatch.static = (pathname, req, res) ->
    if pathname.indexOf("#{dispatch.cgi_dir}/") isnt - 1 and dispatch.serve_cgi is true
      try
        return dispatch.cgi(pathname, req, res)
      catch e
        dispatch.log e.toString() unless not dispatch.logging
        return dispatch._500 null, res, pathname
        
    full_path = "#{dispatch.static_route}#{unescape(pathname)}"
    fs.exists full_path, (exists) ->
      if exists
        fs.stat full_path, (err, stats) ->
          if err
            dispatch.log err.toString() unless not dispatch.logging
            return dispatch._500 null, res, pathname
          if stats
            if stats.isDirectory()
              return dispatch.directory(full_path, pathname, res) unless not dispatch.list_dir
              return dispatch._405(null, res, pathname, "Directory listing not allowed")
            if stats.isFile()
              fd = fs.createReadStream full_path
              res.writeHead 200, {'Content-Type': mime_types[path_tools.extname(full_path)] or 'text/plain'}
              fd.pipe res
      else
        if unescape(pathname).match(/favicon\.ico$/)
          res.writeHead 200, {'Content-Type': mime_types[path_tools.extname('favicon.ico')] or 'application/x-icon'}
          res.end new Buffer(unescape(escaped_icon), 'binary')
        else
          dispatch._404 null, res, pathname

# CGI support (improved on 2012-09-07)

  dispatch.cgi = (pathname, req, res) ->
    respbuffer = ''
    full_path = "#{dispatch.static_route}#{unescape(pathname)}"
    query_pairs = ("#{key}=#{val}" for key, val of req.get)
    if query_pairs.length isnt 0
      process.env["QUERY_STRING"] = "?#{query_pairs.join('&')}"
    else
      process.env['QUERY_STRING'] = ''
    process.env['REMOTE_ADDRESS'] = req.connection.remoteAddress
    process.env['REQUEST_URL'] = req.url
    
    child = spawn(full_path, [])
    child.stderr.pipe process.stderr

    body = []
    if req.method.toLowerCase() is "post"
      req.on 'data', (chunk) ->
        body.push(chunk)
      req.on 'end', ->
        body = body.join ''
        req.post = _bodyparser body
        req.body = _extend req.body, req.post
        try
          json = JSON.stringify(req.body)
          child.stdin.write("#{json}\n")
        catch e
          ''
    else
      try
        json = JSON.stringify(req.body)
        child.stdin.write("#{json}\n")
      catch e
        ''


    child.stdout.on 'data', (data) ->
      arrdata = data.toString().split('\n')
      for elem in arrdata
        if (elem.substr(0,8).toLowerCase() isnt "content-")
          respbuffer += elem
        else
          pair = elem.split(/:\s+/)
          try
            res.setHeader(pair[0], pair[1])
          catch e
            ''
      
    child.stdout.on 'end', (moredata) ->
      try
        respbuffer += moredata unless not moredata
        res.end respbuffer
      catch e
       ''

    return 0

# End of CGI support

  dispatch.directory = (fpath, path, res) ->
    resp = _dirlist_template
    resp = resp.replace("<%= @cwd %>", path) while resp.indexOf("<%= @cwd %>") isnt -1
    fs.readdir fpath, (err, files) ->
      if err
        return dispatch._404(null, res, path)
      else
        links = ("<li><a href='#{path}/#{querystring.escape(file)}'>#{file}</a></li>" for file in files).join('')
        resp = resp.replace("<%= @cwd_contents %>", links)
      res.writeHead 200, {'Content-type': 'text/html'}
      res.end resp


  dispatch.get = (pattern, callback) ->
      _pushRoute pattern, callback, 'get'

  dispatch.post = (pattern, callback) ->
    _pushRoute pattern, _make_request_wrapper(callback), 'post'

  dispatch.put = (pattern, callback) ->
    _pushRoute pattern, _make_request_wrapper(callback), 'put'

  dispatch.delete = (pattern, callback) ->
    _pushRoute pattern, callback, 'delete'

  dispatch.del = (pattern, callback) ->
    _pushRoute pattern, callback, 'delete'


  dispatch._404 = (req, res, path) ->
    res.writeHead(404, {'Content-Type': 'text/html'})
    res.end("""
            <h2>404 - Resource #{path} not found at this server</h2>
            <hr/><h3>Served by #{dispatch.served_by} v#{dispatch.version}</h3>
            <p style="text-align: center;"><button onclick='history.back();'>Back</button></p>
        """)

  dispatch._405 = (req, res, path, message) ->
    res.writeHead(405, {'Content-Type': 'text/html'})
    res.end("""
                <h2>405 - Resource #{path}: #{message}</h2>
                <hr/><h3>Served by #{dispatch.served_by} v#{dispatch.version}</h3>
                <p style="text-align: center;"><button onclick='history.back();'>Back</button></p>
            """)

  dispatch._500 = (req, res, path, message) ->
    res.writeHead(500, {'Content-Type': 'text/html'})
    res.end("""
                <h2>500 - Internal server error at #{path}: #{message}</h2>
                <hr/><h3>Served by #{dispatch.served_by} v#{dispatch.version}</h3>
              <p style="text-align: center;"><button onclick='history.back();'>Back</button></p>
            """)

# End of Dispatch function properties and methods 	


# Returns dispatch (router function)	    
  dispatch


# Exports "router factory function"
module.exports = Router
