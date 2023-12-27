sub init()
	m.renderedImage = m.top.findNode("renderedImage")

	m.currentTask = invalid

	m.top.observeFieldScoped("svgData", "onSVGDataChange", ["width", "height", "padding", "blendColor"])
end sub

sub onSVGDataChange(event as object)
	info = event.getInfo()
	svgData = event.getData()

	if m.currentTask <> invalid
		m.currentTask.control = "stop"
	else
		m.currentTask = createObject("roSGNode", "SimpleSVGTask")
		m.currentTask.observeFieldScoped("status", "onSimpleSVGTaskStatusChange", ["renderedImagePath", "performanceInfo"])
	end if

	m.renderedImage.unobserveFieldScoped("loadStatus")
	m.renderedImage.uri = ""
	m.renderedImage.observeFieldScoped("loadStatus", "onPosterLoadStatusChange")

	m.currentTask.width = info.width
	m.currentTask.height = info.height
	m.currentTask.padding = info.padding
	if info.blendColor <> -1
		m.currentTask.color = "#FFFFFFFF"
	else
		m.currentTask.color = "#00000000"
	end if
	m.currentTask.svgData = svgData

	if info.padding >= 0
		m.currentTask.functionName = "svgToQRBitsToPNG"
	else
		m.currentTask.functionName = "svgToPNG"
	end if

	m.top.performanceInfo = {}
	m.currentTask.control = "run"
end sub

sub onSimpleSVGTaskStatusChange(event as object)
	status = event.getData()

	if status = "ready"
		info = event.getInfo()
		m.renderedImage.uri = info.renderedImagePath
		m.top.performanceInfo = info.performanceInfo
		return
	else if status = "failed"
		info = event.getInfo()
		m.top.performanceInfo = info.performanceInfo
	end if

	m.top.status = status
end sub

sub onPosterLoadStatusChange(event as object)
	m.top.status = event.getData()
end sub
