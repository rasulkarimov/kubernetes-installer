#!/bin/bash

# Directory where the archives are stored
ARCHIVE_DIR="./docker_archives"
REGISTRY="10.1.195.23:5000"

# If a command-line argument is provided, use it as the registry; otherwise, use the default
REGISTRY="${1:-$DEFAULT_REGISTRY}"

echo "Using registry: $REGISTRY"

# Load and push each archived image
for ARCHIVE in "${ARCHIVE_DIR}"/*.tar; do
    # Extract the image name and tag from the archive file name
    IMAGE_NAME_TAG=$(basename "${ARCHIVE}" .tar)
    
    # Reconstruct the original image tag from the archive name
    ORIG_IMAGE_TAG=$(echo "${IMAGE_NAME_TAG}" | tr '_' ':')
    
    # Load the image from the tar archive
    podman load -i "${ARCHIVE}"
    
    # Tag the image for the new registry
    podman tag "${ORIG_IMAGE_TAG}" "${REGISTRY}/${ORIG_IMAGE_TAG}"
    
    # Push the image to the new registry
    podman push "${REGISTRY}/${ORIG_IMAGE_TAG}"
    
    # Output the result
    echo "Loaded and pushed ${ARCHIVE} to ${REGISTRY}/${ORIG_IMAGE_TAG}"
done

