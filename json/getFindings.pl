#!/usr/bin/env perl
# Copyright 2016 Frank Breedijk, Petr
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
# ------------------------------------------------------------------------------
# Get a full list of findings associated with the filter parameters given
# ------------------------------------------------------------------------------

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON;
use lib "..";
use SeccubusV2;
use SeccubusFindings;
use SeccubusIssues;
use Data::Dumper;

my $config = get_config();

my $query = CGI::new();
my $json = JSON->new();

print $query->header(-type => "application/json", -expires => "-1d", -"Cache-Control"=>"no-store, no-cache, must-revalidate", -"X-Clacks-Overhead" => "GNU Terry Pratchett");

my $params = $query->Vars;
my $workspace_id = $query->param("workspaceId");
my @scan_ids = split(/\0/,$params->{"scanIds[]"});
my @asset_ids = split(/\0/,$params->{"assetIds[]"});
my $limit = $query->param("Limit");

$limit = 200 unless defined $limit;
$limit += 0; # Make sure limit is numeric

# Return an error if the required parameters were not passed 
if (not (defined ($workspace_id))) {
	bye("Parameter workspaceId is missing");
} elsif ( $workspace_id + 0 ne $workspace_id ) {
	bye("WorkspaceId is not numeric");
};

eval {
	my @data;
	my %filter;
	foreach my $key ( qw( Status Host Hostname Port Plugin Severity Finding Remark Severity Issue ) ) {
		if ($query->param($key) ne undef and $query->param($key) ne "all" and $query->param($key) ne "null" and $query->param($key) ne "*" ) {
			$filter{lc($key)} = $params->{$key}; 
		}
	}

	my $issues = get_issues($workspace_id,undef,1); # Get list of issues with finding_id;
	my %i2f;
	foreach my $issue ( @$issues ) {
		my $id = $$issue[8];
		if ( $id ) { # finding_id

			$i2f{$id} = [] unless $i2f{$id};
			my $i = {};
			$i->{id} = $$issue[0];
			$i->{name} = $$issue[1];
			$i->{ext_ref} = $$issue[2];
			$i->{description} = $$issue[3];
			$i->{severity} = $$issue[4];
			$i->{severityName} = $$issue[5];
			$i->{status} = $$issue[6];
			$i->{statusName} = $$issue[7];
			my $url = $config->{tickets}->{url_head} . $$issue[2] . $config->{tickets}->{url_tail} if $config->{tickets}->{url_head};
			$i->{url} = $url;
			push @{$i2f{$id}}, $i;
		}
	}

	if( ! @asset_ids ){
		@scan_ids = ( 0 ) unless @scan_ids;
		foreach my $scan_id ( @scan_ids ) {
			my $findings = get_findings($workspace_id, $scan_id,'0', \%filter, $limit);

			foreach my $row ( @$findings ) {
				push (@data, {
					'id'		=> $$row[0],
					'host'		=> $$row[1],
					'hostName'	=> $$row[2],
					'port'		=> $$row[3],
					'plugin'	=> $$row[4],
					'find'		=> $$row[5],
					'remark'	=> $$row[6],
			 		'severity'	=> $$row[7],
					'severityName'	=> $$row[8],
					'status'	=> $$row[9],
					'statusName'	=> $$row[10],
					'scanId'	=> $$row[11],
					'scanName'	=> $$row[12],
					'issues'	=> $i2f{$$row[0]}
				});
			}
		}
	} else{
		foreach my $asset_id ( @asset_ids ) {
			my $findings = get_findings($workspace_id, '0', $asset_id, \%filter, $limit);
			foreach my $row ( @$findings ) {
				push (@data, {
					'id'		=> $$row[0],
					'host'		=> $$row[1],
					'hostName'	=> $$row[2],
					'port'		=> $$row[3],
					'plugin'	=> $$row[4],
					'find'		=> $$row[5],
					'remark'	=> $$row[6],
			 		'severity'	=> $$row[7],
					'severityName'	=> $$row[8],
					'status'	=> $$row[9],
					'statusName'	=> $$row[10],
					'scanId'	=> $$row[11],
					'scanName'	=> $$row[12],
					'issues'	=> $i2f{$$row[0]}
				});
			}
		}
	}

	
	print $json->pretty->encode(\@data);
} or do {
	bye(join "\n", $@);
};

sub bye($) {
	my $error=shift;
	print $json->pretty->encode([{ error => $error }]);
	exit;
}
