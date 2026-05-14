FROM n8nio/n8n:latest

USER root

RUN apk add --no-cache python3 py3-pip build-base

RUN pip3 install beautifulsoup4
