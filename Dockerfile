# Dockerfile for the Debian-Harper worker
# This image provides a basic Debian environment for building.

# Use a recent Debian base image
FROM debian:stable-slim

# Set the working directory inside the container
# This is where the mounted volume will typically be accessed.
WORKDIR /build

# Install any necessary build tools or dependencies here.
# For example, if you need 'make', 'gcc', 'git', etc.:
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     build-essential \
#     git \
#     && rm -rf /var/lib/apt/lists/*