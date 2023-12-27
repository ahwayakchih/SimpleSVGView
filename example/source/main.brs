sub main(_args as Dynamic)
	' Indicate this is a Roku SceneGraph application
	screen = createObject("roSGScreen")
	m.port = createObject("roMessagePort")
	screen.setMessagePort(m.port)

	' Create and load /components/scenes/ExampleScene.xml
	screen.createScene("ExampleScene")

	' Go!
	screen.show()

	while true
		msg = wait(0, m.port)
		msgType = type(msg)
		if msgType = "roSGScreenEvent"
			if msg.isScreenClosed() then return
		end if
	end while
end sub
