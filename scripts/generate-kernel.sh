# inside linux_stable
make -j$(nproc)
sudo make modules_install
sudo make install
sudo cp arch/x86/boot/bzImage /boot/vmlinuz-linux-dev
sudo mkinitcpio -k $(make kernelrelease) -g /boot/initramfs-linux-dev.img
echo "0000:bf:00.0" | sudo tee /sys/bus/pci/drivers/vfio-pci/unbind #unbind the windows nvme from vfio, so grub doesn't remove it
echo "0000:bf:00.0" | sudo tee /sys/bus/pci/drivers/nvme/bind # bind it to nvme
lspci -nnk -s bf:00.0
sudo grub-mkconfig -o /boot/grub/grub.cfg #regenerate grub
echo "0000:bf:00.0" | sudo tee /sys/bus/pci/drivers/nvme/unbind #unbind from nvme driver
echo "0000:bf:00.0" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind #remind to vfio-pci driver
