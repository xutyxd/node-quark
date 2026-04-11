FROM alpine:edge AS builder
# Download and install Node.js and UPX for compression
RUN apk add --no-cache nodejs npm upx

# Compress the Node binary and major libraries
RUN upx --best --lzma /usr/bin/node

# Create non-root user
RUN echo "user:x:1000:1000:user:/home/user:/sbin/nologin" > /tmp/passwd && \
    echo "user:x:1000:" > /tmp/group

# ----------------
FROM scratch AS runner

# Copy essential libraries (musl + libstdc++ + ssl)
# docker run --rm alpine:edge sh -c "apk add --no-cache nodejs && ldd /usr/bin/node"
# Musl libc (dynamic linker + libc)
COPY --from=builder /lib/ld-musl-*.so.* /lib/
COPY --from=builder /lib/libc.musl-*.so.* /lib/

# Compression libraries
COPY --from=builder /usr/lib/libz.so.* /usr/lib/
COPY --from=builder /usr/lib/libzstd.so.* /usr/lib/

# URL parsing (Ada)
COPY --from=builder /usr/lib/libada.so.* /usr/lib/

# JSON/UTF parsing (optimized)
COPY --from=builder /usr/lib/libsimdjson.so.* /usr/lib/
COPY --from=builder /usr/lib/libsimdutf.so.* /usr/lib/

# Brotli compression
COPY --from=builder /usr/lib/libbrotlidec.so.* /usr/lib/
COPY --from=builder /usr/lib/libbrotlienc.so.* /usr/lib/
COPY --from=builder /usr/lib/libbrotlicommon.so.* /usr/lib/

# DNS resolution
COPY --from=builder /usr/lib/libcares.so.* /usr/lib/

# HTTP/2
COPY --from=builder /usr/lib/libnghttp2.so.* /usr/lib/

# SQLite (Node.js uses it for some internals)
COPY --from=builder /usr/lib/libsqlite3.so.* /usr/lib/

# SSL/TLS
COPY --from=builder /usr/lib/libcrypto.so.* /usr/lib/
COPY --from=builder /usr/lib/libssl.so.* /usr/lib/

# ICU (Internationalization - required for Intl API)
COPY --from=builder /usr/lib/libicui18n.so.* /usr/lib/
COPY --from=builder /usr/lib/libicuuc.so.* /usr/lib/
COPY --from=builder /usr/lib/libicudata.so.* /usr/lib/

# GCC runtime
COPY --from=builder /usr/lib/libstdc++.so.* /usr/lib/
COPY --from=builder /usr/lib/libgcc_s.so.* /usr/lib/

# Node.js binary
COPY --from=builder /usr/bin/node /usr/bin/node

# CA certificates (for HTTPS)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# User setup
COPY --from=builder /tmp/passwd /etc/passwd
COPY --from=builder /tmp/group /etc/group

USER user