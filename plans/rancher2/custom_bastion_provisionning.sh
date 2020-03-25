# Parce que je sais que je détruis le bastion à la fin
# Ne pas faire ça si le bastion reste après usage
# Ne jamais partager un bastion avec ça
scp -o StrictHostKeyChecking=no -F ssh_config -r ~/.aws rancher2-bastion:~
scp -o StrictHostKeyChecking=no -F ssh_config -r ./elasticsearch rancher2-bastion:~
scp -o StrictHostKeyChecking=no -F ssh_config -r ./traefik rancher2-bastion:~
ssh -o StrictHostKeyChecking=no -F ssh_config rancher2-bastion 'echo "export AWS_PROFILE=clevandowski-ops-zenika" >> .bashrc'
ssh -o StrictHostKeyChecking=no -F ssh_config rancher2-bastion 'echo "export AWS_REGION=eu-north-1" >> .bashrc'
ssh -o StrictHostKeyChecking=no -F ssh_config rancher2-bastion 'sudo yum install git -y'
kubectl -n cattle-system exec $(kubectl -n cattle-system get pods -l app=rancher | grep '1/1' | head -1 | awk '{ print $1 }') -- reset-password | tail -n 1 > rancher_admin_password.txt

# kubectl -n cattle-system exec $(kubectl -n cattle-system get pods -l app=rancher | grep '1/1' | head -1 | awk '{ print $1 }') -- reset-password | tail -n 1 > rancher_admin_password.txt
# ssh -F ssh_config rancher2-bastion kubectl -n cattle-system exec \$(kubectl -n cattle-system get pods -l app=rancher | grep "1/1" | head -1 | awk "{ print \$1 }") -- reset-password | tail -n 1 > rancher_admin_password.txt
# ssh -F ssh_config rancher2-bastion