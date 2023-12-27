sub init()
	m.statusInfo = m.top.findNode("statusInfo")
	m.performanceInfo = m.top.findNode("performanceInfo")
	m.fileInfo = m.top.findNode("fileInfo")
	m.paddingInfo = m.top.findNode("paddingInfo")
	m.renderedCode = m.top.findNode("renderedCode")
	m.prerenderedCode = m.top.findNode("prerenderedCode")

	m.overlayMarker = m.top.findNode("overlayMarker")
	m.overlayAnimation = m.top.findNode("overlayAnimation")

	initExamples()
	initAnimationNodes()

	updateStatus("")

	m.renderedCode.observeFieldScoped("status", "onStatusChange", ["performanceInfo"])

	if m.examples.count() > 0
		setExample()
	end if

	m.top.setFocus(true)
end sub

sub initExamples()
	m.examples = []
	path = "pkg:/components/ExampleScene"
	for each fileName in listDir(path)
		if fileName.endsWith(".svg")
			m.examples.push(path + "/" + fileName)
		end if
	end for

	if m.examples.count() > 0
		m.currentExample = 0
	else
		m.currentExample = -1
		updateStatus("No example files found")
	end if
end sub

sub initAnimationNodes()
	m.animatedNodes = {}
	for each interpolator in m.overlayAnimation.getChildren(-1, 0)
		field = interpolator.fieldToInterp
		target = field.split(".")
		fieldNode = target[0]
		fieldName = target[1]
		m.animatedNodes[field] = {
			node: m.top.findNode(fieldNode),
			field: fieldName
		}
	end for
end sub

sub updateStatus(message as string, performanceInfo = {} as object)
	m.statusInfo.text = "Status: " + message

	padding = m.renderedCode.padding
	if padding = -1
		text = "* Padding: original"
	else
		text = "* Padding: forced to " + padding.toStr()
	end if
	m.paddingInfo.text = text

	text = ""
	if performanceInfo <> invalid
		keys = performanceInfo.keys()
		totalKey = keys.peek()
		if totalKey <> invalid
			total = performanceInfo[totalKey]
			text = total.toStr() + "ms"
		end if
	end if
	m.performanceInfo.text = text
end sub

function setExampleSVG(filePath as string) as boolean
	svgData = readAsciiFile(filePath)
	hasData = svgData <> invalid and svgData <> ""

	if not hasData
		updateStatus("Could not load test SVG data")
	end if

	m.prerenderedCode.uri = filePath.replace(".svg", ".png")
	m.renderedCode.svgData = svgData
	return hasData
end function

function setExample(direction = 0 as integer) as boolean
	exampleIndex = m.currentExample + direction
	filePath = m.examples[exampleIndex]

	if filePath = invalid
		return false
	end if

	numberOfExamples = m.examples.count()

	prefix = ""
	if exampleIndex = 0
		prefix = "↓  "
	else if exampleIndex + 1 < numberOfExamples
		prefix = "↑↓ "
	else
		prefix = "↑  "
	end if

	m.currentExample = exampleIndex
	m.fileInfo.text = prefix + filePath + " (#" + (exampleIndex + 1).toStr() + " of " + numberOfExamples.toStr() + ")"
	setExampleSVG(filePath)

	return true
end function

function resetExample() as boolean
	if m.renderedCode.uri = "" or m.renderedCode.status <> "ready"
		return false
	end if

	if not deleteFile(m.renderedCode.uri)
		return false
	end if

	return setExample()
end function

sub toggleOverlayMode()
	isActive = (m.isOverlayModeActive = true)
	m.isOverlayModeActive = not isActive

	m.overlayAnimation.control = "stop"

	for each interpolator in m.overlayAnimation.getChildren(-1, 0)
		interpolator.reverse = isActive
		values = interpolator.keyValue

		target = m.animatedNodes[interpolator.fieldToInterp]
		if not isActive and target.values = invalid
			target.values = values
		end if

		if isActive
			values[0] = target.values[0]
			values[1] = target.node[target.field]
		else
			values[0] = target.node[target.field]
			values[1] = target.values[1]
		end if

		interpolator.keyValue = values
	end for

	m.overlayAnimation.control = "start"
end sub

function togglePadding() as boolean
	padding = m.renderedCode.padding

	if padding = -1
		padding = 50
	else if padding = 50
		padding = 25
	else if padding = 25
		padding = 0
	else if padding = 0
		padding = -1
	end if

	m.renderedCode.padding = padding
	resetExample()
	return true
end function

function setOverlay(direction = 0 as integer) as boolean
	if m.currentOverlay = invalid
		m.currentOverlay = 0
	end if

	if direction = 0

	end if

end function

sub onStatusChange(event as object)
	updateStatus(event.getData(), event.getInfo()?.performanceInfo)
end sub

function onKeyEvent(key as string, pressed as boolean) as boolean
	if key = "up"
		return not pressed or setExample(-1)
	else if key = "down"
		return not pressed or setExample(1)
	else if key = "left" or key = "right"
		toggleOverlayMode()
		return true
	else if key = "replay"
		return not pressed or resetExample()
	else if key = "options"
		return not pressed and togglePadding()
	end if

	return false
end function
