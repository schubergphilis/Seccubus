#
# Copyright 2011-2019 Peter Slootweg, Frank Breedijk, Glenn ten Cate
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

# OS detection

# Seccubus
%define installdir  /opt/seccubus
%define homedir     %{installdir}
%define bindir      %{installdir}/bin
%define confdir     /etc/seccubus
%define vardir      %{installdir}/var
%define seccuser    seccubus
%define docsdir     %{installdir}/doc/
%define logdir      /var/log/seccubus

%define moddir      %{installdir}/lib
%define scandir     %{installdir}/scanners

Name:       seccubus
Version:    master
Release:    0
Summary:    Automated regular vulnerability scanning with delta reporting
Group:      Applications/Internet
License:    ASL 2.0
URL:        http://www.seccubus.com

Packager:   Frank Breedijk <fbreedijk@schubergphilis.com>

BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:  noarch

Source0:    %{name}-%{version}.tar.gz

BuildRequires:  java-1.8.0-openjdk-headless
BuildRequires:  perl(ExtUtils::MakeMaker)
%if 0%{?fedora}
    # Nothing
%else
BuildRequires:  perl-CPAN
BuildRequires:  perl-devel
BuildRequires:  curl
BuildRequires:  perl(Test::Simple)
%endif

Requires:   perl(Algorithm::Diff)
Requires:   perl(DBI)
Requires:   perl(DBD::mysql)
Requires:   perl(JSON)
Requires:   perl(XML::Simple)
Requires:   perl-libwww-perl
Requires:   perl(LWP::Simple)
Requires:   perl(LWP::Protocol::https)
Requires:   perl(Net::IP)
Requires:   perl(Date::Format)
Requires:   perl(Exporter)
Requires:   perl(Getopt::Long)
Requires:   perl(Data::Dumper)
Requires:   perl(HTML::Entities)
Requires:   perl(MIME::Base64)
Requires:   perl(File::Basename)
Requires:   perl(Socket)
Requires:   perl(Net::SMTP)
Requires:   perl(Crypt::PBKDF2)
Requires:   perl(Term::ReadKey)
Requires:   perl(Time::HiRes)
Requires:   perl(Sys::Syslog)
Requires:   perl(Mojolicious) >= 6.0
Requires:   openssl

Requires:   mysql
%{?el6:Requires: mysql-server}
%{?el7:Requires: mariadb-server}
%{?fedora:Requires: mariadb-server}

# Mangle rpm output name
#%{?el7:%define _rpmfilename %%{ARCH}/%%{NAME}-%%{VERSION}-%%{RELEASE}.el7.%%{ARCH}.rpm}
#%{?fedora:%define _build_name_fmt %%{ARCH}/%%{NAME}-%%{VERSION}-%%{RELEASE}%{dist}.%%{ARCH}.rpm}

%description
Tool to automatically fire regular vulnerability scans with Nessus, OpenVAS,
Nikto or Nmap.
Compare results of the current scan with the previous scan and report on the
delta in a web interface. Main objective of the tool is to make repeated scans
more efficient.
Nmap scanning needs the Nmap scanner
Nikto scanning needs the Nikto scanner

See http://www.seccubus.com for more information

%clean
[ %{buildroot} != "/" ] && %{__rm} -rf %{buildroot}

%prep
%setup -q -n %{name}-%{version}

%build
./build_all

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{homedir}
cd build
./install.pl --buildroot=%{buildroot} --confdir=%{confdir} --bindir=%{bindir} --dbdir=%{vardir} --basedir=%{homedir} --docdir=%{docsdir}

mkdir -p %{buildroot}%{logdir}

cp ChangeLog.md LICENSE.txt NOTICE.txt README.md %{buildroot}/%{docsdir}

cat > %{buildroot}/%{confdir}/config.xml <<- EOF
<?xml version="1.0" standalone='yes'?>
<seccubus>
    <database>
        <engine>mysql</engine>
        <database>seccubus</database>
        <host>localhost</host>
        <port>3306</port>
        <user>%{seccuser}</user>
        <password>%{seccuser}</password>
    </database>
    <paths>
        <modules>%{installdir}/lib</modules>
        <scanners>%{scandir}</scanners>
        <bindir>%{bindir}</bindir>
        <configdir>%{confdir}</configdir>
        <dbdir>%{vardir}</dbdir>
        <logdir>/var/log/seccubus</logdir>
    </paths>
    <smtp>
        <server>localhost</server>
        <from>seccubus@localhost</from>
    </smtp>
    <tickets>
        <url_head></url_head>
        <url_tail></url_tail>
    </tickets>
    <auth>
        <http_auth_header></http_auth_header>
        <sessionkey>SeccubusScanSmarterNotHarder</sessionkey>
        <baseurl></baseurl>
    </auth>
    <http>
        <port>8443</port>
        <cert>%{confdir}/seccubus.crt</cert>
        <key>%{confdir}/seccubus.key</key>
        <baseurl></baseurl>
    </http>
</seccubus>

EOF


################################################################################
%pre

%if 0%{?fedora}
%{_sbindir}/groupadd -r -f %{seccuser}
%else
%{_sbindir}/groupadd -r -f seccubus
%endif

grep \^%{seccuser} /etc/passwd >/dev/null
if [ $? -ne 0 ]; then
    %{_sbindir}/useradd -d %{installdir} -g %{seccuser} -r %{seccuser}
fi

## %pre
%post

if [[ ! -e /etc/seccubus/seccubus.key && ! -e /etc/seccubus/seccubus.crt ]] ; then
    openssl genrsa -des3 -passout pass:seccubus12345 -out /etc/seccubus/seccubus.pass.key 4096
    openssl rsa -passin pass:seccubus12345 -in /etc/seccubus/seccubus.pass.key -out /etc/seccubus/seccubus.key
    rm -f /etc/seccubus/seccubus.pass.key
    openssl req -new -key /etc/seccubus/seccubus.key -out /etc/seccubus/seccubus.csr \
        -subj "/CN=Seccubus"
    openssl x509 -req -days 365 -in /etc/seccubus/seccubus.csr \
        -signkey /etc/seccubus/seccubus.key -out /etc/seccubus/seccubus.crt
    rm -f /etc/seccubus/seccubus.csr

fi

/bin/cat << OEF
################################################################################

After installation, create a database and database user. Populate the db with provided
scripts:

  # mysql << EOF
  create database seccubus;
  grant all privileges on seccubus.* to seccubus@localhost identified by 'seccubus';
  flush privileges;
  EOF

  # mysql -u seccubus -pseccubus seccubus < %{vardir}/structure_v10.mysql
  # mysql -u seccubus -pseccubus seccubus < %{vardir}/data_v10.mysql

You can change the db name and username/password, make sure you update
%{confdir}/config.xml accordingly

Look for more information on http://www.seccubus.com/documentation/

Seccubus is listening on https://localhost:8443/

################################################################################
OEF

%if 0%{?fedora}
%define hypnopath  /bin
%else
%define hypnopath  /usr/local/bin
%endif

cat >/lib/systemd/system/seccubus.service <<EOF
[Unit]
Description=Seccubus - Scan Smarter not Harder
After=network.target

[Service]
Type=simple
Restart=always
PIDFile=/opt/seccubus/hypnotaod.pid
ExecStart=%{hypnopath}/hypnotoad /opt/seccubus/seccubus.pl -f
ExecStop=%{hypnopath}/hypnotoad -s /opt/seccubus/seccubus.pl
ExecReload=%{hypnopath}/hypnotoad /opt/seccubus/seccubus.pl
WorkingDirectory=/opt/seccubus

[Install]
WantedBy=multi-user.target
EOF

systemctl --system daemon-reload
/bin/systemctl enable seccubus.service
/bin/systemctl start  seccubus.service

## %post

%postun
chkconfig --remove seccubus
rm -f /etc/init.d/seccubus
## %postun

################################################################################
%files
%defattr(640,%{seccuser},%{seccuser},750)
#
%config(noreplace) %{confdir}
#
%{installdir}
#
%{moddir}
#
%{bindir}
%attr(750,%{seccuser},%{seccuser}) %{bindir}/*
#
%docdir %{docsdir}
#
%{scandir}
%attr(750,%{seccuser},%{seccuser}) %{scandir}/*/scan
#
%{logdir}
%attr(750,%{seccuser},%{seccuser}) %{logdir}
#
%attr(750,%{seccuser},%{seccuser}) %{vardir}/create*
#

%changelog
* Wed Jan 30 2019 Frank Breedijk <fbreedijk@schubergphilis.com>
- Added openssl as a dependancy
* Tue Jan 23 2018 Frank Breedijk <fbreedijk@schubergphilis.com>
- Fixed error in system.d startup files
* Fri Dec  8 2017 Frank Breedijk <fbreedijk@schubergphilis.com>
- Re-added support for RedHat/CentOs 7
* Wed Jun  7 2017 Frank Breedijk <fbreedijk@schubergphilis.com>
- New Mojolicious backend
- Dropped suport of Centos5 and RedHat5
* Tue Apr 18 2017 Frank Breedijk <fbreedijk@schubergphilis.com>
- Added the dist tag to the rpm filename
* Mon May 2 2016 Frank Breedijk <fbreedijk@schubergphilis.com>
- RPM now builds on RHEL5 and CentOS5 too.
- Removed RPM lint warnings
- Removed old scanners
* Fri Mar 25 2016 Frank Breedijk <fbreedijk@schubergphilis.com>
- Removed dependancy on MakeMaker
- Better handling of file permissions
* Fri Dec 5 2014 Frank Breedijk <fbreedijk@schubergphilis.com>
- Added dependancies for Nessus6 interface and Assets
* Tue Sep 23 2014 Frank Breedijk <fbreedijk@schubergphilis.com>
- Making it a lot simpler
* Mon Aug 18 2014 Frank Breedijk <fbreedijk@schubergphilis.com>
- Fixed SE Linux isseu thanks to Arkenoi
- Added support for Qualys SSLlabs
* Fri Aug 1 2014 Glenn ten Cate <gtencate@schubergphilis.com>
- New scanner Medusa added by Arkanoi
- Burp parser by SphaZ
* Tue Mar 19 2013 Frank Breedijk <fbreedijk@schubergphilis.com>
- New DB version
* Mon Dec 24 2012 Frank Breedijk <fbreedijk@schubergphilis.com>
- Fixed permissions of files in % { webdir } /seccubus/json/updateWorkspace.pl
* Fri Oct 05 2012 Frank Breedijk <fbreedijk@schubergphilis.com>
- Building the rpm is now part of an automated build process. Unless there
  are any changes to this file in the Git repository changes will not be
  recorded here
* Wed Aug 15 2012 Frank Breedijk <fbreedijk@schubergphilis.com>
- Corrected major error in beta4
* Tue Jul 10 2012 Frank Breedijk <fbreedijk@schubergphilis.com>
- Corrected performance and installation issues
- Version 2.0.beta4
* Fri Feb 24 2012 Frank Breedijk <fbreedijk@schubergphilis.com>
- Removed oldstyle gui
* Fri Jan 27 2012 Frank Breedijk <fbreedijk@schubergphilis.com>
- Version 2.0.beta2
* Sat Jan 07 2012 Frank Breedijk <fbreedijk@schubergphilis.com>
- Moved old GUi to oldstyle
- New GUI is now main GUI
- Version 2.0.beta1
* Wed Nov 23 2011 Frank Breedijk <fbreedijk@schubergphilis.com>
- Added support for rebuilt GUI
- Removed quadruplicate docs/HTML reference
* Fri Nov 18 2011 Frank Breedijk <fbreedijk@schubergphilis.com>
- Fixed missing dependancies
* Thu Nov 17 2011 Frank Breedijk <fbreedijk@schubergphilis.com>
- Permissions of scanner files are not correct
* Tue Sep 13 2011 Frank Breedijk <fbreedijk@schubergphilis.com>
- version 2.0.alpha4
* Thu Aug 25 2011 Peter Slootweg <peter@pxmedia.nl>
- version 2.0.alpha3
* Mon May 2 2011 Peter Slootweg <pslootweg@schubergphilis.com>
- version 2.0.alpha2
* Mon Mar 14 2011 Peter Slootweg <pslootweg@schubergphilis.com>
- version 2.0.alpha1
* Thu Feb 10 2011 Peter Slootweg <pslootweg@schubergphilis.com>
- version 2.0.alpha0
* Thu Feb 10 2011 Peter Slootweg <pslootweg@schubergphilis.com>
- version 1.5.4
* Tue Nov 9 2010 Peter Slootweg <pslootweg@schubergphilis.com>
- version 1.5.3
* Mon Sep 6 2010 Peter Slootweg <pslootweg@schubergphilis.com>
- homedir wasn't owned by seccubus user
* Wed Sep 1 2010 Peter Slootweg <pslootweg@schubergphilis.com>
- removed dependencies on nessus and mod_perl
* Mon Aug 30 2010 Peter Slootweg <pslootweg@schubergphilis.com>
- Removed last remaining /home/seccubus references
* Tue Jun 22 2010 Peter Slootweg <pslootweg@schubergphilis.com>
- Initial Spec File
