#!/bin/bash
#set -ex
# vi: et st=2 sts=2 ts=2 sw=2 cindent bg=dark

#Harbor on Ubuntu 22.04

# Unless ENV VAR 'IPorFQDN' is already set in CLI,
# prompt for the user to ask if the install should use the IP Address or Fully Qualified Domain Name of the Harbor Server

if [ -z "$IPorFQDN" ];then
	PS3='Would you like to install Harbor based on IP or FQDN? '
	select option in IP FQDN
	do
		case $option in
			IP)
				IPorFQDN=$(hostname -I|cut -d" " -f 2)
				break;;
			FQDN)
				IPorFQDN=$(hostname -f)
				break;;
		esac
	done
fi

# Housekeeping
sudo DEBIAN_FRONTEND=noninteractive apt-get update -yq
sudo swapoff --all
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
#ufw disable #Do Not Do This In Production
echo "Housekeeping done"

#Install Latest Stable Docker Release
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl gnupg2 gnupg-agent software-properties-common
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo DEBIAN_FRONTEND=noninteractive add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -yqq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli docker-compose-plugin
sudo tee /etc/docker/daemon.json >/dev/null <<EOF
{
	"exec-opts": ["native.cgroupdriver=systemd"],
	"insecure-registries" : ["$IPorFQDN:443","$IPorFQDN:80","0.0.0.0/0"],
	"log-driver": "json-file",
	"log-opts": {
		"max-size": "100m"
	},
	"storage-driver": "overlay2"
}
EOF

sudo groupadd -f docker
MAINUSER=$(logname)
sudo usermod -aG docker $MAINUSER
sudo systemctl daemon-reload
sudo systemctl restart docker
echo "Docker Installation done"

#Install Latest Stable Docker Compose Release
# curl -skL $(curl -s https://api.github.com/repos/docker/compose/releases/latest|grep browser_download_url|grep -i "$(uname -s)-$(uname -m)"|grep -v sha25|head -1|cut -d'"' -f4) -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
# ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose || true
# echo "Docker Compose Installation done"

#Install Latest Stable Harbor Release
wget -q $(curl -s https://api.github.com/repos/goharbor/harbor/releases/latest|grep browser_download_url|grep online|cut -d'"' -f4|grep '.tgz$'|head -1) -O harbor-online-installer.tgz
tar xvf harbor-online-installer.tgz

cd harbor
cp harbor.yml.tmpl harbor.yml
sed -i "s/reg.mydomain.com/$IPorFQDN/g" harbor.yml
sed -e '/port: 443$/ s/^#*/#/' -i harbor.yml
sed -e '/https:$/ s/^#*/#/' -i harbor.yml
sed -e '/\/your\/certificate\/path$/ s/^#*/#/' -i harbor.yml
sed -e '/\/your\/private\/key\/path$/ s/^#*/#/' -i harbor.yml

sudo mkdir -p /var/log/harbor
sudo ./install.sh
echo -e "Harbor Installation Complete \n\nPlease log out and log in or run the command 'newgrp docker' to use Docker without sudo\n\nLogin to your harbor instance:\n docker login -u admin -p Harbor12345 $IPorFQDN\n\n:::: ufw firewall was NOT disabled!\n"
