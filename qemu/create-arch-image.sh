# Install base dependencies
sudo pacman -S qemu-base arch-install-scripts

qemu-img create -f raw arch.img 10G

mkfs.ext4 -F arch.img

sudo losetup --find --show -P arch.img

sudo mkdir -p /mnt/archvm

sudo mount /dev/loop0 /mnt/archvm

sudo pacstrap -K /mnt/archvm base linux-firmware openssh sudo vim tmux git strace less iproute2 dhcpcd

sudo arch-chroot /mnt/archvm

#Inside the arch-chroot:
echo archvm > /etc/hostname
echo "127.0.0.1 localhost" > /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 archvm.localdomain archvm" >> /etc/hosts
systemctl enable sshd
systemctl enable dhcpcd
systemctl enable serial-getty@ttyS0.service
passwd -d root
mkdir -p /root/.ssh
chmod 700 /root/.ssh

#exit the arch-chroot
exit
#go back to home directory
cd
#Create ssh private and public key on host
ssh-keygen -t ed25519 -C "archvm" -f ~/.ssh/archvm_ed25519_linux_dev

#Copy public key over to client vm
cat .ssh/archvm_ed25519_linux_dev.pub | sudo tee /mnt/archvm/root/.ssh/authorized_keys
#Ensure correct permissions for VM
sudo chmod 700 /mnt/archvm/root/.ssh
sudo chmod 600 /mnt/archvm/root/.ssh/authorized_keys

#Kill gpg not allowing unmount
# sudo kill 98945
# sudo pkill -f gpg-agent
#Unmount image
sudo umount /mnt/archvm

losetup -j ~/linux/qemu/arch.img
sudo losetup -d /dev/loop0
