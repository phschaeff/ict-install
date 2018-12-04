FROM ubuntu:18.04
MAINTAINER Philippe Schaeffer <schaeff-docker@compuphil.de>

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install gnupg -y
RUN echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list
RUN echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" >> /etc/apt/sources.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886
RUN apt-get update
RUN apt-get upgrade -y
RUN echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
RUN echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
RUN apt-get install git oracle-java8-installer oracle-java8-set-default -y
RUN mkdir -p /opt/ict/config
WORKDIR /opt/ict
RUN cd /opt/ict && git clone https://github.com/Come-from-beyond/Ict.git 
WORKDIR /opt/ict/Ict
RUN javac /opt/ict/Ict/src/cfb/ict/*.java
COPY run-ict.sh /opt/ict/Ict/
COPY update-ict.sh /opt/ict/Ict/
RUN chmod a+x run-ict.sh update-ict.sh
COPY ict.properties /opt/ict/config/
VOLUME /opt/ict/config
EXPOSE 14265:14265/udp
ENTRYPOINT /opt/ict/Ict/run-ict.sh

##docker build -t iota:ict .
##docker run -v c:\temp\ict:/opt/ict/config -p 14265:14265/udp -i -t iota:ict


