# vim:set ft=dockerfile:
# This Dockerfile is a generalised version for building most versions of Postgres
# server from its source. 
#
# Building of the image can be done by simply specifying the version you want to
# pull down and build.
FROM alpine:3.8

ARG PG_MAJOR=8.4
ARG PG_VERSION=8.4.20

# alpine includes "postgres" user/group in base install
#   /etc/passwd:22:postgres:x:70:70::/var/lib/postgresql:/bin/sh
#   /etc/group:34:postgres:x:70:
# the home directory for the postgres user, however, is not created by default
# see https://github.com/docker-library/postgres/issues/274
RUN postgresHome="$(getent passwd postgres)"; \
	postgresHome="$(echo "$postgresHome" | cut -d: -f6)"; \
	[ "$postgresHome" = '/var/lib/postgresql' ]; \
	mkdir -p "$postgresHome"; \
	chown -R postgres:postgres "$postgresHome"

# su-exec (gosu-compatible) is installed further down
# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
# alpine doesn't require explicit locale-file generation
ENV LANG en_US.utf8
RUN mkdir /docker-entrypoint-initdb.d
ENV OSSP_UUID_VERSION 1.6.2

RUN apk add --no-cache ca-certificates openssl tar \
    bison coreutils alpine-sdk dpkg-dev dpkg flex libedit-dev \
    libxml2-dev libxslt-dev openssl-dev perl-utils perl-ipc-run util-linux-dev \
    zlib-dev

RUN wget -O postgresql.tar.bz2 "https://ftp.postgresql.org/pub/source/v$PG_VERSION/postgresql-$PG_VERSION.tar.bz2" 
RUN mkdir -p /usr/src/postgresql 
RUN tar \
    --extract \
	--file postgresql.tar.bz2 \
	--directory /usr/src/postgresql \
	--strip-components 1
RUN rm postgresql.tar.bz2 

# install OSSP uuid (http://www.ossp.org/pkg/lib/uuid/)
# see https://github.com/docker-library/postgres/pull/255 for more details
RUN wget -O uuid.tar.gz "https://www.mirrorservice.org/sites/ftp.ossp.org/pkg/lib/uuid/uuid-$OSSP_UUID_VERSION.tar.gz" 
RUN mkdir -p /usr/src/ossp-uuid
RUN tar --extract --file uuid.tar.gz --directory /usr/src/ossp-uuid --strip-components 1
RUN rm uuid.tar.gz
WORKDIR /usr/src/ossp-uuid
RUN gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    # explicitly update autoconf config.guess and config.sub so they support more arches/libcs
    && wget -O config.guess 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess?id=7d3d27baf8107b630586c962c057e22149653deb' \
    && wget -O config.sub 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub?id=7d3d27baf8107b630586c962c057e22149653deb' \
    && ./configure \
        --build="$gnuArch" \
        --prefix=/usr/local \
    && make \
    && make install

RUN rm -rf /usr/src/ossp-uuid

WORKDIR /usr/src/postgresql
RUN awk '$1 == "#define" && $2 == "DEFAULT_PGSOCKET_DIR" && $3 == "\"/tmp\"" { $3 = "\"/var/run/postgresql\""; print; next } { print }' src/include/pg_config_manual.h > src/include/pg_config_manual.h.new
RUN grep '/var/run/postgresql' src/include/pg_config_manual.h.new 
RUN mv src/include/pg_config_manual.h.new src/include/pg_config_manual.h 
RUN gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" 
    # explicitly update autoconf config.guess and config.sub so they support more arches/libcs
RUN wget -O config/config.guess 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess?id=7d3d27baf8107b630586c962c057e22149653deb'
RUN wget -O config/config.sub 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub?id=7d3d27baf8107b630586c962c057e22149653deb'
    # configure options taken from:
    # https://anonscm.debian.org/cgit/pkg-postgresql/postgresql.git/tree/debian/rules?h=9.5
RUN sh ./configure \
	--build="$gnuArch" \
	--enable-integer-datetimes \
	--enable-thread-safety \
	--disable-rpath \
	--with-ossp-uuid \
	--with-gnu-ld \
	--with-pgport=5432 \
	--with-system-tzdata=/usr/share/zoneinfo \
	--prefix=/usr/local \
	--with-includes=/usr/local/include \
	--with-libraries=/usr/local/lib \
	--with-openssl \
	--with-libxml \
	--with-libxslt

# Make and install
RUN make && make install && make -C contrib install \
	&& runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"

# Install extra dependancies
RUN apk add --no-cache --virtual .postgresql-rundeps \
	$runDeps \
	bash \
	su-exec \
	tzdata

RUN rm -rf \
	/usr/src/postgresql \
	/usr/local/share/doc \
	/usr/local/share/man
RUN find /usr/local -name '*.a' -delete

# Make the sample config easier to munge (and "correct by default")
RUN sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/local/share/postgresql/postgresql.conf.sample
RUN mkdir -p /var/run/postgresql
RUN chown -R postgres:postgres /var/run/postgresql 
RUN chmod 2777 /var/run/postgresql

ENV PGDATA /var/lib/postgresql/data
RUN mkdir -p "$PGDATA" 
RUN chown -R postgres:postgres "$PGDATA"

# this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
RUN chmod 777 "$PGDATA" 
VOLUME /var/lib/postgresql/data

WORKDIR /root/
COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]