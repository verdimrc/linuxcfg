# Deprecated, see sysctl.txt.
sudo bash -c "echo 'vm.swappiness = 10' >> /etc/sysctl.conf"
sudo sysctl -p
