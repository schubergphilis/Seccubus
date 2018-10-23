#!/usr/bin/env perl
# Copyright 2017-2018 Frank Breedijk
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
use Mojo::Base -strict;

use strict;

use Test::More;
use Test::Mojo;
use Data::Dumper;

use lib "lib";

my $db_version = 0;
foreach my $data_file (glob "db/data_v*.mysql") {
	$data_file =~ /^db\/data_v(\d+)\.mysql$/;
	$db_version = $1 if $1 > $db_version;
}

ok($db_version > 0, "DB version = $db_version");
`mysql -h 127.0.0.1 -u root -e "drop database seccubus"`;
is($?,0,"Command executed ok");
`mysql -h 127.0.0.1 -u root -e "create database seccubus"`;
is($?,0,"Command executed ok");
`mysql -h 127.0.0.1 -u root -e "create user if not exists 'seccubus'\@'localhost' identified by 'seccubus'"`;
is($?,0,"Command executed ok");
`mysql -h 127.0.0.1 -u root -e "grant all privileges on seccubus.* to seccubus\@localhost;"`;
is($?,0,"Command executed ok");
`mysql -h 127.0.0.1 -u root -e "flush privileges;"`;
is($?,0,"Command executed ok");
`mysql -h 127.0.0.1 -u root seccubus < db/structure_v$db_version.mysql`;
is($?,0,"Command executed ok");
`mysql -h 127.0.0.1 -u root seccubus < db/data_v$db_version.mysql`;
is($?,0,"Command executed ok");

my $t = Test::Mojo->new('Seccubus');

# Log in
$t->post_ok('/api/session' => { 'REMOTEUSER' => 'admin', "content-type" => "application/json" })
    ->status_is(200,"Login ok")
;

# List empty
$t->get_ok('/api/severities')
	->status_is(200)
	->json_is([
	    {
	        "description" => "No severity has been set",
	        "id" => "0",
	        "name" => "Not set"
	    },
	    {
	        "description" => "Direct compromise of Confidentiality, Integrity or Availbility or policy violation",
	        "id" => "1",
	        "name" => "High"
	    },
	    {
	        "description" => "Could compromise of Confidentiality, Integrity or Availbility in combination with other issue. Disclosure of sensitive information",
	        "id" => "2",
	        "name" => "Medium"
	    },
	    {
	        "description" => "Weakens security posture",
	        "id" => "3",
	        "name" => "Low"
	    },
	    {
	        "description" => "Not a security issue, but deemed noteworthy",
	        "id" => "4",
	        "name" => "Note"
	    }
	])
	;

done_testing();
