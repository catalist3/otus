mkdir -p ~root/.ssh
cp ~vagrant/.ssh/auth* ~root/.ssh
yum install -y mdadm

mdadm --create /dev/md0 --level=5 --raid-devices=4 /dev/sd{b,c,d,e}
mdadm --detail --scan > /etc/mdadm.conf

parted -s /dev/md0 mklabel gpt
parted -s /dev/md0 mkpart 1 ext4 0% 20%
parted -s /dev/md0 mkpart 2 ext4 20% 40%
parted -s /dev/md0 mkpart 3 ext4 40% 60%
parted -s /dev/md0 mkpart 4 ext4 60% 80%
parted -s /dev/md0 mkpart 5 ext4 80% 100%

for i in $(seq 1 5);
do
      sudo mkfs.ext4 /dev/md0p$i 
done
sudo mkdir -p /raid/part{1,2,3,4,5}

for i in $(seq 1 5);
do
      sudo mount /dev/md0p$i /raid/part$i
done



