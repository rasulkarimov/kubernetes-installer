#!/bin/bash

CEPH_VERSION="19.2.0"

# Directory to store the archives
ARCHIVE_DIR="./docker_archives"

# Create a directory for the archives if it doesn't exist
mkdir -p "${ARCHIVE_DIR}"

# List of images to download
IMAGES=(
    "quay.io/ceph/ceph:v$CEPH_VERSION"
    "quay.io/podman/hello:latest"
    "quay.io/prometheus/prometheus:v2.51.0"
    "quay.io/ceph/grafana:10.4.0"
    "quay.io/prometheus/node-exporter:v1.7.0"
    "docker.io/library/registry:2"
    "quay.io/prometheus/alertmanager:v0.25.0"
    "docker.io/library/registry:2.8.3"
)

# Archive each image
for IMAGE in "${IMAGES[@]}"; do
    # Extract the image name and tag
    IMAGE_NAME_TAG=$(echo "${IMAGE##*/}" | tr ':' '_')
    
    # Save the image to a tar archive
    podman pull "${IMAGE}"
    podman save -o "${ARCHIVE_DIR}/${IMAGE_NAME_TAG}.tar" "${IMAGE}"
    
    # Output the result
    echo "Archived ${IMAGE} to ${ARCHIVE_DIR}/${IMAGE_NAME_TAG}.tar"
done

