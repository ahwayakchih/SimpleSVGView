sub init()
	m.top.functionName = "svgToPNG"

	m.knownColors = {
		white: &hFFFFFFFF,
		black: &h000000FF
	}
end sub

sub start(name as string)
	m.timer = createObject("roTimespan")
	if m.checkmarks = invalid
		m.checkmarks = []
	end if
	m.checkname = name
end sub

sub checkpoint(name as string)
	m.checkmarks.push([m.checkname + "_" + name, m.timer.totalMilliseconds()])
	m.top.status = name
	m.timer.mark()
end sub

sub finish(status as string)
	info = {
		a_info: "SVG rendering of in milliseconds"
	}
	total = 0
	index = asc("b")
	for each mark in m.checkmarks
		total += mark[1]
		info[chr(index) + "_" + mark[0]] = mark[1]
		index += 1
	end for

	info[chr(index) + "_" + status + "_total"] = total
	m.top.performanceInfo = info
	m.top.status = status
end sub

sub svgToPNG()
	start("svgToPNG")

	fields = m.top.getFields()

	width = fields.width
	height = fields.height
	padding = fields.padding
	color = fields.color
	svgData = fields.svgData
	cachePath = fields.cachePath

	dataId = getStringId(svgData)
	renderedImagePath = getOutputFileName(cachePath, dataId, width, height, padding, color) + ".png"

	m.top.renderedImagePath = renderedImagePath
	m.top.qrBits = []
	m.top.qrString = ""
	m.top.performanceInfo = {}

	checkpoint("init")

	fs = createObject("roFileSystem")
	if fs.exists(renderedImagePath)
		finish("ready")
		return
	end if

	parsedData = parseSVG(svgData)
	checkpoint("parsing")

	if parsedData = invalid
		finish("failed")
		return
	end if

	pngData = renderParsedDataToPNG(parsedData, width, height, color)
	checkpoint("rendering")

	if pngData = invalid
		finish("failed")
		return
	end if

	saved = pngData.writeFile(renderedImagePath)
	checkpoint("saving")

	if saved <> true
		finish("failed")
		return
	end if

	finish("ready")
end sub

sub svgToQRBits()
	start("svgToQRBits")

	svgData = m.top.svgData

	m.top.renderedImagePath = ""
	m.top.qrBits = []
	m.top.qrString = ""
	m.top.performanceInfo = {}

	checkpoint("init")

	parsedData = parseSVG(svgData)
	checkpoint("parsing")

	if parsedData = invalid
		finish("failed")
		return
	end if

	qrBits = readQRBits(parsedData)
	checkpoint("converting")

	if qrBits = invalid
		finish("failed")
		return
	end if

	m.top.qrBits = qrBits
	m.top.qrString = toHalfASCII(qrBits)
	finish("ready")
end sub

sub qrBitsToPNG()
	start("qrBitsToPNG")

	fields = m.top.getFields()

	width = fields.width
	height = fields.height
	padding = fields.padding
	color = fields.color
	qrBits = fields.qrBits
	qrString = fields.qrString
	cachePath = fields.cachePath

	if qrBits = invalid
		finish("failed")
		return
	end if

	if color = 0
		color = m.knownColors.black
	end if

	dataId = getStringId(qrString)
	renderedImagePath = getOutputFileName(cachePath, dataId, width, height, padding, color) + ".png"

	m.top.renderedImagePath = renderedImagePath
	m.top.performanceInfo = {}

	checkpoint("init")

	fs = createObject("roFileSystem")
	if fs.exists(renderedImagePath)
		finish("ready")
		return
	end if

	pngData = renderQRBitsToPNG(qrBits, width, height, padding, color)
	checkpoint("rendering")

	if pngData = invalid
		finish("failed")
		return
	end if

	saved = pngData.writeFile(renderedImagePath)
	checkpoint("saving")

	if saved <> true
		finish("failed")
		return
	end if

	finish("ready")
end sub

sub svgToQRBitsToPNG()
	svgToQRBits()
	qrBitsToPNG()
end sub

function parseSVG(svgData as string) as object
	svg = createObject("roXMLElement")
	if not svg.parse(svgData)
		return invalid
	end if

	paths = svg.getNamedElementsCi("path")
	if paths.count() < 1
		return invalid
	end if

	result = {
		x: 0,
		y: 0,
		width: -1,
		height: -1,
		paths: []
	}

	svgAttributes = svg.getAttributes()
	if hasValue(svgAttributes.viewBox)
		result.append(parseViewBoxRect(svgAttributes.viewBox))
	end if

	paths.resetIndex()
	path = invalid
	while true
		path = paths.getIndex()
		if path = invalid
			exit while
		end if

		pathAttributes = path.getAttributes()
		if hasValue(pathAttributes.d)
			result.paths.push({
				area: parsePathBlocks(pathAttributes.d),
				attrs: pathAttributes
			})
		end if
	end while

	return result
end function

function parseViewBoxRect(viewBoxData as string) as object
	points = viewBoxData.tokenize(" ")

	if points.count() < 4
		return {}
	end if

	x = val(points[0])
	y = val(points[1])

	return {
		x: x,
		y: y,
		width: val(points[2]) - x,
		height: val(points[3]) - y
	}
end function

function parsePathBlocks(pathData as string) as object
	steps = pathData.split("")

	NUL_STATE = 0
	AMX_STATE = 1  ' absolute move-to
	AMY_STATE = 2  ' absolute move-to
	ALX_STATE = 3  ' absolute line-to
	ALY_STATE = 4  ' absolute line-to
	RLX_STATE = 5  ' relative line-to
	RLY_STATE = 6  ' relative line-to
	AHX_STATE = 7  ' absolute horizontal-line-to
	RHX_STATE = 8  ' relative horizontal-line-to
	AVY_STATE = 9  ' absolute vertical-line-to
	RVY_STATE = 10 ' relative vertical-line-to

	blocks = []
	blocksArea = {top: 0, left: 0, bottom: 0, right: 0, width: 0, height: 0, blockSize: 0}
	block = invalid
	state = NUL_STATE
	num = ""
	zero = asc("0")
	nine = asc("9")
	index = 0
	for each data in steps
		char = asc(data)
		if data = "+" or data = "-" or data = "." or (char >= zero and char <= nine)
			num += data
			goto skip
		else if num <> ""
			' parse number
			if state = AMX_STATE
				state = AMY_STATE
				block.x = num.toFloat()
				x = block.x
			else if state = AMY_STATE
				state = ALX_STATE
				block.y = num.toFloat()
				y = block.y
			else if state = ALX_STATE
				state = ALY_STATE
				x = num.toFloat()
				' Ignore this point if it matches block.y or block.y, we only need one other point
				if x <> block.x
					block.width = abs(x - block.x)
				end if
			else if state = ALY_STATE
				state = ALX_STATE
				y = num.toFloat()
				' Ignore this point if it matches block.y or block.y, we only need one other point
				if y <> block.y
					block.height = abs(y - block.y)
				end if
			else if state = RLX_STATE
				state = RLY_STATE
				x += num.toFloat()
				' Ignore this point if it matches block.y or block.y, we only need one other point
				if x <> block.x
					block.width = abs(x - block.x)
				end if
			else if state = RLY_STATE
				state = RLX_STATE
				y += num.toFloat()
				' Ignore this point if it matches block.y or block.y, we only need one other point
				if y <> block.y
					block.height = abs(y - block.y)
				end if
			else if state = AHX_STATE
				x = num.toFloat()
				' Ignore this point if it matches block.y or block.y, we only need one other point
				if x <> block.x
					block.width = abs(x - block.x)
				end if
			else if state = RHX_STATE
				x += num.toFloat()
				' Ignore this point if it matches block.y or block.y, we only need one other point
				if x <> block.x
					block.width = abs(x - block.x)
				end if
			else if state = AVY_STATE
				y = num.toFloat()
				' Ignore this point if it matches block.y or block.y, we only need one other point
				if y <> block.y
					block.height = abs(y - block.y)
				end if
			else if state = RVY_STATE
				y += num.toFloat()
				' Ignore this point if it matches block.y or block.y, we only need one other point
				if y <> block.y
					block.height = abs(y - block.y)
				end if
			end if
		end if

		num = ""

		if data = "M"
			state = AMX_STATE
			block = {x: 0.0, y: 0.0, width: 0.0, height: 0.0}
			x = 0
			y = 0
		else if data = "L"
			state = ALX_STATE
			x = 0
			y = 0
		else if data = "l"
			state = RLX_STATE
		else if data = "H"
			state = AHX_STATE
			x = 0
		else if data = "h"
			state = RHX_STATE
		else if data = "V"
			state = AVY_STATE
			y = 0
		else if data = "v"
			state = RVY_STATE
		else if data = "z" or data = "Z"
			state = NUL_STATE
			blocks.push(block)
			index += 1
			if index = 1 or block.y < blocksArea.top
				blocksArea.top = block.y
			end if
			if index = 1 or block.x < blocksArea.left
				blocksArea.left = block.x
			end if
			if index = 1 or block.y > blocksArea.bottom
				blocksArea.bottom = block.y + block.height
			end if
			if index = 1 or block.x > blocksArea.right
				blocksArea.right = block.x + block.width
			end if
			block = invalid
		else if data = " " or data = ","
			' skip whitespace
		else
			checkpoint("unknown_svg_state")
			return invalid
		end if

		skip:
	end for

	blocksArea.blockSize = blocks[0]?.width
	blocksArea.blocks = blocks
	blocksArea.width = blocksArea.right - blocksArea.left
	blocksArea.height = blocksArea.bottom - blocksArea.top

	return blocksArea
end function

function parseColor(color as string) as integer
	if not color.startsWith("#")
		result = m.knownColors[color]
		if result = invalid
			result = m.knownColors.black
		end if
		return result
	end if

	ba = createObject("roByteArray")
	ba.fromHexString(color.mid(1))

	r = ba[0]
	g = ba[1]
	b = ba[2]
	a = &hFF

	if ba.count() > 3
		a = ba[3]
	end if

	if ba.isLittleEndianCPU()
		return (r << 24) + (g << 16) + (b << 8) + a
	else
		return (a << 24) + (b << 16) + (g << 8) + r
	end if
end function

function renderParsedDataToPNG(parsedData as object, targetWidth as float, targetHeight as float, targetColor as integer) as object
	bmp = createObject("roBitmap", {
		width: parsedData.width,
		height: parsedData.height,
		alphaEnable: false
	})

	checkpoint("preparing_bitmap")

	color = targetColor

	for each path in parsedData.paths
		color = targetColor
		if color = 0
			color = parseColor(stringOr(path.attrs?.fill, "#000000"))
		end if
		for each block in path.area.blocks
			bmp.drawRect(block.x, block.y, block.width, block.height, color)
		end for
	end for

	bmp.finish()

	checkpoint("drawing_original")

	if targetWidth = parsedData.width and targetHeight = parsedData.height
		return bmp.getPNG(0, 0, parsedData.width, parsedData.height)
	end if

	scaledBmp = createObject("roBitmap", {
		width: targetWidth,
		height: targetHeight,
		alphaEnable: false
	})

	checkpoint("preparing_scaled_bitmap")

	scaleX = fix(targetWidth / parsedData.width)
	scaleY = fix(targetHeight / parsedData.height)

	x = fix((targetWidth / 2) - ((parsedData.width * scaleX) / 2))
	y = fix((targetHeight / 2) - ((parsedData.height * scaleY) / 2))

	if not scaledBmp.drawScaledObject(x, y, scaleX, scaleY, bmp)
		return invalid
	end if

	scaledBmp.finish()
	checkpoint("drawing_scaled")

	return scaledBmp.getPNG(0, 0, targetWidth, targetHeight)
end function

' This takse just the first path. If SVG was more complicated than that, this will create invalid data.
function readQRBits(parsedData as object) as object
	path = parsedData.paths[0]
	if path = invalid
		return invalid
	end if

	area = path.area
	if area = invalid
		return invalid
	end if

	if area.width < 1 or area.height < 1 or area.width <> area.height
		return invalid
	end if

	ax = area.left
	ay = area.top

	rowSize = area.width / area.blockSize
	blockSize = area.blockSize

	areaSize = rowSize * rowSize
	DIM result[areaSize]

	for each block in area.blocks
		x = fix((block.x - ax) / blockSize)
		y = fix((block.y - ay) / blockSize)
		result[(y*rowSize) + x] = true
	end for

	' Make sure result has correct number of items set
	if result[areaSize - 1] = invalid
		result[areaSize - 1] = false
	end if

	return result
end function

function renderQRBitsToPNG(qrBits as object, targetWidth as float, targetHeight as float, targetPadding as float, targetColor as integer) as object
	size = sqr(qrBits.count())

	bmp = createObject("roBitmap", {
		width: targetWidth,
		height: targetHeight,
		alphaEnable: false
	})

	checkpoint("preparing_bitmap")

	color = targetColor

	width = targetWidth - (targetPadding * 2)
	height = targetHeight - (targetPadding * 2)

	if width <= height
		cellSize = fix(width / size)
	else
		cellSize = fix(height / size)
	end if

	x = fix((targetWidth / 2) - ((size * cellSize) / 2))
	y = fix((targetHeight / 2) - ((size * cellSize) / 2))

	row = 0
	col = 0
	for row = 0 to size - 1
		for col = 0 to size - 1
			bit = qrBits[(row * size) + col]
			if bit = true
				bmp.drawRect((col * cellSize) + x, (row * cellSize) + y, cellSize, cellSize, color)
			end if
		end for
	end for

	bmp.finish()
	checkpoint("drawing")

	return bmp.getPNG(0, 0, targetWidth, targetHeight)
end function

function getStringId(data as string) as string
	ba = createObject("roByteArray")
	ba.fromASCIIString(data)

	hash = createObject("roEVPDigest")
	hash.setup("sha256")
	return hash.process(ba)
end function

function getOutputFileName(cachePath as string, dataId as string, width as float, height as float, padding as float, color as dynamic) as string
	return cachePath + dataId + "-" + width.toStr() + "x" + height.toStr() + "-" + padding.toStr() + "-" + color.toStr()
end function

function hasValue(value as dynamic) as boolean
	return (type(value) = "roString" or type(value) = "String") and value.trim().len() > 0
end function

function stringOr(value as dynamic, defaultValue as string) as string
	if value = invalid or not hasValue(value)
		return defaultValue
	end if

	return value
end function

' Near carbon-copy of my code submitted to qrcode-generator project:
' https://github.com/kazuhikoarase/qrcode-generator/pull/110
function toHalfASCII(qrBits as object, padding = 0 as integer) as string
	cellSize = 1

	if padding < 0
		padding = 2
	end if

	bitRowSize = sqr(qrBits.count())
	size = (bitRowSize * cellSize) + (padding * 2)
	min = padding
	max = size - padding

	blocks = {
		"██": "█"
		"█ ": "▀"
		" █": "▄"
		"  ": " "
	}

	blocksLastLineNoPadding = {
		"██": "▀"
		"█ ": "▀"
		" █": " "
		"  ": " "
	}

	white = "█"
	black = " "

	ascii = ""
	NL = chr(10)

	for y = 0 to size - 1 step 2
		r1 = fix((y - min) / cellSize)
		r2 = fix((y + 1 - min) / cellSize)
		for x = 0 to size - 1 step 1
			p = white

			if min <= x and x < max and min <= y and y < max and qrBits[(r1 * bitRowSize) +  fix((x - min) / cellSize)] = true
				p = black
			end if

			if min <= x and x < max and min <= y + 1 and y + 1 < max and qrBits[(r2 * bitRowSize) + fix((x - min) / cellSize)] = true
				p += black
			else
				p += white
			end if

			' Output 2 characters per pixel, to create full square. 1 character per pixels gives only half width of square.
			if padding < 1 and y + 1 >= max
				ascii += blocksLastLineNoPadding[p]
			else
				ascii += blocks[p]
			end if
		end for

		ascii += NL
	end for

	if size mod 2 <> 0 and padding > 0
		return ascii.left(ascii.len() - size - 1) + String(size, "▀")
	end if

	return ascii.left(ascii.len() - 1)
end function
