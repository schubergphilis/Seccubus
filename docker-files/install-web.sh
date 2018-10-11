#!/bin/sh
# Copyright 2018 Frank Breedijk
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -x
set -e

# Install prerequisites
apk update
# Basics
APKS="tzdata make bash perl logrotate"
# Web server
APKS="$APKS openssl nginx"
# Perl modules
APKS="$APKS perl-dbd-mysql perl-dbi perl-date-format perl-html-parser perl-json perl-libwww perl-lwp-protocol-https
    perl-net-ip perl-term-readkey perl-xml-simple perl-app-cpanminus perl-mojolicious perl-algorithm-diff
    perl-module-build perl-namespace-autoclean perl-moo perl-strictures perl-test-fatal perl-digest-hmac
    perl-type-tiny linux-headers perl-dev perl-app-cpanminus wget gcc libc-dev"

# Install
apk add $APKS

# Perl modules
cpanm Digest::SHA3
cpanm Crypt::PBKDF2

# Extract tarbal
cd /build/seccubus
tar -xvzf build/Seccubus*.tar.gz
cd Seccubus-*

# Make sure perl is set to the correct path
perl Makefile.PL
make clean
perl Makefile.PL 2>&1| tee makefile.log

# Check if we have all perl dependancies
if [[ $(grep "Warning: prerequisite" makefile.log| grep -v 'Perl::Critic' |wc -l) -gt 0 ]]; then
    echo '*** ERROR: Not all perl dependancies installed ***'
    cat makefile.log
    exit 255
fi
# create user
mkdir -p /opt/seccubus
addgroup seccubus
adduser -h /opt/seccubus -g "Seccubus system user" -s /bin/bash -S -D -G seccubus seccubus
addgroup seccubus wheel

chown -R seccubus:seccubus /opt/seccubus
chmod 755 /opt/seccubus

# Install the software
./install.pl --basedir /opt/seccubus /opt/seccubus/www --stage_dir /build/stage --createdirs --owner seccubus -v -v

# Create mountpoint for data directory
mkdir /opt/seccubus/data
chmod 755 /opt/seccubus/data
chown seccubus:seccubus /opt/seccubus/data
chmod 755 /opt/seccubus

mkdir /var/log/seccubus
chmod 755 /var/log/seccubus
chown seccubus:seccubus /var/log/seccubus

# Set up some default content
SESSION_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
echo $SESSION_KEY > /opt/seccubus/etc/SESSION_KEY
cat <<EOF2 >/opt/seccubus/etc/config.xml
<seccubus>
    <database>
        <engine>mysql</engine>
        <database>seccubus</database>
        <host>127.0.0.1</host>
        <port>3306</port>
        <user>seccubus</user>
        <password>seccubus</password>
    </database>
    <paths>
        <modules>/opt/seccubus/lib</modules>
        <scanners>/opt/seccubus/scanners</scanners>
        <bindir>/opt/seccubus/bin</bindir>
        <configdir>/opt/seccubus/etc</configdir>
        <dbdir>/opt/seccubus/db</dbdir>
    </paths>
    <smtp>
        <server></server>
        <from></from>
    </smtp>
    <tickets>
        <url_head></url_head>
        <url_tail></url_tail>
    </tickets>
    <auth>
        <http_auth_header></http_auth_header>
        <sessionkey>$SESSION_KEY</sessionkey>
    </auth>
    <http>
        <port>443</port>
        <cert>testdata/seccubus.crt</cert>
        <key>testdata/seccubus.key</key>
    </http>
</seccubus>
EOF2

# Setup default environment
echo >/etc/profile.d/seccubus.sh 'export PATH="$PATH:/opt/seccubus/bin"'
echo >>/etc/profile.d/seccubus.sh 'export PERL5LIB="/opt/seccubus:/opt/seccubus/lib"'
chmod +x /etc/profile.d/seccubus.sh
echo >/root/.bashrc 'export PATH="$PATH:/opt/seccubus/bin"'
echo >>/root/.bashrc 'export PERL5LIB="/opt/seccubus:/opt/seccubus/lib"'

# Clone bashrc
cp ~/.bashrc ~seccubus/.bashrc
chown seccubus:seccubus ~seccubus/.bashrc

# Cleanup build stuff
set +e
rm -rf /build


