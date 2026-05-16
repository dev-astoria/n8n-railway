# ─── Stage 1: Alpine builder ────────────────────────────────────────────────
# Install Python 3, pip, build tools, Puppeteer system dependencies, and
# all required Python packages.
FROM alpine:3.19 AS builder

# System packages:
#   - python3 / py3-pip / build-base  → Python runtime + C-extension builds
#   - chromium                         → Chromium browser for Puppeteer
#   - ca-certificates                  → TLS root certs (needed by Chromium)
#   - nss                              → Network Security Services (Chromium dep)
#   - freetype / harfbuzz              → Font rendering (Chromium dep)
#   - ttf-freefont                     → Fallback fonts so pages render correctly
#   - udev / eudev-libs                → Device management (Chromium sandbox)
#   - libstdc++ / libgcc               → C++ runtime libs Chromium links against
RUN apk add --no-cache \
      python3 \
      py3-pip \
      build-base \
      chromium \
      ca-certificates \
      nss \
      freetype \
      harfbuzz \
      ttf-freefont \
      eudev-libs \
      libstdc++ \
      libgcc \
      font-noto-emoji

# Install Python packages useful for n8n Code nodes and HTTP/scraping workflows
RUN pip3 install --no-cache-dir --break-system-packages \
      beautifulsoup4 \
      requests \
      lxml \
      pandas \
      numpy \
      python-dateutil \
      pytz

# ─── Stage 2: n8n runtime ───────────────────────────────────────────────────
FROM n8nio/n8n:latest

USER root

# ── Python: copy everything from the Alpine builder ──────────────────────────

# Python executable (python3, python3.x)
COPY --from=builder /usr/bin/python3* /usr/bin/

# pip3 / pip and any other Python-related scripts
COPY --from=builder /usr/local/bin /usr/local/bin/

# pip-installed packages (beautifulsoup4, requests, etc.)
COPY --from=builder /usr/local/lib /usr/local/lib/

# Alpine system-level Python stdlib and distutils
COPY --from=builder /usr/lib/python3* /usr/lib/

# musl libc, libssl, libcrypto and other Alpine runtime libs Python links against
COPY --from=builder /lib /lib/

# ── Puppeteer system libraries: copy Chromium and its deps from builder ──────

# Chromium binary and supporting files
COPY --from=builder /usr/bin/chromium-browser  /usr/bin/chromium-browser
COPY --from=builder /usr/lib/chromium          /usr/lib/chromium/

# NSS (Network Security Services) — required by Chromium for TLS
COPY --from=builder /usr/lib/libssl3.so        /usr/lib/
COPY --from=builder /usr/lib/libnss3.so        /usr/lib/
COPY --from=builder /usr/lib/libnssutil3.so    /usr/lib/
COPY --from=builder /usr/lib/libsmime3.so      /usr/lib/
COPY --from=builder /usr/lib/libplc4.so        /usr/lib/
COPY --from=builder /usr/lib/libplds4.so       /usr/lib/
COPY --from=builder /usr/lib/libnspr4.so       /usr/lib/

# Freetype + Harfbuzz — font rendering
COPY --from=builder /usr/lib/libfreetype.so*   /usr/lib/
COPY --from=builder /usr/lib/libharfbuzz.so*   /usr/lib/

# C++ runtime
COPY --from=builder /usr/lib/libstdc++.so*     /usr/lib/
COPY --from=builder /usr/lib/libgcc_s.so*      /usr/lib/

# CA certificates so Chromium can validate HTTPS
COPY --from=builder /etc/ssl/certs             /etc/ssl/certs/

# Fonts
COPY --from=builder /usr/share/fonts           /usr/share/fonts/

# ── Install Puppeteer via npm (skips bundled Chromium — we use the system one) ──
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN npm install -g puppeteer --unsafe-perm=true 2>&1 | tail -5

# ── Environment variables ─────────────────────────────────────────────────────
ENV PATH="/usr/local/bin:${PATH}" \
    # Python: make sure the Alpine-copied libs are found
    LD_LIBRARY_PATH="/lib:/usr/lib:/usr/lib/chromium" \
    # Chromium flags required for running in a container (no sandbox, no GPU)
    CHROMIUM_FLAGS="--no-sandbox --disable-gpu --disable-dev-shm-usage" \
    # Suppress Puppeteer's own download logic everywhere
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# ── Smoke-test: verify Python and Puppeteer are reachable ────────────────────
RUN python3 --version && \
    python3 -c "import bs4, requests, lxml, pandas, numpy; print('Python packages OK')" && \
    node -e "require('puppeteer'); console.log('Puppeteer module OK')" && \
    /usr/bin/chromium-browser --version

# Drop back to the default n8n user
USER node
