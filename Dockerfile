FROM maven:3-jdk-6

ENV PROXY_HOST=localhost \
    PROXY_PORT=3128

RUN set -eux; \
  ( \
  echo "deb http://archive.debian.org/debian wheezy main" > /etc/apt/sources.list; \
  echo "deb http://archive.debian.org/debian-security wheezy/updates main" >> /etc/apt/sources.list; \
  ); \
  apt-get -o Acquire::Check-Valid-Until=false update \
  && apt-get install -y zip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY conf/settings.xml /usr/share/maven/conf/settings.xml

COPY proxy/conf/squid_myCA.crt .

RUN keytool -importcert -noprompt -alias repo.maven.apache.org \
  -keystore /usr/lib/jvm/java-6-openjdk-amd64/jre/lib/security/cacerts \
  -storepass changeit -file ./squid_myCA.crt
