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

emerge -u curl
VERSION=`curl --silent "https://api.github.com/repos/${GITREPO}/releases" | grep '"tag_name":' |head -1 | sed -E 's/.*"([^"]+)".*/\1/'`

useradd -d ${ICTHOME} -m -s /bin/bash ict
mkdir -p ${ICTHOME}/${ICTDIR}
cd ${ICTHOME}/${ICTDIR}

if [ "$1" = "BUILD" ]; then
	emerge -u git wget
	cd /tmp
	wget https://raw.githubusercontent.com/metalcated/scripts/master/install_java.sh -O -  | sed -e 's/^JAVA_TYPE="jre"/JAVA_TYPE="jdk"/' | sh
	gradle_version=2.10
	wget -c http://services.gradle.org/distributions/gradle-${gradle_version}-all.zip
	unzip  gradle-${gradle_version}-all.zip -d /opt
	ln -s /opt/gradle-${gradle_version} /opt/gradle
	printf "export GRADLE_HOME=/opt/gradle\nexport PATH=\$PATH:\$GRADLE_HOME/bin\n" > /etc/profile.d/gradle.sh
	source /etc/profile.d/gradle.sh

	if [ -d ${ICTHOME}/${ICTDIR}/ict/.git ]; then
		cd ${ICTHOME}/${ICTDIR}/ict
		git pull
	else
		cd ${ICTHOME}/${ICTDIR}
		git clone https://github.com/${GITREPO}
	fi
	cd ${ICTHOME}/${ICTDIR}/ict
	gradle fatJar
fi

if [ "$1" = "RELEASE" ]; then
	if [ ! -f ict/ict-${VERSION}.jar ]; then
			mkdir ict
			cd ict
			wget https://github.com/iotaledger/ict/releases/download/${VERSION}/ict-${VERSION}.jar
	fi
fi


cat <<EOF > ${ICTHOME}/run-ict.sh
#!/bin/bash
cd ${ICTHOME}/${ICTDIR}
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

cat <<EOF > /etc/init.d/ict
#!/sbin/openrc-run

name="ict daemon"
description="IOTA ict node"
command="${ICTHOME}/run-ict.sh"
pidfile=/var/run/ict.pid

depend() {
  need net
  use logger dns
}

start() {
  ebegin "Starting ICT"
  start-stop-daemon --start -u ict -d ${ICTHOME}/${ICTDIR} \\
    -1 /var/log/ict.log \\
    --exec \${command} \${command_args} \\
    -b -m --pidfile \${pidfile}
  eend $?
}

stop() {
  ebegin "Stopping ICT"
  start-stop-daemon --stop -u ict --exec \${command} \\
    --pidfile \${pidfile}
  eend $?
}
EOF

rc-update add ict
if [ `grep -c "systemctl restart ict" /etc/crontab` -eq 0 ]; then
        echo "2 22 * * * systemctl restart ict" >> /etc/crontab
fi

/etc/init.d/ict restart
tail -f /var/log/ict.log

