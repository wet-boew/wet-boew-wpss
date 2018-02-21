FROM java:8-jre-alpine
MAINTAINER Joseph Olstad <j@7pro.ca>

#ENV CRAWLFILE mycrawlfile
ENV CRAWLFILE=jolstad_bas \
         PATH="/opt/wpss:/opt/wpss/bin:${PATH}"

WORKDIR /opt/wpss
ADD WPSS_Tool_6.8.0 /opt/wpss/
ADD create_crawl_file_for_wpss.sh /opt/wpss
ADD crawl /opt/wpss/crawl

#ALPINE STUFF HERE, DISABLED
RUN apk update
RUN apk add --update perl
# && rm -rf /var/cache/apk/*
RUN apk add perl-archive-zip perl-xml-parser perl-json perl-net-ssleay zip unzip python perl-cgi make gcc g++ curl perl-dev bash
RUN curl -L http://xrl.us/cpanm > /bin/cpanm && chmod +x /bin/cpanm

RUN mkdir /opt/common
RUN mkdir /opt/common/perl
RUN mkdir /opt/common/perl/bin
RUN ln -s /usr/bin/perl /opt/common/perl/bin/perl
RUN cpanm HTML::Form
RUN cpanm IO::Socket::SSL
RUN cpanm Term::ReadKey
RUN cpanm LWP::Protocol::https

#RUN DEBIAN_FRONTEND=noninteractive apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install libarchive-zip-perl libxml-parser-perl libjson-perl libcrypt-ssleay-perl python python-pip python-jsonschema libterm-readkey-perl
#RUN DEBIAN_FRONTEND=noninteractive apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install libarchive-zip-perl libxml-parser-perl libjson-perl libcrypt-ssleay-perl openjdk-8-jdk python
#RUN apt-get -y install software-properties-common python-software-properties
#RUN apt-add-repository ppa:webupd8team/java
#RUN DEBIAN_FRONTEND=noninteractive apt-get -y update
#RUN echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
#RUN echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
#RUN apt-get -y install oracle-java8-installer

RUN mkdir /opt/wpss/wpss_scan_results
RUN chmod 777 /opt/wpss/wpss_scan_results -R

#openjdk-8-jre-headless
#oracle-java8-installer

RUN /opt/wpss/install.pl

#ENTRYPOINT ["/opt/wpss/wpss_tool_cli.pl","-c"]

#CMD ["/opt/wpss/crawl/${CRAWLFILE}"]
CMD ["/bin/sh"]
