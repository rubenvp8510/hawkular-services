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
RUN yum install --quiet -y openssl && \
    rm -rf /var/cache/yum && \
    mkdir -p ${HAWKULAR_DATA} && \
    chown -RH jboss:jboss ${JBOSS_HOME}/{standalone,domain} ${HAWKULAR_DATA} $JAVA_HOME/jre/lib/security/cacerts && \
    chmod -R ugo+rw ${JBOSS_HOME}/{standalone,domain} ${HAWKULAR_DATA} $JAVA_HOME/jre/lib/security/cacerts

VOLUME ["${HAWKULAR_DATA}"]

USER jboss
CMD /opt/hawkular/bin/startcmd.sh
