#!/bin/sh

cd "$(dirname $0)"

set -ex

SERVER="echo \$'#!/bin/sh\ntimeout 1 cat - >/dev/null; echo -e \\\"HTTP/1.1 200 OK\n\nup\\\"' > /tmp/healthy && chmod +x /tmp/healthy && timeout 9 nc -l -p 8080 -e /tmp/healthy"
PODMAN_PORTMAPPING_TEST='podman run -p 8081:8080 --rm alpine:3.12 /bin/sh -c "'"$SERVER"'" & sleep 5; wget -O - localhost:8081'

echo TEST PODMAN AS ROOT '(using CNI)'
docker run --rm --privileged --entrypoint /bin/sh \
	-v "`pwd`/storage/root":/var/lib/containers/storage \
	"${IMAGE}" \
	-c 'podman run --rm alpine:3.12 wget -O /dev/null http://example.org'
echo TEST PODMAN AS ROOT - PORT MAPPING
docker run --rm --privileged --entrypoint /bin/sh \
	-v "`pwd`/storage/root":/var/lib/containers/storage \
	"${IMAGE}" \
	-c "$PODMAN_PORTMAPPING_TEST"
echo TEST PODMAN AS UNPRIVILEGED USER - NETWORK '(using slirp4netns)'
docker run -ti --rm --privileged \
	-v "`pwd`/storage/user":/podman/.local/share/containers/storage \
	"${IMAGE}" \
	docker run --rm alpine:3.12 wget -O /dev/null http://example.org
echo TEST PODMAN AS UNPRIVILEGED USER - PORT MAPPING
docker run -ti --rm --privileged \
	-v "`pwd`/storage/user":/podman/.local/share/containers/storage \
	"${IMAGE}" \
	/bin/sh -c "$PODMAN_PORTMAPPING_TEST"
echo TEST PODMAN AS UNPRIVILEGED USER - UID MAPPING '(using fuse-overlayfs)'
docker run -ti --rm --privileged \
	-v "`pwd`/storage/user":/podman/.local/share/containers/storage \
	"${IMAGE}" \
	docker run --rm alpine:3.12 /bin/sh -c 'set -ex; touch /file; chown guest /file; [ $(stat -c %U /file) = guest ]'
echo TEST PODMAN AS UNPRIVILEGED USER WITH NON-DEFAULT UID '(no uid/gid mapping)'
docker run -ti --rm --privileged --user 9000:9000 \
	"${IMAGE}" \
	docker run --rm alpine:3.12 wget -O /dev/null http://example.org
echo TEST PODMAN BUILD DOCKERFILE AS UNPRIVILEGED USER
docker run -ti --rm --privileged -u 100000:100000 --entrypoint /bin/sh \
	-v "`pwd`/storage/user":/podman/.local/share/containers/storage \
	"${IMAGE}" \
	-c 'set -e;
		podman build -t podmantestimage -f - . <<-EOF
			FROM alpine:3.12
			RUN echo hello world > /hello
			CMD ["/bin/cat", "/hello"]
		EOF'
