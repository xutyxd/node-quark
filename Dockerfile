ARG ALPINE_VERSION=3.22
FROM alpine:${ALPINE_VERSION} AS builder

RUN apk add --no-cache nodejs npm upx

# Create non-root node user files
RUN echo "node:x:1000:1000:node:/home/node:/sbin/nologin" > /tmp/passwd && \
    echo "node:x:1000:" > /tmp/group && \
    mkdir -p /tmp/home/node && \
    chown -R 1000:1000 /tmp/home/node

# Extract with better error handling
RUN --mount=type=cache,target=/var/cache/apk \
    echo "Building for ${ALPINE_VERSION}" && \
    set -ex && \
    mkdir -p /rootfs/bin /rootfs/lib /rootfs/usr/lib /rootfs/etc/ssl/certs /rootfs/home/user && \
    # Get library list and copy actual files (not symlinks)
    ldd /usr/bin/node | grep -o '/[^ ]*' | sort -u > /tmp/libs.txt && \
    cat /tmp/libs.txt && \
    while IFS= read -r lib; do \
        if [ -e "$lib" ]; then \
            mkdir -p "/rootfs$(dirname "$lib")" && \
            cp -L "$lib" "/rootfs$lib"; \
        fi \
    done < /tmp/libs.txt && \
    # Compress with UPX
    upx --best --lzma /usr/bin/node && \
    # Copy node binary
    cp /usr/bin/node /rootfs/bin/node && \
    # Ensure musl dynamic linker is present
    cp /lib/ld-musl-*.so.* /rootfs/lib/ && \
    # Certs and user files
    cp /etc/ssl/certs/ca-certificates.crt /rootfs/etc/ssl/certs/ && \
    cp /tmp/passwd /rootfs/etc/passwd && \
    cp /tmp/group /rootfs/etc/group

RUN ln -s /etc/ssl/certs/ca-certificates.crt /rootfs/etc/ssl/cert.pem

RUN ls -lah /rootfs/lib/
# ----------------
FROM scratch AS runner

COPY --from=builder /rootfs/ /

ENV PATH=/bin
USER node
WORKDIR /home/node

ENTRYPOINT ["/bin/node"]