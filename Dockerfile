FROM alpine:3.23.0

RUN apk add --no-cache \
	bash \
	ca-certificates \
	libsasl \
	mailx \
	sed \
  postfix \ 
	postfix-pgsql \
	rsyslog \
	rsyslog-pgsql \
	logrotate \
	runit

COPY service /etc/service
COPY runit_bootstrap /usr/sbin/runit_bootstrap
COPY rsyslog.conf /etc/rsyslog.conf

VOLUME /etc/logrotate.d
VOLUME /var/log
VOLUME /var/spool/postfix

STOPSIGNAL SIGKILL

ENTRYPOINT ["/usr/sbin/runit_bootstrap"]
