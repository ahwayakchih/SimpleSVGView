sub init()
	m.statusInfo = m.top.findNode("statusInfo")
	m.performanceInfo = m.top.findNode("performanceInfo")
	m.fileInfo = m.top.findNode("fileInfo")
	m.paddingInfo = m.top.findNode("paddingInfo")
	m.renderedLabel = m.top.findNode("renderedLabel")
	m.renderedBackground = m.top.findNode("renderedBackground")
	m.renderedCode = m.top.findNode("renderedCode")
	m.prerenderedCode = m.top.findNode("prerenderedCode")

	m.overlayMarker = m.top.findNode("overlayMarker")
	m.overlayAnimation = m.top.findNode("overlayAnimation")

	initExamples()
	initAnimationNodes()

	updateStatus("")

	m.isUsingLocalComponent = true
	m.localRenderedCode = m.renderedCode
	m.libRenderedCode = invalid

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

sub setLibComponent()
	m.renderedBackground.removeChild(m.renderedCode)
	m.libRenderedCode = createObject("roSGNode", "SimpleSVGView:SimpleSVGView")

	if m.libRenderedCode = invalid
		updateStatus("Failed to create SimpleSVGView:SimpleSVGView")
		setLocalComponent()
		return
	end if

	m.libRenderedCode.observeFieldScoped("status", "onStatusChange", ["performanceInfo"])
	m.libRenderedCode.setFields({
		id: m.renderedCode.id,
		width: m.renderedCode.width,
		height: m.renderedCode.height,
		padding: m.renderedCode.padding,
		blendColor: m.renderedCode.blendColor,
		translation: m.renderedCode.translation,
		svgData: m.renderedCode.svgData
	})	
	m.renderedCode = m.libRenderedCode

	m.renderedLabel.text = "rendered with SVGView from lib:"
	m.renderedBackground.appendChild(m.renderedCode)
end sub

sub setLocalComponent()
	m.renderedBackground.removeChild(m.renderedCode)
	m.renderedCode = m.localRenderedCode
	m.renderedBackground.appendChild(m.localRenderedCode)
	m.renderedLabel.text = "rendered with local SVGView:"
	resetExample()
end sub

sub updateStatus(message as string, performanceInfo = {} as object)
	print "Status: " + message
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

function toggleComponent() as boolean
	isLocal = (m.isUsingLocalComponent = true)
	m.isUsingLocalComponent = not isLocal

	if isLocal
		if m.componentLib = invalid or m.componentLib.loadStatus = "failed"
			appInfo = createObject("roAppInfo")
			version = appInfo.getVersion()
			m.componentLib = createObject("roSGNode", "ComponentLibrary")
			m.componentLib.observeFieldScoped("loadStatus", "onComponentLibraryStatusChange")
			m.componentLib.id = "LibSimpleSVGView"
			m.componentLib.uri = "https://github.com/ahwayakchih/SimpleSVGView/releases/download/v"+version+"/lib-SimpleSVGView-"+version+".zip"
		else if m.componentLib.loadStatus = "ready"
			setLibComponent()
		end if
	else
		setLocalComponent()
	end if
end function

sub onStatusChange(event as object)
	updateStatus("[SVG] " + event.getData(), event.getInfo()?.performanceInfo)
end sub

sub onComponentLibraryStatusChange(event as object)
	status = event.getData()
	updateStatus("[Lib] " + status)
	if status = "ready"
		setLibComponent()
	end if
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
	else if key = "OK"
		return not pressed and toggleComponent()
	end if

	return false
end function
