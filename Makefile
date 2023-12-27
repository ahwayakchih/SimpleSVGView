ENV?=dev

ROKU=
USER=rokudev
PASS=
TELNET=busybox telnet

-include ${ENV}.env

HOUR=$(shell date -u +'%Y-%m-%dT%H')
BUILDS=builds
ZIP=${BUILDS}/${ENV}-${HOUR}.zip

all: build deploy
test: example deploy

build: ${BUILDS}
	rm ${ZIP} || true
	zip -r -9 ${ZIP} components source manifest

example: build
	cd example && zip -r -9 ../${ZIP} components source manifest

deploy: build
	curl -s -S --digest --user ${USER}:${PASS} -F "mysubmit=replace" -F "archive=@${ZIP}" http://${ROKU}/plugin_install >/dev/null

delete:
	curl -s -S --digest --user ${USER}:${PASS} -F "mysubmit=Delete" -F "archive=" http://${ROKU}/plugin_install >/dev/null

console:
	${TELNET} ${ROKU} 8085

debug:
	${TELNET} ${ROKU} 8080

${BUILDS}:
	mkdir ${BUILDS}

screenshot:
	curl -s -S --digest --user ${USER}:${PASS} -F "mysubmit=Screenshot" -F "archive=" http://${ROKU}/plugin_inspect >/dev/null
	curl -s -S --digest --user ${USER}:${PASS} --output screenshot.png http://${ROKU}/pkgs/dev.png

clean: delete
	rm ${BUILDS}/*.zip || test -z `ls ${BUILDS}/*.zip`
