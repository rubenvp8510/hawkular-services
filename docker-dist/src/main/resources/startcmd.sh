#!/usr/bin/env bash
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

check_cassandra() {
  # Check that cassandra is available and responding
  if [ !  -z "${CASSANDRA_NODES}" ]; then
    echo " ## Using external storage nodes ##"
    export HAWKULAR_BACKEND=remote
  elif [ ! -z "${CASSANDRA_SERVICE}" ]; then
    echo " ## Using Kubernetes-style named service"
    eval "s=${CASSANDRA_SERVICE^^}_SERVICE_HOST"
    export CASSANDRA_NODES=${!s}
    HAWKULAR_BACKEND=remote
  fi

  echo "CASSANDRA_NODES='${CASSANDRA_NODES}'"

  if [ ! -z "${DB_TIMEOUT}" ]; then
    echo "Waiting for DB (timeout=${DB_TIMEOUT})"
    DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    timeout "${DB_TIMEOUT}" "${DIR}/check-cnode.sh" ${CASSANDRA_NODES}
    status=$?
    if [[ $status -eq 124 ]]; then
      echo "DB timed out"
      exit $?
    fi
    if [ ! $status ]; then
      exit 1
    fi
  fi
}

get_credentials() {
  # The username is obtained as a content of file '/client-secrets/hawkular-services.username'
  # if the file does not exist or is empty, the value of $HAWKULAR_USER is used
  # if the value of $HAWKULAR_USER is empty, it generates the username
  # The same precendence rules apply for the password.

  local _username_file="/client-secrets/hawkular-services.username"
  if [[ -f ${_username_file} ]] && [[ -s ${_username_file} ]]; then
    username=$(cat ${_username_file})
  else
    username=${HAWKULAR_USER:-"$(head /dev/urandom -c 512 | tr -dc A-Z-a-z-0-9 | head -c 16)"}
    [[ -z ${HAWKULAR_USER} ]] && username_generated="true"
  fi

  local _password_file="/client-secrets/hawkular-services.password"
  if [[ -f ${_password_file} ]] && [[ -s ${_password_file} ]]; then
    password=$(cat ${_password_file})
  else
    password=${HAWKULAR_PASSWORD:-"$(head /dev/urandom -c 512 | tr -dc A-Z-a-z-0-9 | head -c 16)"}
    [[ -z ${HAWKULAR_PASSWORD} ]] && password_generated="true"
  fi
}

create_user() {
  # we create only if there's users starting with ${username}
  grep "^${username}" "${JBOSS_HOME}/standalone/configuration/application-users.properties" > /dev/null
  RT_APP=$?
  # While using openshift, we couldn't access the management console without an username and password
  # Also checking the management users (see https://github.com/hawkular/hawkular-services/issues/172 )
  grep "^${username}" "${JBOSS_HOME}/standalone/configuration/mgmt-users.properties" > /dev/null
  RT_MGMT=$?

  if [[ ${RT_APP} -eq 0 ]] && [[ ${RT_MGMT} -eq 0 ]]; then
    echo "The '${username}' user has already been found."
  elif [[ ${RT_APP} -ne 1 ]] || [[ ${RT_MGMT} -ne 1 ]]; then
    echo "An error has been found when attempting to check if the '${username}' user exists. Aborting."
    exit 1
  else
    # we add the ${username} user to application and management
    RT=0
    if [[ ${RT_APP} -ne 0 ]]; then
      ${JBOSS_HOME}/bin/add-user.sh -a -u "${username}" -p "${password}" -g read-write,read-only -s
      RT=$?
    fi
    if [[ ${RT} -eq 0 ]] && [[ ${RT_MGMT} -ne 0 ]]; then
      ${JBOSS_HOME}/bin/add-user.sh -u "${username}" -p "${password}" -g read-write,read-only -s
      RT=$?
    fi

    [[ ${username_generated} != "true" ]] && [[ ${password_generated} != "true" ]] && return 0
    if [[ ${RT} -eq 0 ]]; then
      echo "------------------------------------"
      echo "ATTENTION ATTENTION ATTENTION ATTENTION"
      echo "We automatically created a user for you to access the Hawkular Services:"
      [[ ${username_generated} == "true" ]] && echo "Username: ${username}"
      [[ ${password_generated} == "true" ]] && echo "Password: ${password}"
      echo "------------------------------------"
    else
      echo "------------------------------------"
      echo "ATTENTION ATTENTION ATTENTION ATTENTION"
      echo "We attempted to create a user for you to access the Hawkular Services,"
      echo "but for some reason, we didn't succeed. You might need to enter the container manually"
      echo "and create one user as specified in the documentation."
      echo "------------------------------------"
    fi
  fi
}

run_hawkular_services() {
  ${JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0 \
         -bmanagement 0.0.0.0 \
         -Djboss.server.data.dir=${HAWKULAR_DATA:-/var/opt/hawkular}/data \
         -Djboss.server.log.dir=${HAWKULAR_DATA:-/var/opt/hawkular}/log \
         -Dactivemq.artemis.client.global.thread.pool.max.size=${HAWKULAR_JMS_THREAD_POOL:-30} \
         -Dhawkular.agent.enabled=${HAWKULAR_AGENT_ENABLE} \
         -Dhawkular.rest.host="https://127.0.0.1:8444" \
         -Dhawkular.log.agent=DEBUG \
         -Dhawkular.rest.user=${username} \
         -Dhawkular.rest.password=${password} \
         -Dhawkular.metrics.default-ttl=${HAWKULAR_METRICS_TTL:-14} \
         -Dhawkular.agent.machine.id=${HOSTNAME} -Djboss.server.name=${HOSTNAME} -Dhawkular.agent.in-container=true \
         -Dhawkular.rest.feedId=${HOSTNAME} -Dhawkular.agent.immutable=true \
         "$@"
}

main() {
  if [ "${HAWKULAR_AGENT_ENABLE}" != "true" ]; then
    HAWKULAR_AGENT_ENABLE="false"
  fi

  echo "Starting Hawkular Services"
  source $(dirname "$0")/cert_utils.sh
  get_credentials
  create_user
  add_certificate
  check_cassandra
  run_hawkular_services "$@"
}

main "$@"
