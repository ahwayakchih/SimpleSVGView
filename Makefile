ENV?=dev

ROKU=
USER=rokudev
PASS=
TELNET=busybox telnet

-include ${ENV}.env

HOUR=$(shell date -u +'%Y-%m-%dT%H')
ZIP?=${ENV}-${HOUR}.zip
BUILD_DIR?=builds

all: build deploy
test: build_example deploy

build: ${BUILD_DIR}
	rm "${BUILD_DIR}/${ZIP}" || true
	zip -r -9 "${BUILD_DIR}/${ZIP}" components source manifest

build_example: build
	mv "${BUILD_DIR}/${ZIP}" "example/${ZIP}"
	cd example && zip -r -9 "${ZIP}" components source manifest
	mv "example/${ZIP}" "${BUILD_DIR}/${ZIP}"

deploy:
	curl -s -S --digest --user ${USER}:${PASS} -F "mysubmit=replace" -F "archive=@${BUILD_DIR}/${ZIP}" http://${ROKU}/plugin_install >/dev/null

delete:
	curl -s -S --digest --user ${USER}:${PASS} -F "mysubmit=Delete" -F "archive=" http://${ROKU}/plugin_install >/dev/null

console:
	${TELNET} ${ROKU} 8085

debug:
	${TELNET} ${ROKU} 8080

${BUILD_DIR}:
	mkdir -p "${BUILD_DIR}"

screenshot:
	curl -s -S --digest --user ${USER}:${PASS} -F "mysubmit=Screenshot" -F "archive=" http://${ROKU}/plugin_inspect >/dev/null
	curl -s -S --digest --user ${USER}:${PASS} --output screenshot.png http://${ROKU}/pkgs/dev.png

clean: delete
	rm "${BUILD_DIR}"/*.zip || test -z `ls "${BUILD_DIR}"/*.zip`

.PHONY: test build build_example deploy delete console debug screenshot clean
