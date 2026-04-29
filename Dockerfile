FROM python:3.11-alpine

# Use the specific version for ARM64 (STB architecture)
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.29/supercronic-linux-arm64

# Install bash and curl (Alpine needs these specifically)
RUN apk add --no-cache curl bash ca-certificates \
    && pip install --no-cache-dir instaloader \
    && curl -fsSL "$SUPERCRONIC_URL" -o /usr/local/bin/supercronic \
    && chmod +x /usr/local/bin/supercronic

WORKDIR /app

# Copy and fix permissions
COPY insta_download.sh .
RUN chmod +x /app/insta_download.sh

# IMPORTANT: Define the PATH and SHELL inside the crontab file
# This prevents the "no such file or directory" fork error
RUN echo "SHELL=/bin/bash" > crontab \
    && echo "PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/sbin:/bin" >> crontab \
    && echo "0 2 * * * /app/insta_download.sh" >> crontab

# Run supercronic
CMD ["supercronic", "/app/crontab"]
