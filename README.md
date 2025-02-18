# Ceph Installer

## Overview

This repository provides a streamlined approach to deploying a Ceph cluster using Ansible. It supports on-premises servers and, in the "Quick Start" section, provides an example with CentOS 9 operating system (Rocky Linux 9).

Architecture example:

![alt text](image.png)

## Quick Start

### Installing a Ceph Cluster in a Private Datacenter

For installing a Ceph cluster without internet access, you need to configure a private repository. Follow these steps:

1. **Configure Private Repository**:  
   Place `local-ceph-dependencies_v19.2.0.tar.gz` in the root directory of the admin node. During validation and installation, Ansible will copy this file to the `/var/<repo>` directory and configure this directory as a repository.

   - **Note**: If this file is not provided, the repository configuration task will be skipped.

2. **Future Package Collection**:  
   At the end of this document, guidance is provided for collecting packages for future Ceph versions.

### Prepare Images for Private Docker Registry

The recent version of Ceph is recommended to be installed using the `cephadm` tool, which orchestrates Ceph services, running and managing their deployment in containers. In data centers without internet access, you need to:

1. **Download Images**:
   - Images must be downloaded to the `docker_registry` server.
   - Ansible will configure the private Docker registry and push all uploaded images into it, so Ceph can fetch them within the private network. 

2. **Use `00_download_artefact.sh`**:
   - Review the `00_download_artefact.sh` file for images and execute it on a machine with internet access. It will download images and archive them for installation procedures.

   ```bash
   ./00_download.sh
   Trying to pull quay.io/ceph/ceph:v19.2.0...
   Getting image source signatures
   ```


### Configure Ansible User with Sudo Access

To remotely manage nodes, the Ansible user must be able to log into all the Red Hat Ceph Storage nodes with root privileges to install software and create configuration files without prompting for a password.

**Ensure pre-requisites:**

- Ensure both `git` and `ansible` are installed on the servers, as the remaining configurations are managed through Ansible scripts.

### Repository Setup

1. **Clone the Repository**:
   - Use Git to clone the required repository.

   ```bash
   git clone https://github.com/rasulkarimov/ceph-installer.git
   ```

2. **Initialize and Apply Terraform**:

Initialize and Apply Terraform:

Prepare your infrastructure using Terraform.
~~~
terraform init
terraform plan
terraform apply
~~~

3. **Review Ansible Configuration (ansible.cfg)**:

Ensure the Ansible configuration is set up with the appropriate credentials.
~~~
[defaults]
remote_user = root
inventory = ./inventory
private_key_file = ~/.ssh/id_rsa
~~~

**Configure Private Repository with RPM Packages**
Use Ansible playbooks to configure your private repository with RPM packages.
~~~
ansible-playbook setup-repo.yml
~~~

Validate Servers and Install Required Packages
Run an Ansible playbook to validate the servers and ensure all necessary packages are installed.
~~~
ansible-playbook validate-and-install.yml
~~~

Install Private Registry
Steps to configure the private registry and bootstrap the first Ceph cluster:

Review Inventory File:

Check the inventory file to ensure it lists all relevant nodes.
~~~
cat ../ansible/inventory
~~~

Inventory Example

Bootstrap the Cluster:
~~~
~~~

Start setting up the cluster with Ceph.
~~~
ceph -s
~~~
Add Nodes to the Cluster:

Use Ansible playbooks to add additional nodes to your cluster.
~~~
ansible-playbook site.yml
~~~

Configure HAProxy for Ceph Dashboard Exposure:
Ensure that HAProxy is configured to expose the Ceph Dashboard.
~~~
ansible-playbook configure-haproxy.yml
~~~

Upon completion, a link to the Ceph Dashboard URL will be provided.

Useful Commands
Manage Ceph cluster hosts and labels, deploy daemons, and monitor OSDs using the following commands:

Add Host Labels:
~~~
ceph orch host label add HOSTNAME LABEL
~~~
List Hosts and Labels:
~~~
ceph orch host ls
~~~
Deploy Daemons Using Labels:
~~~
ceph orch apply mon label:mon
~~~
Or specify host placement:
~~~
ceph orch apply mon --placement="3 host01 host02 host03"
~~~
List Storage Devices:
~~~
ceph orch device ls
~~~
Create New OSDs:
~~~
ceph orch daemon add osd <host>:<device-path>
~~~
Or deploy on all available devices:
~~~
ceph orch apply osd --all-available-devices
~~~
Monitor OSD:
~~~
ceph orch osd rm status
~~~
Clean Devices:
~~~
ceph orch device zap <host> /dev/vdb --force
~~~

TODO
Add instructions to create an RPM repository, providing guidance on repository setup and management for Ceph.