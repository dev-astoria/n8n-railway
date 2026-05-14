# Stage 1: Alpine builder — install Python 3, pip, build tools, and BeautifulSoup4
FROM alpine:3.19 AS builder

RUN apk add --no-cache python3 py3-pip build-base

RUN pip3 install --no-cache-dir --break-system-packages beautifulsoup4

# Stage 2: n8n runtime — copy Python and site-packages from the builder stage
FROM n8nio/n8n:latest

USER root

# Copy Python binary from /usr/bin (Alpine places the python3 executable here)
COPY --from=builder /usr/bin/python3* /usr/bin/

# Copy pip3 and other Python-related scripts installed into /usr/local/bin
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy Python standard library and installed packages (e.g. beautifulsoup4)
COPY --from=builder /usr/local/lib /usr/local/lib

# Copy Alpine system-level Python libs (stdlib, distutils, etc.)
COPY --from=builder /usr/lib/python3* /usr/lib/

# Copy Alpine's /lib directory (musl libc, libssl, libcrypto, etc. that Python links against)
COPY --from=builder /lib /lib

# Ensure /usr/local/bin is on PATH and LD_LIBRARY_PATH points to the copied Alpine libs
ENV PATH="/usr/local/bin:${PATH}" \
    LD_LIBRARY_PATH="/lib:/usr/lib"
