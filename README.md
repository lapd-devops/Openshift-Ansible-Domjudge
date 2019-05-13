# Openshift-Ansible-Domjudge

Setup [Domjudge](https://github.com/DOMjudge/domjudge-packaging) with Openshift(Origin) Ansible 3.11

## Hardware Configuration

Having at least 5 hosts: 1 openshift master node, 1 openshift infra node with DNS, and 3 or more openshift compute nodes for judges. Use 1 of the computers listed above or any other computer that is connected to all hosts as the main system. The main system will be controlling all the hosts and setup their environment.

## Prerequisites

1. Fedora/Centos/RHEL(Any Red Hat based distro with SELinux Enabled)
2. All hosts meet [the requirements of Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
3. [Ansible](https://www.ansible.com/) installed on your main system
4. SSH server enabled and accepting interactive challenge on all openshift hosts
5. All hosts connected via internet
6. All hosts have an user with the same username
7. `git clone git@github.com:Superdanby/Openshift-Ansible-Domjudge.git`
8. `git clone https://github.com/openshift/openshift-ansible`

## Configuration

### DNS

Set DNS record for hosts in `Openshift-Ansible-Domjudge/tasks/files/hosts_domjudge`.

### Ansible

1. In `Openshift-Ansible-Domjudge/inventory`:
    1. Set the user in the line: `ansible_user='[username]'`
    2. Set host mappings in `Openshift-Ansible-Domjudge/inventory`. Make sure the mappings are consistent with those of `Openshift-Ansible-Domjudge/tasks/files/hosts_domjudge`
    3. Make sure `ansible_python_interpreter='[path to python3]'` is present under `[all:vars]` if your distro uses `python3` instead of `python2`
2. Create an ansible vault with `ansible-vault create [path to vault file]` and write `pass: [password for the user on all hosts]`

### Openshift

1. In `Openshift-Ansible-Domjudge/openshift_install_config/hosts.domjudge`:
    1. Set host mappings in `Openshift-Ansible-Domjudge/inventory`. Make sure the mappings are consistent with those of `Openshift-Ansible-Domjudge/inventory`
    2. Change the line: `openshift_pkg_version=-[3.11.1]` to match the version number of the Openshift packages provided by your distro
        - On Fedora, you can check the version with `dnf info origin`
    3. If your hosts don't meet [the minimum hardware requirements of Openshift](https://docs.okd.io/3.11/install/prerequisites.html#hardware), disable the corresponding checks in the end of the file with [these options](https://docs.okd.io/3.11/install/configuring_inventory_file.html#configuring-cluster-pre-install-checks)
2. Go to `openshift-ansible`
3. `git checkout release-3.11`
4. Copy `Openshift-Ansible-Domjudge/openshift_install_config/hosts.domjudge` and place it in `openshift-ansible/inventory`

### Domjudge Configs for Openshift

- `deploy_config`:
    - `domserver`: set `nodeName` to the FQDN of 1 of the compute nodes, set the mariadb credentials
    - `mariadb`: set `nodeName` to the FQDN of 1 of the compute nodes, set the mariadb credentials, set persistent volume
    - `judge-with-init`: set `JUDGEDAEMON_PASSWORD`, set `memory`
    - `judge-with-init-core-unbound`: set `JUDGEDAEMON_PASSWORD`, set `memory`
- `services`:
    - **set `externalIPs` to access your domjudge server**.

## Installation

### Enable Ansible Access to All Hosts

1. Go to `Openshift-Ansible-Domjudge`
2. Execute `send-ssh-keys.sh` with `./send-ssh-keys.sh`

### Environment Setup with Ansible

1. Go to `Openshift-Ansible-Domjudge`
2. Ensure machine ID is different on all hosts: `ansible-playbook -i inventory --ask-vault-pass --extra-vars '@[path to vault file]' tasks/01.change_mahcine_id.yml`
3. Setup DNS: `ansible-playbook -i inventory --ask-vault-pass --extra-vars '@[path to vault file]' tasks/02.setup_dns.yml`
4. Set DNS IP for all hosts: `ansible-playbook -i inventory --ask-vault-pass --extra-vars '@[path to vault file]' tasks/03.set_dns_lookup.yml`
5. Set hostname for all hosts according to DNS records: `ansible-playbook -i inventory --ask-vault-pass --extra-vars '@[path to vault file]' tasks/04.set_hostname.yml`
6. Upgrade all hosts: `ansible-playbook -i inventory --ask-vault-pass --extra-vars '@[path to vault file]' tasks/05.upgrade_all_packages.yml`
7. Enable dnsmasq on master to prevent System Resolv occupying port 53: `ansible-playbook -i inventory --ask-vault-pass --extra-vars '@[path to vault file]' tasks/06.enable_dnsmasq.yml`
8. Reboot all hosts: `ansible-playbook -i inventory --ask-vault-pass --extra-vars '@[path to vault file]' tasks/07.reboot.yml`
    - **If the main system is one of the cluster hosts, remember to exclude it from 07.reboot.yml and reboot it manually after the others finished their reboots.**
    - Rebooting all hosts ensures `journactl` works normally after a machine id change.
9. Stop `dnsmasq` on master node: `ansible-playbook -i inventory --ask-vault-pass --extra-vars '@[path to vault file]' tasks/08.stop_dns.yml`
    - **Step 7 ~ 9 is intended to prevent System Resolv occupying port 53 on master node.**

### Install Openshift

1. Go to `openshift-ansible`
2. Execute `ansible-playbook -i inventory/hosts.domjudge playbooks/prerequisites.yml`
3. Execute `ansible-playbook -i inventory/hosts.domjudge playbooks/deploy_cluster.yml`

## Configuring and Using Openshift

On openshift master node:

1. Create a user: `sudo htpasswd /etc/origin/master/htpasswd [username]`
2. Give the user super powers: `sudo oc adm policy add-cluster-role-to-user cluster-admin [username] --rolebinding-name=cluster-admins`
3. Login to master node web console from `[master FQDN/IP]:8443`
4. Select `Cluster Console` on the upper left screen and login with the same credentials
5. In `Administration > Projects`, create a new project with `domjudge` as its name
6. Under the `domjudge` project:
    1. In `Administration > Service Account`, create a new service account and modify the name line to `name: privrun`
    2. Back in terminal, give `privrun` super powers: `sudo oc adm policy add-scc-to-user privileged -z privrun -n domjudge`
    3. In `Builds > Image Streams`, create Image Streams with the files of `Openshift-Ansible-Domjudge/openshift_domjudge_config/image_stream`
    4. In `Builds > Build Configs`, create Build Configs with the files of `Openshift-Ansible-Domjudge/openshift_domjudge_config/build_config`
    5. In `Workloads > Deployment Configs`, create Deployment Configs with the files in `openshift_domjudge_config/deploy_config`
    6. In `Networking > Services`, create Services with the files in `Openshift-Ansible-Domjudge/openshift_domjudge_config/services`
7. Select `Application Console` on the upper left screen, and selecr `domjudge` project
8. Adjust the pods to suit your needs by selecting the pod entries and click the up and down arrow on the right hand side

## Domjudge Setup

1. Login from the external IP(s) set in `Openshift-Ansible-Domjudge/openshift_domjudge_config/services/domserver.yaml` to setup judgehost password

2. Well done! All components should be running now.

## Add Nodes and Masters

### Configuration

1. All hosts meet the [prerequisites](#prerequisites).
2. Add DNS record for new hosts in `Openshift-Ansible-Domjudge/tasks/files/hosts_domjudge`.
    ![DNS](https://i.imgur.com/8Kj3rFe.png)
3. Add hosts ansible setup in `Openshift-Ansible-Domjudge/inventory`.
    ![Ansible inventory file](https://i.imgur.com/gTUyO7m.png)
4. [Add host mappings](https://docs.okd.io/latest/admin_guide/manage_nodes.html#adding-cluster-hosts_manage-nodes) to Openshift configuration file in `Openshift-Ansible-Domjudge/openshift_install_config/hosts.domjudge`
    ![Openshift configuration file](https://i.imgur.com/B4b3Wtq.png)
5. Replace `openshift-ansible/inventory/hosts.domjudge` with `Openshift-Ansible-Domjudge/openshift_install_config/hosts.domjudge`.

### Scale Up

1. Go to `Openshift-Ansible-Domjudge`
2. Run `ansible-playbook -i inventory --ask-vault-pass --extra-vars '@[path to vault file]' tasks/add_nodes.yml`
3. Run `ansible-playbook -i inventory --ask-vault-pass --extra-vars '@[path to vault file]' tasks/add_masters.yml`
4. Go to `openshift-ansible`
5. `ansible-playbook -i inventory/hosts.domjudge playbooks/openshift-node/scaleup.yml`
6. `ansible-playbook -i inventory/hosts.domjudge playbooks/openshift-master/scaleup.yml`

## Todo

1. Merge all openshift_domjudge_config files into [1 template](https://github.com/openshift/origin/tree/master/examples/storage-examples/local-examples)
2. Better documentation for DEBUGGING
