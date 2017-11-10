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

KEYSTORE_HOME="${JBOSS_HOME}/standalone/configuration"

# creates the empty ${KEYSTORE_HOME}/hawkular.keystore file
create_empty_keystore() {
  keytool -genkeypair -keyalg RSA -alias dummy -dname "CN=localhost" -keypass hawkular -storepass hawkular \
    -keystore ${KEYSTORE_HOME}/hawkular.keystore
  keytool -delete -alias dummy -storepass hawkular -keystore ${KEYSTORE_HOME}/hawkular.keystore
}

# add the certificate from the ${KEYSTORE_HOME}/hawkular.keystore file as trusted
add_cert_as_trusted() {
  # export the public key from the keystore
  keytool -export -alias hawkular -file ${KEYSTORE_HOME}/hawkular.cert -storepass hawkular \
    -keystore ${KEYSTORE_HOME}/hawkular.keystore

  # and import it as a trusted certificate for the current JDK
  keytool -import -keystore $JAVA_HOME/jre/lib/security/cacerts -alias hawkular -storepass changeit \
    -file ${KEYSTORE_HOME}/hawkular.cert -noprompt
  rm ${KEYSTORE_HOME}/hawkular.cert
}

# add the security realm, HTTPS listener and turn SSL for agent
use_standalone_ssl_config() {
  cp ${JBOSS_HOME}/standalone/configuration/standalone.xml ${JBOSS_HOME}/standalone/configuration/standalone-orig.xml
  cp ${JBOSS_HOME}/standalone/configuration/standalone-ssl.xml ${JBOSS_HOME}/standalone/configuration/standalone.xml
  cp ${JBOSS_HOME}/standalone/configuration/hawkular-javaagent-config.yaml ${JBOSS_HOME}/standalone/configuration/hawkular-javaagent-config-orig.yaml
  cp ${JBOSS_HOME}/standalone/configuration/hawkular-javaagent-config-ssl.yaml ${JBOSS_HOME}/standalone/configuration/hawkular-javaagent-config.yaml
}

add_certificate() {
  if [[ ${HAWKULAR_USE_SSL} = "true" ]]; then
    local _public_key=${HAWKULAR_PUBLIC_KEY_FILENAME}
    local _private_key=${HAWKULAR_PRIVATE_KEY_FILENAME}
    local _keypair=${HAWKULAR_KEYPAIR_FILENAME}

    if [[ -f ${_private_key} ]] && [[ -s ${_private_key} ]] && \
       [[ -f ${_public_key} ]] && [[ -s ${_public_key} ]]; then
      # private key and certificate given in pem format

      create_empty_keystore

      # convert the external key pair into pkcs12 file
      openssl pkcs12 -export -out ${KEYSTORE_HOME}/hawkular.pkcs12 -in ${_public_key} -inkey ${_private_key} \
        -passout pass: -name hawkular

      # import the pkcs12 file to the keystore
      keytool -importkeystore -srckeystore ${KEYSTORE_HOME}/hawkular.pkcs12 -srcalias hawkular -srcstorepass "" \
        -srcstoretype PKCS12 -destkeystore ${KEYSTORE_HOME}/hawkular.keystore -deststoretype JKS -destalias hawkular \
        -deststorepass hawkular -destkeypass hawkular -noprompt
      rm ${KEYSTORE_HOME}/hawkular.pkcs12

      # import the external certificate in pem as a trusted certificate for the current JDK
      keytool -import -keystore $JAVA_HOME/jre/lib/security/cacerts -alias hawkular -storepass changeit \
        -file ${_public_key} -noprompt
    elif [[ -f ${_keypair} ]] && [[ -s ${_keypair} ]]; then
      # pkcs12 case (no password is assumed)

      create_empty_keystore

      # import the pkcs12 file to the keystore
      keytool -importkeystore -srckeystore ${_keypair} -srcalias hawkular -srcstorepass "" -srcstoretype PKCS12 \
        -destkeystore ${KEYSTORE_HOME}/hawkular.keystore -deststoretype JKS -destalias hawkular \
        -deststorepass hawkular -destkeypass hawkular -noprompt

      add_cert_as_trusted
    else
      # generate the keystore and the key pair in it
      echo "------------------------------------"
      echo "Generating the self-signed certificate"
      local _dname=${HAWKULAR_HOSTNAME:-${HOSTNAME:-"localhost"}}
      keytool -genkeypair -keystore ${KEYSTORE_HOME}/hawkular.keystore -alias hawkular \
        -dname "CN=${_dname}" -keyalg RSA -keysize 4096 -storepass hawkular \
        -keypass hawkular -validity 3650 -ext san=ip:127.0.0.1

      keytool -list -keystore ${KEYSTORE_HOME}/hawkular.keystore -storepass hawkular | grep fingerprint
      echo "------------------------------------"

      add_cert_as_trusted
    fi
    use_standalone_ssl_config
  fi
}
