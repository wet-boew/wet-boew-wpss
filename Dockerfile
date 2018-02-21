FROM java:8-jre-alpine
MAINTAINER Joseph Olstad <j@7pro.ca>

#ENV CRAWLFILE mycrawlfile
ENV CRAWLFILE=jolstad_bas \
         PATH="/opt/wpss:/opt/wpss/bin:${PATH}"

WORKDIR /opt/wpss
# WPSS_Tool_6.8.0 is a dependency, you can get this from the installation folder of the WPSS tool , however I am looking for another way to get this without having to install on windows.
ADD WPSS_Tool_6.8.0 /opt/wpss/
ADD create_crawl_file_for_wpss.sh /opt/wpss
ADD crawl /opt/wpss/crawl

#ALPINE STUFF HERE, DISABLED
RUN apk update
RUN apk add --update perl
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

RUN mkdir /opt/wpss/wpss_scan_results
RUN chmod 777 /opt/wpss/wpss_scan_results -R

RUN /opt/wpss/install.pl
 && rm -rf /var/cache/apk/*

#ENTRYPOINT ["/opt/wpss/wpss_tool_cli.pl","-c"]

#CMD ["/opt/wpss/crawl/${CRAWLFILE}"]
CMD ["/bin/sh"]
