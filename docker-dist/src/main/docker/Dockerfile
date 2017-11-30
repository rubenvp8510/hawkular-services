#
# Copyright 2016-2017 Red Hat, Inc. and/or its affiliates
# and other contributors as indicated by the @author tags.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

FROM jboss/wildfly:10.1.0.Final

MAINTAINER Hawkular Team, hawkular-dev@lists.jboss.org

ARG agent_enable
ARG metrics_ttl=21
ARG the_tag
ARG GOSU_VERSION=1.10

EXPOSE 8080 8443 8787

COPY maven /

ENV HAWKULAR_BACKEND=cassandra \
    HAWKULAR_PASSWORD=password \
    HAWKULAR_AGENT_ENABLE=${agent_enable} \
    CASSANDRA_NODES=myCassandra \
    HAWKULAR_USER=jdoe \
    HAWKULAR_USE_SSL=false \
    HAWKULAR_DATA=/var/opt/hawkular \
    HAWKULAR_METRICS_TTL=${metrics_ttl}\
    HAWKULAR_PUBLIC_KEY_FILENAME="/client-secrets/hawkular-services-public.pem" \
    HAWKULAR_PRIVATE_KEY_FILENAME="/client-secrets/hawkular-services-private.key" \
    HAWKULAR_KEYPAIR_FILENAME="/client-secrets/hawkular-services.pkcs12"

USER root
RUN set -ex; \
    yum install --quiet -y openssl;\
    rm -rf /var/cache/yum; \
    mkdir -p ${HAWKULAR_DATA}; \
    chown -RH jboss:jboss ${JBOSS_HOME}/{standalone,domain} ${HAWKULAR_DATA} $JAVA_HOME/jre/lib/security/cacerts; \
    chmod -R ugo+rw ${JBOSS_HOME}/{standalone,domain} ${HAWKULAR_DATA} $JAVA_HOME/jre/lib/security/cacerts; \
    yum -y install epel-release; \
    yum -y install wget dpkg; \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    wget -O /usr/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
    wget -O /tmp/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify /tmp/gosu.asc /usr/bin/gosu; \
    rm -r "$GNUPGHOME" /tmp/gosu.asc; \
    chmod +x /usr/bin/gosu; \
    gosu nobody true; \
    yum -y remove wget dpkg; \
    yum clean all

VOLUME ["${HAWKULAR_DATA}"]

CMD /opt/hawkular/bin/entrypoint.sh
