#/bin/sh
apt-get update
apt-get upgrade -y
apt-get install gnupg dirmngr -y --install-recommends
grep "^deb .*webupd8team" /etc/apt/sources.list || echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list
grep "^deb-src .*webupd8team" /etc/apt/sources.list || echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" >> /etc/apt/sources.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C2518248EEA14886
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886
apt-get update
apt-get upgrade -y
echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
apt-get install git oracle-java8-installer oracle-java8-set-default -y --allow-unauthenticated
useradd -d /home/ict -m -s /bin/bash ict
cd /home/ict
git clone https://github.com/Come-from-beyond/Ict.git
cd /home/ict/Ict
javac /home/ict/Ict/src/cfb/ict/*.java

cat <<EOF > /home/ict/Ict/run-ict.sh
#!/bin/bash
cd /home/ict/Ict/src
java cfb.ict.Ict /home/ict/config/ict.properties
EOF

echo <<EOF > /home/ict/Ict/update-ict.sh
#!/bin/bash
git pull
javac src/cfb/ict/*.java
systemctl restart ict
EOF

chmod a+x run-ict.sh update-ict.sh

mkdir -p /home/ict/config
cat <<EOF > /home/ict/config/ict.properties
host = 0.0.0.0
port = 14265
//Discord neighbor:
neighborAHost = 127.0.0.1
neighborAPort = 14265
//Discord neighbor:
neighborBHost = 127.0.0.2
neighborBPort = 14265
//Discord neighbor:
neighborCHost = 127.0.0.3
neighborCPort = 14265
EOF

chown -R ict /home/ict/config /home/ict/Ict

cat <<EOF > /lib/systemd/system/ict.service
[Unit]
Description=IOTA ICT
After=network.target
[Service]
ExecStart=/bin/bash -u run-ict.sh
WorkingDirectory=/home/ict/Ict
StandardOutput=inherit
StandardError=inherit
Restart=always
User=ict
[Install]
WantedBy=multi-user.target
EOF

systemctl enable ict
echo "2 22 * * * systemctl restart ict" >> /var/spool/cron/crontabs/root
systemctl start ict
journalctl -u ict
