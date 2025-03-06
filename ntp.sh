# Install NTP
sudo apt-get install ntp

# Setup static IP for the device
echo "Do you want to setup this device to have a static IP? (y/N)"
read setupIP
case $setupIP in
    yes|Y|y)
        echo "Please enter the IP that this device will be assigned in form of *.*.*.*/*:"
        read IP
        sudo echo "network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enp3s0:
      addresses:
        - $IP" > /etc/netplan/staticip.yaml
        sudo netplan apply
	;;
    *)
        echo "Not setting up device with a static IP."
	;;
esac

# Set up NTP on device
echo "Do you want to set up NTP to point to a server? (y/N)"
read NTP
case $NTP in
    yes|Y|y)
        echo "IP of server you want to sync with (in form *.*.*.*): "
	read IP
	rm /etc/ntp.conf
 	echo "tos maxclock 8
	pool $IP iburst" > /etc/ntp.conf
 	;;
    *)
    	echo "Not setting up NTP to point to a server"
 	;;
esac
