# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

@reset_canvas = ->
  o.fillStyle = "white"
  o.fillRect 0, 0, c.width, c.height
  o.fillStyle = "black"

# here's a really simple little drawing app so people can try their luck at
# the lottery that is offline handwriting recognition
@open_picker = ->
  e = document.createEvent("MouseEvents")
  e.initEvent "click", true, true
  document.getElementById("picker").dispatchEvent e

@picked_file = (file) ->
  return unless file
  
  # document.getElementById("output").className = 'processing'
  ext = file.name.split(".").slice(-1)[0]
  reader = new FileReader()
  if file.type is "image/x-portable-bitmap" or ext is "pbm" or ext is "pgm" or ext is "pnm" or ext is "ppm"
    reader.onload = ->
      reset_canvas()
      document.getElementById("text").innerHTML = "Recognizing Text... This may take a while..."
      o.font = "30px sans-serif"
      o.fillText "No previews for NetPBM format.", 50, 100
      runOCR new Uint8Array(reader.result), true

    reader.readAsArrayBuffer file
  else
    reader.onload = ->
      img = new Image()
      img.src = reader.result
      img.onerror = ->
        reset_canvas()
        o.font = "30px sans-serif"
        o.fillText "Error: Invalid Image " + file.name, 50, 100

      img.onload = ->
        document.getElementById("text").innerHTML = "Recognizing Text... This may take a while..."
        reset_canvas()
        rat = Math.min(c.width / img.width, c.height / img.height)
        o.drawImage img, 0, 0, img.width * rat, img.height * rat
        tmp = document.createElement("canvas")
        tmp.width = img.width
        tmp.height = img.height
        ctx = tmp.getContext("2d")
        ctx.drawImage img, 0, 0
        image_data = ctx.getImageData(0, 0, tmp.width, tmp.height)
        runOCR image_data, true

    reader.readAsDataURL file

@runOCR = (image_data, raw_feed) ->
  document.getElementById("output").className = "processing"
  worker.onmessage = (e) ->
    document.getElementById("output").className = ""
    if "innerText" of document.getElementById("text")
      document.getElementById("text").innerText = e.data
    else
      document.getElementById("text").textContent = e.data
    document.getElementById("timing").innerHTML = "recognition took " + ((Date.now() - start) / 1000).toFixed(2) + "s"

  start = Date.now()
  image_data = o.getImageData(0, 0, c.width, c.height)  unless raw_feed
  worker.postMessage image_data
  lastWorker = worker
fisher_yates = (a) ->
  i = a.length - 1

  while i > 0
    j = Math.floor(Math.random() * (i + 1))
    temp = a[i]
    a[i] = a[j]
    a[j] = temp
    i--

@da_image = ->
  url = "/captcha/#{parseInt(Math.random() * 180)}.png"

  img = new Image()
  img.onerror = ->
    reset_canvas()
    o.font = "30px sans-serif"
    o.fillText "Error: Invalid Image", 50, 100

  img.onload = ->
    document.getElementById("text").innerHTML = "Recognizing Text... This may take a while..."
    reset_canvas()
    rat = Math.min(c.width / img.width, c.height / img.height)
    o.drawImage img, 0, 0, img.width * rat, img.height * rat
    tmp = document.createElement("canvas")
    tmp.width = img.width
    tmp.height = img.height
    ctx = tmp.getContext("2d")
    ctx.drawImage img, 0, 0
    dataURL = tmp.toDataURL('image/png')
    image_data = ctx.getImageData(0, 0, tmp.width, tmp.height)
    runOCR image_data, true
  img.src = url

@da_word = ->
  reset_canvas()
  font = fonts.shift() # do a rotation
  fonts.push font
  if Math.random() > 0.7
    phrase = font
  else
    phrase = quotes.shift() #quotes[Math.floor(quotes.length * Math.random())];
    quotes.push phrase
  WebFont.load
    google:
      families: [font]

    active: ->
      o.font = "30px \"" + font + "\""
      words = phrase.split(" ")
      buf = []
      n = 70
      i = 0

      while i < words.length
        buf.push words[i]
        if buf.join(" ").length > 15 or i is words.length - 1
          o.fillText buf.join(" "), 100, n
          buf = []
          n += 50
        i++
      runOCR phrase

c = document.getElementById("c")
o = c.getContext("2d")
drag = false
lastX = undefined
lastY = undefined
c.onmousedown = (e) ->
  drag = true
  lastX = 0
  lastY = 0
  e.preventDefault()
  c.onmousemove e

c.onmouseup = (e) ->
  drag = false
  e.preventDefault()
  runOCR()

c.onmousemove = (e) ->
  dot = (x, y) ->
    o.beginPath()
    o.moveTo x + r, y
    o.arc x, y, r, 0, Math.PI * 2
    o.fill()
  e.preventDefault()
  rect = c.getBoundingClientRect()
  r = 5
  if drag
    x = e.clientX - rect.left
    y = e.clientY - rect.top
    if lastX and lastY
      dx = x - lastX
      dy = y - lastY
      d = Math.sqrt(dx * dx + dy * dy)
      i = 1

      while i < d
        dot lastX + dx / d * i, lastY + dy / d * i
        i += 2
    dot x, y
    lastX = x
    lastY = y

document.body.ondragover = ->
  document.body.className = "dragging"
  false

document.body.ondragend = ->
  document.body.className = ""
  false

document.body.onclick = ->
  document.body.className = ""

document.body.ondrop = (e) ->
  e.preventDefault()
  document.body.className = ""
  picked_file e.dataTransfer.files[0]
  false

lastWorker = undefined
worker = new Worker("/assets/worker.js")
reset_canvas()
quotes = ["Hello World!!", "Hello my name is dug. I have just met you. I love you.", "ABC DEF GHI JKL MNO PQR STU VWX YZ", "abc def ghi jkl mno pqr stu vwx yz", "0 1 2 3 4 5 6 7 8 9", "One Two Three Four Five Six Seven Eight Nine Ten", "Life is good.", "A true magician never unveils his trick.", "Ceci n'est pas une pipe."]
fonts = ["Droid Sans", "Philosopher", "Alegreya Sans", "Chango", "Coming Soon", "Allan", "Cardo", "Bubbler One", "Bowlby One SC", "Prosto One", "Rufina", "Cantora One", "Denk One", "Play", "Architects Daughter", "Nova Square", "Inder", "Gloria Hallelujah", "Telex", "Comfortaa", "Merienda", "Boogaloo", "Krona One", "Orienta", "Sofadi One", "Source Sans Pro", "Revalia", "Overlock", "Kelly Slab", "Rye", "Butcherman", "Lato", "Milonga", "Aladin", "Princess Sofia", "Audiowide", "Italiana", "Michroma", "Cabin Condensed", "Jura", "Marko One", "PT Mono", "Bubblegum Sans", "Amaranth"]
fisher_yates fonts
fisher_yates quotes
o.font = "30px sans-serif"
o.fillText "rm -rf /", 100, 100
runOCR()
