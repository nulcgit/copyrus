#!/usr/bin/env bash

cd "$(dirname "$0")"
mkdir -p temp apps data/share/log
(echo -e "$(date -u) Copyrus installation started.") >> $PWD/data/log.txt
sudo apt update
read -p "Enter IPFS port(default 4003): " IPFSPORT
if [ -z "$IPFSPORT" ]; then
    IPFSPORT=4003
fi

arch=$(uname -m)
if [[ "$arch" == "x86_64" ]]; then
    ipfsdistr="https://github.com/ipfs/kubo/releases/download/v0.34.1/kubo_v0.34.1_linux-amd64.tar.gz"
    yggdistr="https://github.com/yggdrasil-network/yggdrasil-go/releases/download/v0.5.12/yggdrasil-0.5.12-amd64.deb"
elif [[ "$arch" == "aarch64" ]]; then
    ipfsdistr="https://github.com/ipfs/kubo/releases/download/v0.34.1/kubo_v0.34.1_linux-arm64.tar.gz"
    yggdistr="https://github.com/yggdrasil-network/yggdrasil-go/releases/download/v0.5.12/yggdrasil-0.5.12-arm64.deb"
fi

echo PATH="$PATH:/home/$USER/.local/bin:$PWD/bin" | sudo tee /etc/environment
echo COPYRUS="$PWD" | sudo tee -a /etc/environment
echo IPFS_PATH="$PWD/data/.ipfs" | sudo tee -a /etc/environment
source /etc/environment
echo -e "PATH=$PATH\nCOPYRUS=$PWD\nIPFS_PATH=$IPFS_PATH\n$(sudo crontab -l)\n" | sudo crontab -
sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -yq
sudo DEBIAN_FRONTEND=noninteractive apt install -y git docker.io docker-compose-v2 build-essential python3-dev python3-pip python3-venv tmux cron iputils-ping net-tools unzip btop nginx
sudo usermod -aG docker $USER
sudo systemctl restart docker
python3 -m venv venv
source venv/bin/activate
pip install reader[cli] -q

currentdate=$(date -u +%Y%m%d%H%M%S)
wget -O temp/ygg.deb $yggdistr
sudo dpkg -i temp/ygg.deb
sudo sed -i 's#^  Peers: \[\]$#  Peers: \[\n    tls://185.103.109.63:65534\n  \]#' /etc/yggdrasil/yggdrasil.conf
sudo sed -i 's#^  Listen: \[\]$#  Listen: \[\]\n  AdminListen: 127.0.0.1:9001\n#' /etc/yggdrasil/yggdrasil.conf
sudo sed -i "s#^  NodeInfo: {}#  NodeInfo: \{\n    name:copyrus-$currentdate\n  \}#" /etc/yggdrasil/yggdrasil.conf
sudo systemctl restart yggdrasil
ping -6 -c 6 222:a8e4:50cd:55c:788e:b0a5:4e2f:a92c

sudo mkdir /ipfs /ipns
sudo chmod 777 /ipfs
sudo chmod 777 /ipns
export IPFS_PATH=$PWD/data/.ipfs
wget -O temp/kubo.tar.gz $ipfsdistr
tar xvzf temp/kubo.tar.gz -C temp
sudo mv temp/kubo/ipfs /usr/local/bin/ipfs
ipfs init --profile server
ipfs config --json Experimental.FilestoreEnabled true
ipfs config --json Pubsub.Enabled true
ipfs config --json Ipns.UsePubsub true
ipfs config profile apply lowpower
ipfs config Addresses.Gateway /ip4/127.0.0.1/tcp/8083
ipfs config Addresses.API /ip4/127.0.0.1/tcp/5003
sed -i "s/4001/$IPFSPORT/g" $PWD/data/.ipfs/config
sed -i "s/104.131.131.82\/tcp\/$IPFSPORT/104.131.131.82\/tcp\/4001/g" $PWD/data/.ipfs/config
sed -i "s/104.131.131.82\/udp\/$IPFSPORT/104.131.131.82\/udp\/4001/g" $PWD/data/.ipfs/config
echo -e "\
[Unit]\n\
Description=InterPlanetary File System (IPFS) daemon\n\
Documentation=https://docs.ipfs.tech/\n\
After=network.target\n\
\n\
[Service]\n\
MemorySwapMax=0\n\
TimeoutStartSec=infinity\n\
Type=notify\n\
User=$USER\n\
Group=$USER\n\
Environment=IPFS_PATH=$PWD/data/.ipfs\n\
ExecStart=/usr/local/bin/ipfs daemon --enable-gc --mount --mount-ipfs=/ipfs --mount-ipns=/ipns --migrate=true\n\
Restart=on-failure\n\
KillSignal=SIGINT\n\
\n\
[Install]\n\
WantedBy=default.target\n\
" | sudo tee /etc/systemd/system/ipfs.service
sudo systemctl daemon-reload
sudo systemctl enable ipfs
sudo systemctl restart ipfs

cat <<EOF >>$PWD/bin/ipfssub.sh
#!/usr/bin/env bash

/usr/local/bin/ipfs pubsub sub copyrus >> $PWD/data/sub.txt
EOF
chmod +x $PWD/bin/ipfssub.sh

echo -e "\
[Unit]\n\
Description=InterPlanetary File System (IPFS) subscription\n\
After=network.target\n\
\n\
[Service]\n\
Type=simple\n\
User=$USER\n\
Group=$USER\n\
Environment=IPFS_PATH=$PWD/data/.ipfs\n\
ExecStartPre=/usr/bin/sleep 5\n\
ExecStart=$PWD/bin/ipfssub.sh\n\
Restart=on-failure\n\
KillSignal=SIGINT\n\
\n\
[Install]\n\
WantedBy=default.target\n\
" | sudo tee /etc/systemd/system/ipfssub.service
sudo systemctl daemon-reload
sudo systemctl enable ipfssub
sudo systemctl restart ipfssub
sleep 9

ipfs bootstrap add /ip6/21f:5234:5548:31e5:a334:854b:5752:f4fc/tcp/4001/p2p/12D3KooWNNhG9Qzopb3wtytrxpZdRikMgNq6hWinVmuaWFjYCjcZ
ipfs bootstrap add /ip6/21f:5234:5548:31e5:a334:854b:5752:f4fc/udp/4001/quic/p2p/12D3KooWNNhG9Qzopb3wtytrxpZdRikMgNq6hWinVmuaWFjYCjcZ

echo -e "$(sudo crontab -l)\n@reboot echo \"\$(date -u) System is rebooted\" >> $PWD/data/log.txt\n* * * * * su $USER -c \"bash $PWD/bin/cron.sh\"" | sudo crontab -

sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt install -y ca-certificates curl gnupg
sudo rm /etc/apt/keyrings/nodesource.gpg
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
NODE_MAJOR=22
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update && sudo apt-get install nodejs -y
node -v
npm -v

sudo DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y php8.4-fpm php8.4-mysql php8.4-mbstring php8.4-xml php8.4-zip php8.4-curl php8.4-gd
sudo cat << EOF | sudo tee /etc/nginx/sites-available/default
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        root /var/www/html;
        server_name _;
        index index.php index.html index.htm index.nginx-debian.html;
        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        }
}
EOF
sudo nginx -t
sudo chown -R www-data:www-data /var/www/html
cat << EOF | sudo -u www-data tee /var/www/html/index.php > /dev/null
<?php
    echo "Hello World!<br>GMT";
    echo gmdate("Y-m-d");
?>
EOF
sudo systemctl restart nginx

echo -n "IPFS status:"
ipfs cat QmYwoMEk7EvxXi6LcS2QE6GqaEYQGzfGaTJ9oe1m2RBgfs/test.txt
echo -n "IPFSmount status:"
cat /ipfs/QmYwoMEk7EvxXi6LcS2QE6GqaEYQGzfGaTJ9oe1m2RBgfs/test.txt

cd "$(dirname "$0")"
sleep 9
rm -rf temp
mkdir temp
str=$(ipfs id) && echo $str | cut -c10-61 > $PWD/data/id.txt
(echo -n "$(date -u) Copyrus system is installed. ID=" && cat $PWD/data/id.txt) >> $PWD/data/log.txt
ipfspub 'Initial message'
ipfs pubsub pub copyrus $PWD/data/log.txt
sudo reboot
