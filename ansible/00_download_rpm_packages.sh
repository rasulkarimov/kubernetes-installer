#!/bin/bash

CEPH_VERSION="19.2.0"
DISTRO="el9"

#Configure ceph repo
curl --silent --remote-name --location https://download.ceph.com/rpm-$CEPH_VERSION/$DISTRO/noarch/cephadm
chmod +x cephadm
./cephadm add-repo --version $CEPH_VERSION

# Packages list you want to download
PACKAGES=(
    "lvm2"
    "podman"
    "openssh"
    "git"
    "cephadm"
    "ceph"
    "httpd"
    "yum-utils"
    "ansible"
    "chrony"
    "ceph-common"
    "ansible" 
)

# Directory to store downloaded RPM packages
DOWNLOAD_DIR="local-repo"

# Ensure yum-utilsand are installed
if ! rpm -qa | grep -qw yum-utils; then
    echo "Installing yum-utils..."
    sudo yum install -y yum-utils createrepo
fi

# Ensure createrepo installed
if ! rpm -qa | grep -qw createrepo; then
    echo "Installing createrepo..."
    sudo yum install -y createrepo
fi

# Create download directory
mkdir -p $DOWNLOAD_DIR


# Download specified packages with dependencies
for package in "${PACKAGES[@]}"; do
    echo "Downloading $package..."
    yumdownloader --resolve --alldeps --destdir=$DOWNLOAD_DIR $package
done

# Create YUM metadata for the repository
echo "Running createrepo..."
createrepo $DOWNLOAD_DIR

# Create a tarball of the downloaded RPMs
tar -czvf $DOWNLOAD_DIR.tar.gz -C $DOWNLOAD_DIR .

# Clean up
rm -rf $DOWNLOAD_DIR

echo "All packages are downloaded and compressed into $DOWNLOAD_DIR.tar.gz"
