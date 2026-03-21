FROM alpine:3.23.3

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
	runit \
	tini

COPY service /etc/service
COPY runit_bootstrap /usr/sbin/runit_bootstrap
COPY rsyslog.conf /etc/rsyslog.conf
COPY master.cf /etc/postfix/master.cf
COPY logrotate.d /etc/logrotate.d

VOLUME /etc/logrotate.d
VOLUME /var/log
VOLUME /var/spool/postfix

STOPSIGNAL SIGTERM

ENTRYPOINT ["/sbin/tini", "--", "/usr/sbin/runit_bootstrap"]
