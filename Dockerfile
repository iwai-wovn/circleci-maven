FROM maven:3-jdk-6

ENV DEBIAN_FRONTEND=noninteractive \
    SQUID_VERSION=3.1.20

WORKDIR /root

# patch for certificate_db.cc:48:17: error: 'close' was not declared in this scope
COPY certificate_db.cc_error_close_was_not_declared_in_this_scope.patch /root/

RUN set -eux; \
  ( \
  echo "deb http://archive.debian.org/debian wheezy main" > /etc/apt/sources.list; \
  echo "deb http://archive.debian.org/debian-security wheezy/updates main" >> /etc/apt/sources.list; \
  echo "deb-src http://archive.debian.org/debian wheezy main" >> /etc/apt/sources.list \
  ); \
  apt-get -o Acquire::Check-Valid-Until=false update \
  && apt-get install -y dpkg-dev \
  && apt-get install -y debian-keyring \
  && gpg --keyserver hkp://keyserver.ubuntu.com --recv 1343CF44 \
  && gpg --no-default-keyring -a --export 1343CF44 | gpg --no-default-keyring --keyring ~/.gnupg/trustedkeys.gpg --import - \
  && apt-get source squid3 \
  && apt-get -o APT::Get::AllowUnauthenticated=true build-dep -y squid3 \
  && apt-get -o APT::Get::AllowUnauthenticated=true -y install devscripts build-essential fakeroot \
  && apt-get -o APT::Get::AllowUnauthenticated=true install -y openssl libssl-dev \
  && cd squid3-${SQUID_VERSION} \
  && sed -i -e '39a \                --with-openssl \\' debian/rules \
  && sed -i -e '39a \                --enable-ssl-crtd \\' debian/rules \
  && sed -i -e '39a \                --enable-ssl \\' debian/rules \
  && (patch -p0 < ../certificate_db.cc_error_close_was_not_declared_in_this_scope.patch) \
  && ./configure \
  && debuild -us -uc -b

FROM maven:3-jdk-6

ENV JAVA_HOME=/usr/lib/jvm/java-6-openjdk-amd64 \
    SQUID_VERSION=3.5.27 \
    SQUID_CACHE_DIR=/var/spool/squid3 \
    SQUID_LOG_DIR=/var/log/squid3 \
    SQUID_USER=proxy

WORKDIR /root

COPY --from=0 /root/squid*.deb /root/

RUN set -eux; \
  ( \
  echo "deb http://archive.debian.org/debian wheezy main" > /etc/apt/sources.list; \
  echo "deb http://archive.debian.org/debian-security wheezy/updates main" >> /etc/apt/sources.list; \
  echo "deb-src http://archive.debian.org/debian wheezy main" >> /etc/apt/sources.list \
  ); \
  apt-get -o Acquire::Check-Valid-Until=false update \
  && apt-get install -y openssl libltdl7 logrotate squid-langpack \
  && rm squid-cgi_3.1.20-2.2+deb7u4_amd64.deb \
  && dpkg -i ./squid*.deb \
  && /usr/lib/squid3/ssl_crtd -c -s /var/lib/ssl_db

COPY conf/* /root/

RUN mv /root/squid.conf /etc/squid3/squid.conf \
  && mv /root/squid_myCA.pem /etc/squid3/squid_myCA.pem \
  && mv /root/settings.xml /usr/share/maven/conf/settings.xml \
  && keytool -importcert -noprompt -alias repo.maven.apache.org \
       -keystore ${JAVA_HOME}/jre/lib/security/cacerts \
       -storepass changeit -file squid_myCA.crt \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /sbin/entrypoint.sh

ENTRYPOINT ["/sbin/entrypoint.sh"]

CMD ["mvn"]
