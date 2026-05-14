# Stage 1: Alpine builder — install Python 3, pip, build tools, and BeautifulSoup4
FROM alpine:3.19 AS builder

RUN apk add --no-cache python3 py3-pip build-base

RUN pip3 install --no-cache-dir beautifulsoup4

# Stage 2: n8n runtime — copy Python and site-packages from the builder stage
FROM n8nio/n8n:latest

USER root

# Copy Python binaries (python3, pip3, etc.) from the Alpine builder
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy Python standard library and installed packages (e.g. beautifulsoup4)
COPY --from=builder /usr/local/lib /usr/local/lib

# Also copy the Alpine system-level Python libs so the interpreter resolves correctly
COPY --from=builder /usr/lib/python3* /usr/lib/

# Ensure python3 resolves on PATH
ENV PATH="/usr/local/bin:${PATH}"
