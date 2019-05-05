#!/bin/sh
printf "Leave passphrase empty!\n"
ssh-keygen -t rsa -b 4096 -C "domjudge"
read -p "Please set user of all hosts [root]: " user
user=${user:-root}
for host in $(sed -n 's/.*ansible_host=\(.\+\)/\1/p' inventory | sort -u); do
    ssh-copy-id -i ~/.ssh/id_rsa.pub $user@$host
    if [[ $user != root ]]; then
        ssh -t $user@$host "sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config && sudo mkdir -p /root/.ssh -m 700 -Z && sudo cp ~/.ssh/authorized_keys /root/.ssh/authorized_keys && sudo restorecon -R /root/.ssh && sudo systemctl restart sshd"
    else
        ssh $user@$host "sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config && systemctl restart sshd"
    fi
done
