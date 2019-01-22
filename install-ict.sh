#!/bin/sh

ICTHOME="/home/ict"
ICTDIR="omega-ict"
GITREPO="iotaledger/ict"

if [ "$(id -u)" != "0" ]; then
	echo "Please run as root or sudo ./$0 BUILD|RELEASE|EXPERIMENTAL [NODENAME]."
	exit 1
fi

if [ -z "$1" ] || [ "$1" != "BUILD" -a "$1" != "RELEASE" -a "$1" != "EXPERIMENTAL" ] ; then
	echo "Please choose between BUILD or RELEASE:"
    echo "./$0 BUILD|RELEASE|EXPERIMENTAL [NODENAME]"
    exit 1
fi

PKGMANAGER=$( command -v apt-get || command -v yum || command -v dnf || command -v emerge || command -v pkg ) || exit "Cannot find the appropriate package manager"
echo "### Setting package manager to ${PKGMANAGER}"
case "$PKGMANAGER" in
*apt-get* )
	${PKGMANAGER} update -y
	${PKGMANAGER} upgrade -y
	${PKGMANAGER} install -y curl wget unzip 
	
	JAVA_PATH=$(which java)
	JAVAC_PATH=$(which javac)
	if [ -z "${JAVA_PATH}" -o -z "${JAVAC_PATH}" ] ; then
		echo "### Installing default-jdk-headless"
		sed -i "/^deb .*webupd8team.*$/d;/^deb-src .*webupd8team.*$/d" /etc/apt/sources.list
		rm -f /etc/profile.d/jdk.*
		apt-get install default-jdk-headless -y --allow-unauthenticated
		update-alternatives --auto java 
		update-alternatives --auto javac
	fi
	JAVA_PATH=$(which java)
	JAVAC_PATH=$(which javac)
	if [ -z "${JAVA_PATH}" -o -z "${JAVAC_PATH}" ] ; then 
		echo "### Installing java-11"
		sed -i "/^deb .*webupd8team.*$/d;/^deb-src .*webupd8team.*$/d" /etc/apt/sources.list
		echo "deb http://ppa.launchpad.net/linuxuprising/java/ubuntu bionic main" | tee /etc/apt/sources.list.d/linuxuprising-java.list
		apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 73C3DB2A
		apt-get update
		apt --fix-broken install
		echo oracle-java11-installer shared/accepted-oracle-license-v1-2 select true | /usr/bin/debconf-set-selections
		echo oracle-java11-installer shared/accepted-oracle-licence-v1-2 boolean true | /usr/bin/debconf-set-selections
		apt-get install oracle-java11-installer oracle-java11-set-default -y --allow-unauthenticated
	fi
	
	if [ "$1" = "EXPERIMENTAL" ]; then
		${PKGMANAGER} install -y --fix-missing maven libzmq3-dev pkg-config
		curl https://sh.rustup.rs -sSf | sh -s -- -y 
		source ~/.cargo/env || export PATH="/root/.cargo/bin:$PATH"
	fi
	JAVA_HOME=$(update-alternatives --get-selections | sed -ne "s/^java[[:space:]]\+[a-z]\+[[:space:]]\+\(.*\)\/bin\/java$/\1/p")

	;;
* )
	if [ "$PKGMANAGER" = "/usr/bin/emerge" ]; then
		${PKGMANAGER} --sync
		${PKGMANAGER} -u curl wget unzip	
	else
		${PKGMANAGER} update -y
		${PKGMANAGER} upgrade -y
		${PKGMANAGER} install -y curl wget unzip	
	fi
	JAVA_PATH=$(which java)
	JAVAC_PATH=$(which javac)
	if [ -z "${JAVA_PATH}" -o -z "${JAVAC_PATH}" ] ; then
		cd /tmp
		wget https://raw.githubusercontent.com/phschaeff/ict-install/master/install_java.sh -O -  | sh
	fi
	JAVA_HOME=$(update-alternatives --list | sed -ne "s/^java[[:space:]]\+[a-z]\+[[:space:]]\+\(.*\)\/bin\/java$/\1/p")
	if [ "$1" = "EXPERIMENTAL" ]; then
		exit "### Currently not supported"
	fi

	;;
esac
echo "### JAVA_HOME set to ${JAVA_HOME}"

echo "### Setting time, preparing user and directories"
date --set="$(curl -v --insecure --silent https://google.com/ 2>&1 | grep -i "^< date" | sed -e 's/^< date: //i')"
useradd -d ${ICTHOME} -m -s /bin/bash ict
mkdir -p ${ICTHOME}/${ICTDIR}
cd ${ICTHOME}/${ICTDIR}

if [ "$1" = "BUILD" -o "$1" = "EXPERIMENTAL" ]; then
	echo "### Installing dependencies for BUILD" 
	case "$PKGMANAGER" in
	*apt-get* )
		${PKGMANAGER} install -y --fix-missing git gnupg dirmngr net-tools nodejs npm
		${PKGMANAGER} remove gradle -y
		if [ "$1" = "EXPERIMENTAL" ]; then
			${PKGMANAGER} install -y --fix-missing maven libzmq3-dev pkg-config
			curl https://sh.rustup.rs -sSf | sh -s -- -y 
			source ~/.cargo/env || export PATH="/root/.cargo/bin:$PATH"
		fi
		;;
	* )
		${PKGMANAGER} -u git net-tools maven nodejs npm 2>/dev/null || ${PKGMANAGER} install -y git net-tools nodejs npm
		${PKGMANAGER} purge gradle -y
		if [ "$1" = "EXPERIMENTAL" ]; then
			exit "### Currently not supported"
		fi
		;;
	esac

	gradle_version=4.10
	echo "### Installing gradle version ${gradle_version}"
	if [ ! -d /opt/gradle-${gradle_version} ] ; then
		cd /tmp
		wget -c http://services.gradle.org/distributions/gradle-${gradle_version}-all.zip
		unzip -o gradle-${gradle_version}-all.zip -d /opt
		printf "export GRADLE_HOME=/opt/gradle\nexport PATH=\$PATH:\$GRADLE_HOME/bin\n" > /etc/profile.d/gradle.sh
	fi
	rm -f /opt/gradle
	ln -f -s /opt/gradle-${gradle_version} /opt/gradle
	export GRADLE_HOME=/opt/gradle
	source /etc/profile.d/gradle.sh
	
	echo "### Pulling and building ICT source"
	if [ -d ${ICTHOME}/${ICTDIR}/ict/.git ]; then
		cd ${ICTHOME}/${ICTDIR}/ict
		git pull origin dev
		git reset --hard origin/dev
	else
		cd ${ICTHOME}/${ICTDIR}
		rm -rf ict
		git clone https://github.com/${GITREPO}
		cd ict
		git branch dev
	fi
	cd ${ICTHOME}/${ICTDIR}/ict
	rm -f *.jar
	/opt/gradle/bin/gradle fatJar || exit "BUILD did not work. Try ./$0 RELEASE [NODENAME]"
	VERSION=`ls *.jar | sed -e 's/ict\(.*\)\.jar/\1/'`
	echo "### Installing Node.js modules required by ICT"
	cd ${ICTHOME}/${ICTDIR}/ict/web
	npm install
	echo "### Done building ICT$VERSION"
	
	echo "### Pulling and building Report.ixi source"
	if [ -d ${ICTHOME}/${ICTDIR}/Report.ixi/.git ]; then
		cd ${ICTHOME}/${ICTDIR}/Report.ixi
		git pull origin dev
		git reset --hard origin/dev
	else
		cd ${ICTHOME}/${ICTDIR}
		rm -rf ${ICTHOME}/${ICTDIR}/Report.ixi
		git clone https://github.com/trifel/Report.ixi
		cd Report.ixi
		git branch dev
		git pull origin dev
		git reset --hard origin/dev		
	fi
	cd ${ICTHOME}/${ICTDIR}/Report.ixi
	rm -f *.jar
	/opt/gradle/bin/gradle fatJar
	REPORT_IXI_VERSION=`ls *.jar | sed -e 's/report.ixi\(.*\)\.jar/\1/'`
	echo "### Done building Report.ixi$REPORT_IXI_VERSION"
	
	echo "### Pulling and building Chat.ixi source"
	cd ${ICTHOME}/${ICTDIR}
	if [ -d ${ICTHOME}/${ICTDIR}/chat.ixi/.git ]; then
		cd ${ICTHOME}/${ICTDIR}/chat.ixi
		git pull origin dev
		git reset --hard origin/dev
	else
		cd ${ICTHOME}/${ICTDIR}
		rm -rf ${ICTHOME}/${ICTDIR}/chat.ixi
		git clone https://github.com/iotaledger/chat.ixi
		cd chat.ixi
		git branch dev
		git pull origin dev
		git reset --hard origin/dev
	fi
	cd ${ICTHOME}/${ICTDIR}/chat.ixi
	rm -f *.jar
	/opt/gradle/bin/gradle ixi
	CHAT_IXI_VERSION=`ls *.jar | sed -e 's/chat.ixi\(.*\)\.jar/\1/'`
	echo "### Done building Chat.ixi$CHAT_IXI_VERSION"
	
	if [ "$1" = "EXPERIMENTAL" ]; then
		echo "### Pulling and building ZeroMQ.ixi source"
		cd ${ICTHOME}/${ICTDIR}
		if [ -d ${ICTHOME}/${ICTDIR}/iota-ixi-zeromq/.git ]; then
			cd ${ICTHOME}/${ICTDIR}/iota-ixi-zeromq
			rm -rf ${ICTHOME}/${ICTDIR}/iota-ixi-zeromq/target
			git pull
		else
			cd ${ICTHOME}/${ICTDIR}
			rm -rf ${ICTHOME}/${ICTDIR}/iota-ixi-zeromq
			git clone https://gitlab.com/Stefano_Core/iota-ixi-zeromq.git
		fi
		cd ${ICTHOME}/${ICTDIR}
		if [ -d ${ICTHOME}/${ICTDIR}/iota-ict-zmq-listener/.git ]; then
			cd ${ICTHOME}/${ICTDIR}/iota-ict-zmq-listener
			git pull
		else
			cd ${ICTHOME}/${ICTDIR}
			rm -rf ${ICTHOME}/${ICTDIR}/iota-ict-zmq-listener
			git clone https://gitlab.com/Stefano_Core/iota-ict-zmq-listener.git
		fi
		cd ${ICTHOME}/${ICTDIR}/iota-ict-zmq-listener/
		npm install && echo "### Done building ICT-ZMQ-Listener"

		echo "### Pulling and building ictmon.ixi source"
		cd ${ICTHOME}/${ICTDIR}
		if [ -d ${ICTHOME}/${ICTDIR}/ictmon/.git ]; then
			cd ${ICTHOME}/${ICTDIR}/ictmon
			git pull
		else
			cd ${ICTHOME}/${ICTDIR}
			rm -rf ${ICTHOME}/${ICTDIR}/ictmon
			git clone https://github.com/Alex6323/ictmon.git
		fi
		cd ${ICTHOME}/${ICTDIR}/ictmon/ 
		cargo build --release && echo "### Done building ictmon.ixi"
	fi
	ICTOPTIONS="--debug"
fi

if [ "$1" = "RELEASE" ]; then
	cd ${ICTHOME}/${ICTDIR}
	VERSION=`curl --silent "https://api.github.com/repos/${GITREPO}/releases" | grep '"tag_name":' |head -1 | sed -E 's/.*"([^"]+)".*/\1/'`
	mkdir ict
	cd ict
	rm -f *.jar
	wget -c https://github.com/iotaledger/ict/releases/download/${VERSION}/ict-${VERSION}.jar
	VERSION="-${VERSION}"
	echo "### Done downloading ICT$VERSION"
	
	cd ${ICTHOME}/${ICTDIR}
	REPORT_IXI_VERSION=`curl --silent "https://api.github.com/repos/trifel/Report.ixi/releases" | grep '"tag_name":' |head -1 | sed -E 's/.*"([^"]+)".*/\1/'`
	mkdir Report.ixi
	cd Report.ixi
	rm -f *.jar *.zip
	wget -c https://github.com/trifel/Report.ixi/releases/download/${REPORT_IXI_VERSION}/report.ixi-${REPORT_IXI_VERSION}.jar
	REPORT_IXI_VERSION="-${REPORT_IXI_VERSION}"
	echo "### Done downloading Report.ixi$REPORT_IXI_VERSION"
	
	cd ${ICTHOME}/${ICTDIR}
	CHAT_IXI_VERSION=`curl --silent "https://api.github.com/repos/iotaledger/chat.ixi/releases" | grep '"tag_name":' |head -1 | sed -E 's/.*"([^"]+)".*/\1/'`
	mkdir chat.ixi
	cd chat.ixi
	rm -f *.jar *.zip
	wget -c https://github.com/iotaledger/chat.ixi/releases/download/${CHAT_IXI_VERSION}/chat.ixi-${CHAT_IXI_VERSION}.jar
	CHAT_IXI_VERSION="-${CHAT_IXI_VERSION}"
	echo "### Done downloading Chat.ixi$CHAT_IXI_VERSION"
fi

echo "### Preparing directories, run script, and configs"

mkdir -p ${ICTHOME}/config

echo "### Creating default ict.cfg template"
cd ${ICTHOME}/${ICTDIR}
rm -f ict.cfg
java -jar ${ICTHOME}/${ICTDIR}/ict/ict${VERSION}.jar --config-create &
last_pid=$!
while [ ! -f ict.cfg ] ; do sleep 1 ; done
sleep 1
kill -KILL $last_pid 2>/dev/null 1>/dev/null
rm -rf web

if [ ! -f ${ICTHOME}/config/ict.cfg ]; then
	if [ -f ${ICTHOME}/config/ict.properties ]; then
		echo "### Importing from old ict.properties"
		host=`sed -ne 's/^host\s*=\s*//gp' ${ICTHOME}/config/ict.properties`
		port=`sed -ne 's/^port\s*=\s*//gp' ${ICTHOME}/config/ict.properties`
		neighbors=`sed -ne 's/^neighbor\(A\|B\|C\)\(Host\|Port\)\s*=\s*//gp' ${ICTHOME}/config/ict.properties | sed ':a;N;$!ba;s/\n/:/g;s/:\([^:]*\):/:\1,/g'`
		sed -i "s/^host=.*$/host=$host/;s/^port=.*$/port=$port/;s/^neighbors=.*$/neighbors=$neighbors/" ict.cfg
	fi
else
	echo "### Importing from existing ict.cfg"
	grep -v "^#" ${ICTHOME}/config/ict.cfg | while IFS="=" read -r varname value ; do
		echo "### Setting config $varname to ${value}"
		sed -i "s/^$varname=.*$/$varname=$value/" ict.cfg
		cp -f ict.cfg ${ICTHOME}/config/ict.cfg
	done
fi

if [ /bin/true ]; then
	echo "### Adapting run script and configs for IXIs"
	cat <<EOF > ${ICTHOME}/run-ict.sh
#!/bin/sh
cd ${ICTHOME}/${ICTDIR}
java -jar ${ICTHOME}/${ICTDIR}/ict/ict${VERSION}.jar -c ${ICTHOME}/config/ict.cfg ${ICTOPTIONS} &
ict_pid=\$!
echo \$ict_pid > ict.pid
EOF
	cat <<EOF > ${ICTHOME}/stop-ict.sh
#!/bin/sh
cd ${ICTHOME}/${ICTDIR}
kill \$(cat ${ICTHOME}/${ICTDIR}/ict.pid)
EOF
	chmod a+x ${ICTHOME}/run-ict.sh ${ICTHOME}/stop-ict.sh
	cd ${ICTHOME}/${ICTDIR}
	cp -f ${ICTHOME}/${ICTDIR}/Report.ixi/report.ixi${REPORT_IXI_VERSION}.jar ${ICTHOME}/${ICTDIR}/modules/report.ixi${REPORT_IXI_VERSION}.jar
	echo "### Creating default report.ixi.cfg template"
	echo "name=nick (ict-0)" > report.ixi.cfg
	echo "neighbors=127.0.0.1\:1338" >> report.ixi.cfg
	echo "reportPort=1338" >> report.ixi.cfg
	echo "### Setting config neighbors in report.ixi.cfg"
	neighbors=`sed -ne 's/:[[:digit:]]\+/:1338/g;s/^neighbors\s*=\s*//gp' ict.cfg`
	sed -i "s/^neighbors=.*$/neighbors=$neighbors/" report.ixi.cfg

	if [ -f ${ICTHOME}/config/report.ixi.cfg -a ! -h ${ICTHOME}/config/report.ixi.cfg ]; then
		echo "### Importing from old report.ixi.cfg"
		grep -v "^#" ${ICTHOME}/config/report.ixi.cfg | while IFS="=" read -r varname value ; do
			echo "### Setting config $varname to ${value} in report.ixi.cfg"
			sed -i "s/^$varname=.*$/$varname=$value/" report.ixi.cfg
		done
		if [ `grep -c "^neighbor[A|B|C][Host|Port]" report.ixi.cfg` -gt 0 ] && [ `grep -c "^neighbors=[^[:space:]+]" report.ixi.cfg` -eq 0 ]  ; then 
			neighbors=`sed -ne 's/^neighbor\(A\|B\|C\)\(Host\|Port\)\s*=\s*//gp' ../config/report.ixi.cfg | sed ':a;N;$!ba;s/\n/:/g;s/:\([^:]*\):/:\1,/g'`
			echo "### Converting neighbor?Host syntax to $neighbors"
			sed -i "s/^neighbors=.*$/neighbors=$neighbors/" report.ixi.cfg
		fi 
		sed -i "/^neighbor[A|B|C][Host|Port]/d" report.ixi.cfg
		rm -f ${ICTHOME}/config/report.ixi.cfg
	fi
	if [ -f ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg ]; then
		cp -f ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg.last
		echo "### Importing from existing report.ixi.cfg"
		grep -v "^#" ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg | while IFS="=" read -r varname value ; do
			echo "### Setting config $varname to ${value} in report.ixi.cfg"
			sed -i "s/^$varname=.*$/$varname=$value/" report.ixi.cfg
		done
	fi
	if [ -n "$2" ] ; then
		echo "### Setting nodename of the node to $2"
		sed -i "s/^name=.*$/name=$2/" report.ixi.cfg
	fi
	if [ `grep -Ec "^name=[^()]+ \(ict-[[:digit:]]+\)$" report.ixi.cfg` -eq 0 ] ; then
		nodename=""
		while [ `echo "$nodename" | grep -Ec "^[^()]+ \(ict-[[:digit:]]+\)$"` -eq 0 ] ; do
			echo "### Please give your node an individual name. Follow the naming convention: <name> (ict-<number>)"
			read -r nodename
		done
		sed -i "s/^name=.*$/name=$nodename/" report.ixi.cfg
	fi

	mkdir -p ${ICTHOME}/${ICTDIR}/modules/report.ixi
	cp -f report.ixi.cfg ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg
	rm -f ${ICTHOME}/config/report.ixi.cfg
	ln -s ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg ${ICTHOME}/config/
#	sed -i "s/^ixi_enabled=.*$/ixi_enabled=true/" ict.cfg
	rm -f ${ICTHOME}/${ICTDIR}/modules/report.ixi*jar
	cp -f ${ICTHOME}/${ICTDIR}/Report.ixi/report.ixi${REPORT_IXI_VERSION}.jar ${ICTHOME}/${ICTDIR}/modules/report.ixi${REPORT_IXI_VERSION}.jar
	
	if [ -f ${ICTHOME}/config/chat.ixi.cfg -a ! -h ${ICTHOME}/config/chat.ixi.cfg ] ; then
		CHATUSER=`sed -ne "s/^username=\(.*\)$/\1/gp" ${ICTHOME}/config/chat.ixi.cfg`
		RANDOMPASS=`sed -ne "s/^password=\(.*\)$/\1/gp" ${ICTHOME}/config/chat.ixi.cfg`
	elif [ -f ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg ] ; then
		CHATUSER=`sed -ne "s/^username=\(.*\)$/\1/gp" ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg`
		RANDOMPASS=`sed -ne "s/^password=\(.*\)$/\1/gp" ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg`
		ln -s ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg ${ICTHOME}/config/
	else 
		mkdir -p ${ICTHOME}/${ICTDIR}/modules/chat-config
		CHATUSER=`sed -ne "s/^name=\(.*\) .*$/\1/p" report.ixi.cfg`
		RANDOMPASS=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12`
		#read -e -p "Enter a password for Chat.ixi API:" -i "${CHATUSER}" CHATUSER
		#read -e -p "Enter a password for Chat.ixi API:" -i "${RANDOMPASS}" RANDOMPASS
		echo "username=$CHATUSER" > ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg
		echo "password=$RANDOMPASS" >> ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg
		ln -s ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg ${ICTHOME}/config/
	fi
	rm -f ${ICTHOME}/config/chat.ixi.cfg
	rm -rf ${ICTHOME}/${ICTDIR}/modules/chat.ixi*
	cp -f ${ICTHOME}/${ICTDIR}/chat.ixi/chat.ixi${CHAT_IXI_VERSION}.jar ${ICTHOME}/${ICTDIR}/modules/chat.ixi${CHAT_IXI_VERSION}.jar
	
	if [ "$1" = "EXPERIMENTAL" ]; then
		if [ ! -f ${ICTHOME}/${ICTDIR}/modules/zeromq.ixi/zeromq.ixi.cfg ] ; then
			mkdir -p ${ICTHOME}/${ICTDIR}/modules/zeromq.ixi
			echo "ZMQPORT=5560" > ${ICTHOME}/${ICTDIR}/modules/zeromq.ixi/zeromq.ixi.cfg
			rm -f ${ICTHOME}/config/zeromq.ixi.cfg
			ln -s ${ICTHOME}/${ICTDIR}/modules/zeromq.ixi/zeromq.ixi.cfg ${ICTHOME}/config/
		fi
		rm -f ${ICTHOME}/${ICTDIR}/modules/ixi-zeromq*jar
		cp -f ${ICTHOME}/${ICTDIR}/iota-ixi-zeromq/ixi-zeromq/target/ixi-zeromq-jar-with-dependencies.jar ${ICTHOME}/${ICTDIR}/modules/
	fi
fi

echo "### Writing new configs"
cd ${ICTHOME}/${ICTDIR}
cp -f ${ICTHOME}/config/ict.cfg ${ICTHOME}/config/ict.cfg.last
cp -f ict.cfg ${ICTHOME}/config/ict.cfg 
chown -R ict ${ICTHOME}/config ${ICTHOME}/${ICTDIR}

echo "### Deleting old directories and temporary files"
cd ${ICTHOME}/${ICTDIR}
rm -rf *ctx* *.key *.cfg logs ixi channels.txt contacts.txt ${ICTHOME}/config/*.properties ${ICTHOME}/config/*.key ${ICTHOME}/config/*.txt

echo "### Configuring system services"
if [ $(systemctl is-active --quiet systemd-sysctl.service 2>/dev/null; echo $?) -eq 0 ] ; then
	echo "### systemd"
	cat <<EOF > /lib/systemd/system/ict.service
	[Unit]
	Description=IOTA ICT
	After=network.target
	[Service]
	ExecStart=/usr/bin/java -jar ${ICTHOME}/${ICTDIR}/ict/ict${VERSION}.jar -c ${ICTHOME}/config/ict.cfg ${ICTOPTIONS}
	WorkingDirectory=${ICTHOME}/${ICTDIR}
	StandardOutput=inherit
	StandardError=inherit
	Restart=always
	User=ict
	PIDFile=/var/run/ict.pid
	[Install]
	WantedBy=multi-user.target
EOF
	chmod u+x /lib/systemd/system/ict.service
	systemctl daemon-reload
	systemctl enable ict
	systemctl restart ict

	for ixi in $(ls /lib/systemd/system/ict_* | rev | cut -f1 -d"/" | rev) ; do 
		echo "### Removing old ${ixi}"
		systemctl stop ${ixi}
		systemctl disable
		rm -f /lib/systemd/system/${ixi}
	done

	systemctl daemon-reload

	journalctl -fu ict
	
elif [ -f /sbin/openrc-run ] ; then
	echo "### openrc"
	cat <<EOF > /etc/init.d/ict
#!/sbin/openrc-run

name="ict daemon"
description="IOTA ict node"
command="/usr/bin/java"
command_args="-jar ${ICTHOME}/${ICTDIR}/ict/ict${VERSION}.jar -c ${ICTHOME}/config/ict.cfg ${ICTOPTIONS}"
pidfile=/var/run/ict.pid

depend() {
  need net
  use logger dns
}

start() {
  ebegin "Starting ICT"
  start-stop-daemon --start -u ict -d ${ICTHOME}/${ICTDIR} \\
    -1 /var/log/ict.log \\
    --exec \${command} \\
    -b -m --pidfile \${pidfile} \\
    -- \${command_args}

  eend \$?
}

stop() {
  ebegin "Stopping ICT"
  start-stop-daemon --stop -u ict
  eend \$?
}
EOF
	
	chmod u+x /etc/init.d/ict
	
	grep "ict restart" /var/spool/cron/crontabs/root && sed -i 's/^.*ict restart.*$//' /var/spool/cron/crontabs/root
	grep "ict restart" /etc/crontab && sed -i 's/^.*ict restart.*$//' /etc/crontab
	
	rc-update add ict
	
	/etc/init.d/ict restart
	echo "### ict daemon installed, added to boot, and restarted"

	for ixi in $(ls /etc/init.d/ict_* | rev | cut -f1 -d"/" | rev) ; do 
		echo "### Removing old ${ixi} service"
		/etc/init.d/${ixi} stop
		rc-update del ${ixi}
		rm -f /etc/init.d/${ixi}
	done
	
	tail -f /var/log/ict.log

else
	echo "### NOT INSTALLED AS SERVICE. STARTING IN FORGROUND."
	cd ${ICTHOME}/${ICTDIR}
	${ICTHOME}/stop-ict.sh
	sudo --user=ict ${ICTHOME}/run-ict.sh & 
fi
