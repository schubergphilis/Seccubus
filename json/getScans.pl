#!/usr/bin/env perl
# ------------------------------------------------------------------------------
# $Id$
# ------------------------------------------------------------------------------
# List the scans
# ------------------------------------------------------------------------------

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON;
use lib "..";
use SeccubusV2;
use SeccubusScans;

my $query = CGI::new();
my $json = JSON->new();

print $query->header("application/json");

my $workspace_id = $query->param("workspaceId");

# Return an error if the required parameters were not passed 
if (not (defined ($workspace_id))) {
	bye("Parameter workspaceId is missing");
} elsif ( $workspace_id + 0 ne $workspace_id ) {
	bye("WorkspaceId is not numeric");
};

eval {
	my @data;
	my $scans = get_scans($workspace_id);

	foreach my $row ( @$scans ) {
		push (@data, {
			'id'		=> $$row[0],
			'name'		=> $$row[1],
			'scanner'	=> $$row[2],
			'parameters'	=> $$row[3],
			'lastScan'	=> $$row[4],
			'runs'		=> $$row[5],
			'findCount'	=> $$row[6],
			'targets'	=> $$row[7],
			'workspace'	=> $$row[8],
			'notifications'	=> $$row[9],
		});
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
