#!/usr/bin/env bash

cd
echo "" | sudo crontab -
sudo sed -i "s|:/home/$USER/.local/bin:$COPYRUS/bin||g" /etc/environment
sudo sed -i '/COPYRUS/d' /etc/environment
sudo sed -i '/IPFS_PATH/d' /etc/environment
sudo systemctl stop ipfssub; sudo systemctl disable ipfssub
sudo systemctl stop ipfs; sudo systemctl disable ipfs
sudo rm /etc/systemd/system/ipfs.service
sudo rm /etc/systemd/system/ipfssub.service
rm -rf $COPYRUS
sudo rm -rf /ipfs; sudo rm -rf /ipns
sudo reboot
