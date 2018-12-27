#/bin/sh

ICTHOME="/home/ict"
ICTDIR="omega-ict"
GITREPO="iotaledger/ict"
HOST="0.0.0.0"
PORT="14265"
NEIGHBORS="127.0.0.1:14265,127.0.0.2:14265,127.0.0.3:14265"

if [ -z "$1" ] || [ "$1" != "BUILD" -a "$1" != "RELEASE" ] ; then
	echo 'Please choose between BUILD or RELEASE:'
    echo './$0 [BUILD|RELEASE]'
    exit
fi

apt-get update
apt-get upgrade -y
apt-get install curl -y --install-recommends

useradd -d ${ICTHOME} -m -s /bin/bash ict
mkdir -p ${ICTHOME}/${ICTDIR}
cd ${ICTHOME}/${ICTDIR}

if [ "$1" = "BUILD" ]; then
	apt-get install git gnupg dirmngr gradle -y --install-recommends
	grep "^deb .*webupd8team" /etc/apt/sources.list || echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list
	grep "^deb-src .*webupd8team" /etc/apt/sources.list || echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" >> /etc/apt/sources.list
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C2518248EEA14886
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886
	apt-get update
	apt-get upgrade -y
	echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
	echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
	apt-get install oracle-java8-installer oracle-java8-set-default -y --allow-unauthenticated

	if [ -d ${ICTHOME}/${ICTDIR}/ict/.git ]; then
		cd ${ICTHOME}/${ICTDIR}/ict
		git pull
	else
		cd ${ICTHOME}/${ICTDIR}
		git clone https://github.com/${GITREPO}
	fi
	cd ${ICTHOME}/${ICTDIR}/ict
	rm -f *.jar
	gradle fatJar
	VERSION=`ls *.jar | sed -e 's/ict-\(.*\)\.jar/\1/'`
fi

if [ "$1" = "RELEASE" ]; then
	VERSION=`curl --silent "https://api.github.com/repos/${GITREPO}/releases" | grep '"tag_name":' |head -1 | sed -E 's/.*"([^"]+)".*/\1/'`
	if [ ! -f ict/ict-${VERSION}.jar ]; then
			mkdir ict
			cd ict
			rm -f *.jar
			wget https://github.com/iotaledger/ict/releases/download/${VERSION}/ict-${VERSION}.jar
	fi
fi


cat <<EOF > ${ICTHOME}/run-ict.sh
#!/bin/sh
cd ${ICTHOME}/${ICTDIR}
#start ixi here
java -jar ict/ict-${VERSION}.jar -c ${ICTHOME}/config/ict.cfg
EOF

chmod a+x ${ICTHOME}/run-ict.sh

mkdir -p ${ICTHOME}/config

if [ ! -f ${ICTHOME}/config/ict.cfg ]; then
	if [ -f ${ICTHOME}/config/ict.properties ]; then
		HOST=`sed -ne 's/^host\s*=\s*//gp' ${ICTHOME}/config/ict.properties`
		PORT=`sed -ne 's/^port\s*=\s*//gp' ${ICTHOME}/config/ict.properties`
		NEIGHBORS=`sed -ne 's/^neighbor\(A\|B\|C\)\(Host\|Port\)\s*=\s*//gp' ${ICTHOME}/config/ict.properties | sed ':a;N;$!ba;s/\n/:/g;s/:\([^:]*\):/:\1,/g'`
	fi	
	cat <<EOF > ${ICTHOME}/config/ict.cfg
name=ict
ixis=
port=${PORT}
log_round_duration=60000
ixi_enabled=false
spam_enabled=false
min_forward_delay=0
host=${HOST}
neighbors=${NEIGHBORS}
max_forward_delay=200
EOF
fi

chown -R ict ${ICTHOME}/config ${ICTHOME}/${ICTDIR}

cat <<EOF > /lib/systemd/system/ict.service
[Unit]
Description=IOTA ICT
After=network.target
[Service]
ExecStart=/bin/bash -u ${ICTHOME}/run-ict.sh
WorkingDirectory=${ICTHOME}/${ICTDIR}
StandardOutput=inherit
StandardError=inherit
Restart=always
User=ict
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ict
if [ -f /var/spool/cron/crontabs/root ]; then
	if [ `grep -c "systemctl restart ict" /var/spool/cron/crontabs/root` -eq 0 ]; then
		echo "2 22 * * * systemctl restart ict" >> /var/spool/cron/crontabs/root
	fi
	else
		grep "systemctl restart ict" /etc/crontab || echo "2 22 * * * systemctl restart ict" >> /etc/crontab
	fi

systemctl restart ict
journalctl -fu ict
