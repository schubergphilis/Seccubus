# ------------------------------------------------------------------------------
# Copyright 2011-2018 Frank Breedijk, Steve Launius, Petr
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
package Seccubus::Findings;

=head1 NAME $RCSfile: SeccubusFindings.pm,v $

This Pod documentation generated from the module SeccubusFindings gives a list
of all functions within the module.

=cut

use strict;
use SeccubusV2;
use Seccubus::DB;
use Seccubus::Rights;
use Seccubus::Users;
use Seccubus::Issues;
use Algorithm::Diff qw( diff );
use Data::Dumper;

our @ISA = ('Exporter');

our @EXPORT = qw (
    get_findings
    get_status
    get_filters
    get_finding
    update_finding
    process_status
    diff_finding
);

use Carp;

=head1 Data manipulation - findings

=head2 get_findings

This function returns a reference to an array of findings
(id, host, hostname, port, plugin, findingl, remark, severity, status, status_txt)

=over 2

=item Parameters

=over 4

=item workspace_id - id of the workspace

=item scan_id - id of the scan if 0 this parameter is disregarded

=item filter - reference to a hash containing filters

=back

=item Checks

Must have at least read rights

=back

=cut

sub get_findings {
    my $workspace_id = shift or die "No workspace_id provided";
    my $scan_id = shift;
    my $asset_id = shift;
    my $filter = shift;
    my $limit = shift;

    $limit = 200 unless defined $limit;
    $limit = undef if $limit < 0;

    if ( may_read($workspace_id) ) {
        my $params = [ $workspace_id, $workspace_id ];

        my $query = "
            SELECT DISTINCT `findings`.`id`, `findings`.`host`, `host_names`.`name` as `hostname`,
                `port`, `plugin`, `finding`, `remark`,
                `findings`.`severity` as `severity_id`,
                `severity`.`name` as `severity_name`,
                `findings`.`status` as `status_id`,
                `finding_status`.`name` as `status`,
                `findings`.`scan_id` as `scan_id`,
                `scans`.`name` as `scan_name`,
                `runs`.`time` as `run_time`
            FROM
                `findings`
            LEFT JOIN `host_names` ON `host_names`.`ip` = `host` and `host_names`.`workspace_id` = ?
            LEFT JOIN `severity` ON `findings`.`severity` = `severity`.`id`
            LEFT JOIN `finding_status` ON `findings`.`status` = `finding_status`.`id`
            LEFT JOIN `scans` ON `scans`.`id` = `findings`.`scan_id`
            LEFT JOIN `issues2findings` ON `issues2findings`.`finding_id` = `findings`.`id`
            LEFT JOIN `runs` ON `findings`.`run_id` = `runs`.`id`
            WHERE
                `findings`.`workspace_id` = ?";
        if ( $scan_id != 0 ) {
            $query .= " AND `findings`.`scan_id` = ? ";
            push @$params, $scan_id;
        }
        if($asset_id != 0){
            $query = "
            SELECT DISTINCT `findings`.`id`, `findings`.`host`, `host_names`.`name` AS `hostname`,
                `port`, `plugin`, `finding`, `remark`,
                `findings`.`severity` AS `severity_id`,
                `severity`.`name` AS `severity_name`,
                `findings`.`status` AS `status_id`,
                `finding_status`.`name` AS `status`,
                `findings`.`scan_id` AS `scan_id`,
                `scans`.`name` AS `scan_name`,
                `runs`.`time` AS `run_time`
            FROM
                `findings`
                LEFT JOIN `host_names` ON `host_names`.`ip` = `host` AND `host_names`.`workspace_id` = ?
                LEFT JOIN `severity` ON `findings`.`severity` = `severity`.`id`
                LEFT JOIN `finding_status` ON `findings`.`status` = `finding_status`.`id`
                LEFT JOIN `scans` ON `scans`.`id` = `findings`.`scan_id`
                LEFT JOIN `issues2findings` ON `issues2findings`.`finding_id` = `findings`.`id`
                LEFT JOIN `runs` ON `findings`.`run_id` = `runs`.`id`,
                `assets`,
                `asset_hosts`
            WHERE
                `findings`.`workspace_id` = ? AND
                `assets`.`workspace_id` = `findings`.`workspace_id` AND
                `asset_hosts`.`asset_id` = `assets`.`id` AND (
                    `asset_hosts`.`ip` = `findings`.`host` OR
                    `asset_hosts`.`host` = `findings`.`host` OR
                    `findings`.`host` LIKE CONCAT('%/',`asset_hosts`.`ip`) OR
                    `findings`.`host` LIKE CONCAT(`asset_hosts`.`host`, '/%')
                )
                ";
            $query .= "AND `assets`.`id` = ?";
            push @$params, $asset_id;

        }

        if ( $filter ) {
            if ( $filter->{status} ) {
                $query .= " AND `status` = ? ";
                push @$params, $filter->{status};
            }
            if ( $filter->{host} ) {
                $filter->{host} =~ s/\*/\%/;
                $query .= " AND `findings`.`host` LIKE ? ";
                push @$params, $filter->{host};
            }
            if ( defined $filter->{hostname} ) {
                $filter->{hostname} =~ s/\*/\%/;
                $filter->{hostname} = "%$filter->{hostname}%";
                $query .= " AND `host_names`.`name` LIKE ? ";
                push @$params, $filter->{hostname};
            }
            if ( $filter->{port} ) {
                $query .= " AND `port` = ? ";
                push @$params, $filter->{port};
            }
            if ( $filter->{plugin} ) {
                $query .= " AND `plugin` = ? ";
                push @$params, $filter->{plugin};
            }
            if ( defined $filter->{severity} ) {
                $query .= " AND `findings`.`severity` = ? ";
                push @$params, $filter->{severity};
            }
            if ( $filter->{finding} ) {
                $query .= " AND `finding` LIKE ? ";
                push @$params, "%" . $filter->{finding} . "%";
            }
            if ( $filter->{remark} ) {
                $query .= " AND `remark` LIKE ?";
                push @$params, "%" . $filter->{remark} . "%";
            }
            if ( $filter->{issue} ) {
                $query .= " AND `issues2findings`.`issue_id` = ?";
                push @$params, $filter->{issue};
            }
            if ( $filter->{id} ) {
                $query .= " AND `findings`.`id` = ?";
                push @$params, $filter->{id};
            }
        }

        $query .= " ORDER BY `host`, `port`, `plugin` ";
        if ( $limit ) {
            $query .= "LIMIT ?\n";
            push @$params, $limit;
        }
        #die $query;

        #die $query;
        return sql(
            "return"    => "ref",
            "query"     => $query,
            "values"    => $params,
        );
    } else {
        die "Permission denied!";
    }
}

=head2 get_status

This function returns an array of statusses and the amount of findings in it,
given a specific filter

=over 2

=item Parameters

=over 4

=item workspace_id - id of the workspace

=item scan_ids - reference to an araay of scan ids

=item asset_ids - reference to an araay of asset ids

=item filter - reference to a hash containing filters

=back

=item Checks

Must have at least read rights

=back

=cut

sub get_status {
    my $workspace_id = shift or die "No workspace_id provided";
    my $scan_ids = shift;
    my $asset_ids = shift;
    my $filter = shift;

    if ( may_read($workspace_id) ) {
        my $params;
        push @$params, $workspace_id;

        my $query = "
            SELECT	`s`.`id`, `s`.`name`, COUNT(`fi`.`id`)
            FROM
                `finding_status` `s`
            LEFT JOIN (
                SELECT DISTINCT `findings`.`id`, `findings`.`status`
                FROM
        ";
        $query .= "`asset_hosts`,  " if @$asset_ids;
        $query .= " `findings`
                LEFT JOIN   `host_names` `h`
                ON          ( `h`.`ip` = `findings`.`host` )
                WHERE       `findings`.`workspace_id` = ?
        ";

        if (@$asset_ids) {
            $query .= "AND `asset_hosts`.`asset_id` IN (";
            $query .= join ",", map { push @$params,$_; '?'; } @$asset_ids;
            $query .= " ) AND (
                    `asset_hosts`.`ip` = `findings`.`host` OR
                    `asset_hosts`.`host` = `findings`.`host` OR
                    `findings`.`host` LIKE CONCAT('%/',`asset_hosts`.`ip`) OR
                    `findings`.`host` LIKE CONCAT(`asset_hosts`.`host`, '/%')
                )
            ";
        } elsif ( @$scan_ids ) {
            $query .= " AND `findings`.`scan_id` IN (  ";
            $query .= join ",", map { push @$params,$_; '?'; } @$scan_ids if(@$scan_ids);
            $query .= " ) \n";
        }
        if ( $filter ) {
            if ( $filter->{host} ) {
                $filter->{host} =~ s/\*/\%/;
                $query .= " AND `findings`.`host` LIKE ? ";
                push @$params, $filter->{host};
            }
            if ( $filter->{port} ) {
                $query .= " AND `findings`.`port` = ? ";
                push @$params, $filter->{port};
            }
            if ( $filter->{plugin} ) {
                $query .= " AND `findings`.`plugin` = ? ";
                push @$params, $filter->{plugin};
            }
            if ( $filter->{severity} ) {
                $query .= " AND `findings`.`severity` = ? ";
                push @$params, $filter->{severity};
            }
            if ( $filter->{finding} ) {
                $query .= " AND `finding` LIKE ? ";
                push @$params, "%" . $filter->{finding} . "%";
            }
            if ( $filter->{remark} ) {
                $query .= " AND `remark` LIKE ?";
                push @$params, "%" . $filter->{remark} . "%";
            }
            if ( $filter->{issue} ) {
                $query .= " AND `finding`.`id` IN ( SELECT `finding_id` FROM `issues2findings` WHERE `issue_id` = ? ) ";
                push @$params, $filter->{issue};
            }
            if ( $filter->{hostname} ) {
                $filter->{hostname} =~ s/\*/\%/;
                $filter->{hostname} = "%$filter->{hostname}%";
                $query .= " AND `h`.`name` LIKE ? ";
                push @$params, $filter->{hostname};
            }
        }

        $query .= "
        ) `fi` ON ( `fi`.`status` = `s`.`id` )
        GROUP BY `s`.`id`
        ORDER BY `s`.`id`";
        #die $query;
        return sql(
            "return"    => "ref",
            "query"     => $query,
            "values"    => $params,
        );
    } else {
        die "Permission denied!";
    }
}
=head2 get_filters

This function returns an hash of filters needed with a specific filter given a specific filter

=over 2

=item Parameters

=over 4

=item workspace_id - id of the workspace

=item scan_ids - reference to an araay of scan ids

=item asset_ids - reference to an araay of scan ids

=item filter - reference to a hash containing filter

=back

=item Checks

Must have at least read rights

=back

=cut

sub get_filters {
    my $workspace_id = shift or die "No workspace_id provided";
    my $scan_ids = shift;
    my $asset_ids = shift;
    if(!$scan_ids && !$asset_ids)  { die "Must specify scanids or assetids for function get_status"; }
    my $filter = shift;
    my %filters;

    # finding -> id, host, hostname, port, plugin, findingl, remark, severity, status, status_txt
    # filter -> host hostname port plugin finding remark severity status issue
    if ( ! may_read($workspace_id) ) {
        die "Permission denied!";
    } else {
        my $from = " FROM `findings`";
        my $where = "`findings`.`workspace_id` = ?";
        my $join = "";
        $join .= "LEFT JOIN `issues2findings` `i2f` ON `i2f`.`finding_id` = `findings`.`id `" if exists $filter->{issue};
        $join .= "LEFT JOIN `host_names` ON `host_names`.`ip` = `findings`.`host` AND `host_names`.`workspace_id` = `findings`.`workspace_id` " if exists $filter->{hostname};

        # If we have scan_ids
        if ( @$scan_ids ) {
            $where .= " AND ( " if @$scan_ids;
            foreach my $scan ( @$scan_ids ) {
                $where .= " `scan_id` = ? OR "
            }
            $where =~ s/OR $/\) /;
        } elsif ( @$asset_ids ) {
            $from = "FROM `asset_hosts`, `findings` ";
            $where .= " AND `asset_hosts`.`asset_id` IN ( ";
            foreach my $asset ( @$asset_ids ) {
                $where .= " ? , ";
            }
            $where =~ s/, $/\) /;
            $where .= "AND (
                    `asset_hosts`.`ip` = `findings`.`host` OR
                    `asset_hosts`.`host` = `findings`.`host` OR
                    `findings`.`host` LIKE CONCAT('%/',`asset_hosts`.`ip`) OR
                    `findings`.`host` LIKE CONCAT(`asset_hosts`.`host`, '/%')
                )
            ";
        }

        # Hosts
        my @hosts = ({name => "*", number => 0});
        # Construct filter
        # Get hosts in filter.
        my $ffields = [];
        my $fwhere = construct_filter($filter,"host",$ffields,1);
        my $query = "
            SELECT `findings`.`host`, COUNT(*)
            $from
            $join
            WHERE $where $fwhere
            GROUP BY `findings`.`host`
            ORDER BY INET_ATON(`findings`.`host`), `findings`.`host`
        ";
        my $hosts_in = sql(query => $query, values => [ $workspace_id, @$scan_ids, @$asset_ids, @$ffields ] );

        # Get hosts outside filter.
        $query = "
            SELECT `findings`.`host`, COUNT(*)
            $from
            WHERE $where AND `findings`.`host` NOT IN (
                SELECT DISTINCT `findings`.`host`
                $from
                $join
                WHERE $where $fwhere
            )
            GROUP BY `findings`.`host`
            ORDER BY INET_ATON(`findings`.`host`), `findings`.`host`
        ";
        my $hosts_out = sql(query => $query, values => [$workspace_id, @$scan_ids, @$asset_ids, $workspace_id, @$scan_ids, @$asset_ids, @$ffields ] );
        my %count;

        foreach my $host ( @$hosts_in ) {
            $count{"*"} += $$host[1];

            # Split on slashes first
            my @subs = split(/\//, $$host[0]);
            my $addr = "";
            while ( 1 < @subs ) {
                $addr .= shift @subs;
                $addr .= "/";
                if ( ! exists $count{"$addr*"} ) {
                    push @hosts, { name => "$addr*", number => 0 };
                }
                $count{"$addr*"} += $$host[1];
            }
            # Then on dots
            my @subs = split(/\./, $$host[0]);
            my $addr = "";
            while ( 1 < @subs ) {
                $addr .= shift @subs;
                $addr .= ".";
                if ( ! exists $count{"$addr*"} ) {
                    push @hosts, { name => "$addr*", number => 0 };
                }
                $count{"$addr*"} += $$host[1];
            }
            push @hosts, { name => $$host[0], number => $$host[1] };
        }
        $hosts_in = undef;
        foreach my $host ( @hosts ) {
            if ( exists $count{$host->{name}} ) {
                $host->{number} = $count{$host->{name}};
            }
            if ( $host->{name} eq $filter->{host} ) {
                $host->{selected} = 1;
            } else {
                $host->{selected} = 0;
            }
        }
        push @hosts, { "name" => "---", "number" => -1, selected => 0 };
        foreach my $host ( @$hosts_out ) {
            if ( $$host[0] eq $filter->{host} ) {
                push @hosts, { name => $$host[0], number => $$host[1], selected => 1 };
            } else {
                push @hosts, { name => $$host[0], number => $$host[1], selected => 0 };
            }
        }
        $hosts_out = undef;
        $filters{"host"} = \@hosts;

        # Hostnames
        my @hostnames = ({name => "*", number => 0});
        # Construct filter
        # Get hosts in filter.
        $ffields = [];
        $fwhere = construct_filter($filter,"hostname",$ffields,1);
        $query = "
            SELECT `host_names`.`name` AS `hostname`, COUNT(*)
            $from
            $join";
        $query .= " LEFT JOIN `host_names` ON `host_names`.`ip` = `findings`.`host` AND `host_names`.`workspace_id` = `findings`.`workspace_id` " unless exists $filter->{hostname};
        $query .= "
            WHERE $where $fwhere
            GROUP BY `hostname`
            ORDER BY `hostname`
        ";
        my $hostnames_in = sql(query => $query, values => [ $workspace_id, @$scan_ids, @$asset_ids, @$ffields ] );

        # Get hosts not in filter.
        $query = "
            SELECT `host_names`.`name` AS `hostname`, COUNT(*)
            $from
            $join";
        $query .= " LEFT JOIN `host_names` ON `host_names`.`ip` = `findings`.`host` AND `host_names`.`workspace_id` = `findings`.`workspace_id` " unless exists $filter->{hostname};
        $query .= "
            WHERE $where AND `host_names`.`ip` NOT IN (
                SELECT DISTINCT `findings`.`host`
                $from
                $join
                WHERE $where $fwhere
            )
            GROUP BY `hostname`
            ORDER BY `hostname`
        ";
        my $hostnames_out = sql(query => $query, values => [ $workspace_id, @$scan_ids, @$asset_ids, $workspace_id, @$scan_ids, @$asset_ids, @$ffields ] );

        my $count = 0;
        foreach my $host ( @$hostnames_in ) {
            $count+=$$host[1];
            if ( $$host[0] eq $filter->{hostname} ) {
                push @hostnames, { name => $$host[0], number => $$host[1], selected => 1 };
            } else {
                push @hostnames, { name => $$host[0], number => $$host[1], selected => 0 };
            }
            if ( $hostnames[-1]->{name} eq "" ) {
                $hostnames[-1]->{name} = "(blank)";
                $hostnames[-1]->{value} = "";
            }
        }
        $hostnames_in = undef;
        push @hostnames, { "name" => "---", "number" => -1, selected => 0 };
        foreach my $host ( @$hostnames_out ) {
            $$host[0] = "" unless defined $$host[0];
            if ( $$host[0] eq $filter->{hostname} ) {
                push @hostnames, { name => $$host[0], number => $$host[1], selected => 1 };
            } else {
                push @hostnames, { name => $$host[0], number => $$host[1], selected => 0 };
            }
        }
        $hostnames_out = undef;
        $hostnames[0]->{number} = $count;
        $filters{"hostname"} = \@hostnames;

        # Ports
        my @ports = ({name => "*", number => 0});
        # Construct filter
        # Get hosts in filter.
        $ffields = [];
        $fwhere = construct_filter($filter,"port",$ffields,1);
        $query = "
            SELECT `port`, COUNT(*)
            $from
            $join
            WHERE $where $fwhere
            GROUP BY `port`
            ORDER BY CAST(`port` as SIGNED INTEGER), `port`
        ";
        my $ports_in = sql(query => $query, values => [ $workspace_id, @$scan_ids, @$asset_ids, @$ffields ] );

        # Get ports outside filter
        $query = "
            SELECT `port`, COUNT(*)
            $from
            WHERE $where AND `port` NOT IN (
                SELECT DISTINCT `port`
                $from
                $join
                WHERE $where $fwhere
            )
            GROUP BY `port`
            ORDER BY CAST(`port` as SIGNED INTEGER), `port`
        ";
        my $ports_out = sql(query => $query, values => [ $workspace_id, @$scan_ids, @$asset_ids, $workspace_id, @$scan_ids, @$asset_ids, @$ffields ] );

        $count = 0;
        foreach my $port ( @$ports_in ) {
            $count+=$$port[1];
            $$port[0] = "" unless defined $$port[0];
            if ( $$port[0] eq $filter->{port} ) {
                push @ports, { name => $$port[0], number => $$port[1], selected => 1 };
            } else {
                push @ports, { name => $$port[0], number => $$port[1], selected => 0 };
            }
        }
        $ports_in = undef;
        push @ports, { "name" => "---", "number" => -1, selected => 0 };
        foreach my $port ( @$ports_out ) {
            $$port[0] = "" unless defined $$port[0];
            if ( $$port[0] eq $filter->{port} ) {
                push @ports, { name => $$port[0], number => $$port[1], selected => 1 };
            } else {
                push @ports, { name => $$port[0], number => $$port[1], selected => 0 };
            }
        }
        $ports_out = undef;
        $ports[0]->{number} = $count;
        $filters{"port"} = \@ports;

        # Plugins
        my @plugins = ({name => "*", number => 0});
        # Construct filter
        # Get hosts in filter.
        $ffields = [];
        $fwhere = construct_filter($filter,"plugin",$ffields,1);
        $query = "
            SELECT `plugin`, COUNT(*)
            $from
            $join
            WHERE $where $fwhere
            GROUP BY `plugin`
            ORDER BY CAST(`plugin` AS SIGNED INTEGER), `plugin`
        ";
        my $plugins_in = sql(query => $query, values => [ $workspace_id, @$scan_ids, @$asset_ids, @$ffields ] );
        my @ids = ();
        foreach my $p ( @$plugins_in ) {
            push @ids, $$p[0];
        }

        # Get plugins outside filter
        $query = "
            SELECT `plugin`, COUNT(*)
            $from
            WHERE $where AND `plugin` NOT IN (
                SELECT DISTINCT `plugin`
                $from
                $join
                WHERE $where $fwhere
            )
            GROUP BY `plugin`
            ORDER BY CAST(`plugin` AS SIGNED INTEGER), `plugin`
        ";
        my $plugins_out = sql(query => $query, values => [ $workspace_id, @$scan_ids, @$asset_ids, $workspace_id, @$scan_ids, @$asset_ids, @$ffields ] );

        $count = 0;
        foreach my $plugin ( @$plugins_in ) {
            $count+=$$plugin[1];
            $$plugin[0] = "" unless defined $$plugin[0];
            if ( $$plugin[0] eq $filter->{plugin} ) {
                push @plugins, { name => $$plugin[0], number => $$plugin[1], selected => 1 };
            } else {
                push @plugins, { name => $$plugin[0], number => $$plugin[1], selected => 0 };
            }
        }

        $plugins_in = undef;
        push @plugins, { "name" => "---", "number" => -1, selected => 0 };
        foreach my $plugin ( @$plugins_out ) {
            $$plugin[0] = "" unless defined $$plugin[0];
            if ( $$plugin[0] eq $filter->{plugin} ) {
                push @plugins, { name => $$plugin[0], number => $$plugin[1], selected => 1 };
            } else {
                push @plugins, { name => $$plugin[0], number => $$plugin[1], selected => 0 };
            }
        }
        $plugins_out = undef;
        $plugins[0]->{number} = $count;
        $filters{"plugin"} = \@plugins;

        # Serverity
        my @severitys = ({name => "*", number => 0});
        # Construct filter
        # Get hosts in filter.
        $ffields = [];
        $fwhere = construct_filter($filter,"severity",$ffields,1);
        $query = "
            SELECT `severity`.`id` AS `severity`, `severity`.`name`, COUNT(*)
            $from
            $join
            LEFT JOIN `severity` ON `findings`.`severity` = `severity`.`id`
            WHERE $where $fwhere
            GROUP BY `severity`, `name`
            ORDER BY `severity`
        ";
        my $severitys_in = sql(query => $query, values => [ $workspace_id, @$scan_ids, @$asset_ids, @$ffields ] );

        # Get severities outside filter
        $query = "
            SELECT `severity`.`id` AS `severity`, `severity`.`name`, COUNT(*)
            $from
            $join
            LEFT JOIN `severity` ON `findings`.`severity` = `severity`.`id`
            WHERE $where AND `severity`.`id` NOT IN (
                SELECT DISTINCT `severity`
                $from
                $join
                WHERE $where $fwhere
            )
            GROUP BY `severity`
            ORDER BY `severity`
        ";
        my $severitys_out = sql(query => $query, values => [ $workspace_id, @$scan_ids, @$asset_ids, $workspace_id, @$scan_ids, @$asset_ids, @$ffields ] );

        $count = 0;
        foreach my $severity ( @$severitys_in ) {
            $count+=$$severity[2];
            if ( $$severity[0] eq $filter->{severity} ) {
                push @severitys, { value => $$severity[0], name=>$$severity[1], number => $$severity[2], selected => 1 };
            } else {
                push @severitys, { value => $$severity[0], name=>$$severity[1], number => $$severity[2], selected => 0 };
            }
        }
        $severitys_in = undef;
        push @severitys, { "name" => "---", "number" => -1, selected => 0 };
        foreach my $severity ( @$severitys_out ) {
            if ( $$severity[0] eq $filter->{severity} ) {
                push @severitys, { value => $$severity[0], name=>$$severity[1], number => $$severity[2], selected => 1 };
            } else {
                push @severitys, { value => $$severity[0], name=>$$severity[1], number => $$severity[2], selected => 0 };
            }
        }
        $severitys_out = undef;
        $severitys[0]->{number} = $count;
        $filters{"severity"} = \@severitys;

        # Issues
        my @issues = ({name => "*", number => 0});
        # Construct filter
        # Get hosts in filter.
        $ffields = [];
        $fwhere = construct_filter($filter,"issue",$ffields,1);
        $query = "
            SELECT `issues`.`id` AS `issue_id`, `issues`.`name`, `ext_ref`, COUNT(*)
            $from
            $join";
        $query .= " LEFT JOIN `issues2findings` `i2f` ON `findings`.`id` = `i2f`.`finding_id` " unless $filter->{issue};
        $query .= "
            LEFT JOIN `issues` ON `i2f`.`issue_id` = `issues`.`id`
            WHERE $where $fwhere
            GROUP BY `issue_id`, `name`, `ext_ref`
            ORDER BY `issue_id`
        ";
        #die $query . " +++ " . join " -- ", ($workspace_id, @$scan_ids, @$asset_ids, @$ffields);
        my $issues_in = sql(query => $query, values => [ $workspace_id, @$scan_ids, @$asset_ids, @$ffields ] );

        # Get issues outside filter

        $query = "
            SELECT `issues`.`id`, `issues`.`name`, `ext_ref`, '?'
            FROM `issues`
            WHERE `issues`.`workspace_id` = ? AND `id` NOT IN (
                SELECT DISTINCT `issues`.`id` AS `issue_id`
                $from
                $join";
        $query .= " LEFT JOIN `issues2findings` `i2f` ON `findings`.`id` = `i2f`.`finding_id` " unless $filter->{issue};
        $query .= "
                LEFT JOIN `issues` ON `i2f`.`issue_id` = `issues`.`id`
                WHERE $where $fwhere AND `issue_id` IS NOT NULL
            )
            ORDER BY `id`
        ";
        my $issues_out = sql(query => $query, values => [ $workspace_id, $workspace_id, @$scan_ids, @$asset_ids, @$ffields ] );

        $count = 0;
        foreach my $issue ( @$issues_in ) {
            $count+=$$issue[3];
            # SKIP nulls
            if ( defined $$issue[1] ) {
                my ($issue_name, $issue_value);
                $issue_name = "$$issue[1] ($$issue[2])";
                $issue_value = $$issue[0];
                if ( $$issue[0] eq $filter->{issue} ) {
                    push @issues, { value => $$issue[0], name=>$issue_name, number => $$issue[3], selected => 1 };
                } else {
                    push @issues, { value => $$issue[0], name=>$issue_name, number => $$issue[3], selected => 0 };
                }
            }
        }
        $issues_in = undef;
        push @issues, { "name" => "---", "number" => -1, selected => 0 };
        foreach my $issue ( @$issues_out ) {
            my $issue_name = "$$issue[1] ($$issue[2])";
            if ( defined $$issue[1] ) {
                if ( $$issue[0] eq $filter->{issue} ) {
                    push @issues, { value => $$issue[0], name=>$issue_name, number => $$issue[3], selected => 1 };
                } else {
                    push @issues, { value => $$issue[0], name=>$issue_name, number => $$issue[3], selected => 0 };
                }
            }
        }
        $issues_out = undef;
        $issues[0]->{number} = $count;
        $filters{"issue"} = \@issues;

        # Finding and remark are easy
        $filter->{"finding"} = "" unless $filter->{"finding"};
        $filters{"finding"} = $filter->{"finding"};
        $filter->{"remark"} = "" unless $filter->{"remark"};
        $filters{"remark"} = $filter->{"remark"};

        return %filters;
    }
}

sub construct_filter {
    my $filter = shift;
    my $exclude = shift;
    my $args = shift;
    my $in = shift;

    my $where = "AND ( ";
    if ( exists $filter->{status} && $exclude ne "status" ) {
        if ( $in ) {
            $where .= "`findings`.`status` = ? AND ";
        } else {
            $where .= "`findings`.`status` != ? OR ";
        }
        push @$args, $filter->{status};
    }

    if ( exists $filter->{host} && $exclude ne "host" ) {
        my $host = lc($filter->{host});
        $host =~ s/\*/%/g;
        if ( $in ) {
            $where .= "`findings`.`host` LIKE ? AND ";
        } else {
            $where .= "`findings`.`host` NOT LIKE ? OR ";
        }
        push @$args, $host;
    }

    if ( exists $filter->{hostname} && $exclude ne "hostname" ) {
        my $hostname = lc($filter->{hostname});
        $hostname =~ s/\*/%/g;
        if ( $in ) {
            $where .= "`host_names`.`name` LIKE ? AND ";
        } else {
            $where .= "`host_names`.`name` NOT LIKE ? OR ";
        }
        push @$args, $hostname;
    }

    if ( exists $filter->{port} && $exclude ne "port" ) {
        if ( $in ) {
            $where .= "`port` = ? AND ";
        } else {
            $where .= "`port` != ? OR ";
        }
        push @$args, $filter->{port};
    }

    if ( exists $filter->{plugin} && $exclude ne "plugin" ) {
        if ( $in ) {
            $where .= "`plugin` = ? AND ";
        } else {
            $where .= "`plugin` != ? OR ";
        }
        push @$args, $filter->{plugin};
    }

    if ( exists $filter->{severity} && $exclude ne "severity" ) {
        if ( $in ) {
            $where .= "`findings`.`severity` = ? AND ";
        } else {
            $where .= "`findings`.`severity` != ? OR ";
        }
        push @$args, $filter->{port};
    }

    if ( exists $filter->{issue} && $exclude ne "issue" ) {
        if ( $in ) {
            $where .= "`issue_id` = ? AND ";
        } else {
            $where .= "`issue_id` != ? OR ";
        }
        push @$args, $filter->{issue};
    }

    if ( exists $filter->{finding} && $exclude ne "finding" ) {
        my $finding = "%" . lc($filter->{finding}) . "%";
        if ( $in ) {
            $where .= "`finding` LIKE ? AND ";
        } else {
            $where .= "`finding` NOT LIKE ? OR ";
        }
        push @$args, $finding;
    }

    if ( exists $filter->{remark} && $exclude ne "remark" ) {
        my $remark = "%" . lc($filter->{remark}) . "%";
        if ( $in ) {
            $where .= "`remark` LIKE ? AND ";
        } else {
            $where .= "`remark` NOT LIKE ? OR ";
        }
        push @$args, $filter;
    }
    $where =~ s/(AND|OR) $/\)/;
    $where = "" if $where eq "AND ( ";

    return $where;
}


=head2 match

Private function that returns 1 if a finding matches a filter or 0 if it doesn't

=over 2

=item Parameters

=over 4

=item finding - Reference to an array that containst the finding as returned by get_findings

=item filter - Reference to a hash containing the filter

=item fields (Optional) - Only match on these fields

=back

=back

=cut

sub match {
    my $finding = shift or die "No finding specified for match";
    my $filter = shift or die "No filter specified for match";
    my $fields = shift;

    #die Dumper $filter;

    unless ($fields) {
        $fields = [];
        push @$fields, qw( host hostname port plugin finding remark severity status);
    }
    my %filter2;
    foreach my $field ( @$fields ) {
        $filter2{$field} = $filter->{$field};
    }
    my $match = 1;
    #id
    #host
    if ( $filter2{"host"} && $filter2{"host"} && $filter2{"host"} ne "*" ) {# We have to filter
        my $re = $filter2{"host"};
        $re =~ s/\./\\\./g;
        $re =~ s/\*/\.\*/g;
        if ( $$finding[1] !~ /^$re$/ ) {
            $match = 0;
        }
    }
    #hostname
    if ( $match && $filter2{"hostname"} && $filter2{"hostname"} ne "*" ) {
        my $re = $filter2{"hostname"};
        $re =~ s/\*/\.\*/g;
        if ( $$finding[2] !~ /^$re$/ ) {
            $match = 0;
        }
    }
    #port
    if ( $match && $filter2{"port"} && $filter2{"port"} ne "*" && $$finding[3] ne $filter2{"port"} ) {
        $match = 0;
    }
    #plugin
    if ( $match && $filter2{"plugin"} && $filter2{"plugin"} ne "*" && $$finding[4] ne $filter2{"plugin"} ) {
        $match = 0;
    }
    #finding
    if ( $match && $filter2{"finding"} && $filter2{"finding"} ne "*" ) {
        my $re = $filter2{"finding"};
        $re =~ s/\*/\.\*/g;
        if ( $$finding[5] !~ /$re/ ) {
            $match = 0;
        }
    }
    #remark
    if ( $match && $filter2{"remark"} && $filter2{"remark"} ne "*" ) {
        my $re = $filter2{"remark"};
        $re =~ s/\*/\.\*/g;
        if ( $$finding[6] !~ /$re/ ) {
            $match = 0;
        }
    }
    #severity
    if ( $match && $filter2{"severity"} ne undef && $filter2{"severity"} ne "*" && $$finding[7] ne $filter2{"severity"} ) {
        $match = 0;
    }
    #status
    if ( $match && $filter2{"status"} && $filter2{"status"} ne "*" && $$finding[9] ne $filter2{"status"} ) {
        $match = 0;
    }
    #issue
    #die Dumper %filter2;
    if ( $match && $filter2{"issue"} && $filter2{"issue"} ne "*" ) {
        $match = 0;
        foreach my $i ( @{$$finding[13]} ) {
            if ( $$i[0] == $filter2{"issue"} ) {
                $match = 1;
                last;
            }
        }
    }
    return $match;
}

=head2 get_finding

This function returns a reference to an array of changes of findings
(id, finding.id, host, hostname, port, plugin, finding, remark, severity, severity_name, status, status_txt, user_id, username, time, runtime)

=over 2

=item Parameters

=over 4

=item workspace_id - id of the workspace

=item finding_id - id of the finding

=back

=item Checks

Must have at least read rights

=back

=cut

sub get_finding {
    my $workspace_id = shift or die "No workspace_id provided";
    my $finding_id = shift or die "No finding_id provided";

    if ( may_read($workspace_id) ) {
        my $params = [ $workspace_id, $workspace_id ];

        my $query = "
            SELECT  `finding_changes`.`id`, `findings`.`id`, `host`,
                `host_names`.`name`, `port`, `plugin`,
                `finding_changes`.`finding`,
                `finding_changes`.`remark`,
                `finding_changes`.`severity`, `severity`.`name`,
                `finding_changes`.`status`, `finding_status`.`name`,
                `user_id`, `username`, `finding_changes`.`time` as `changetime`,
                `runs`.`time` as `runtime`
            FROM
                `finding_changes`
                LEFT JOIN `users` ON (`finding_changes`.`user_id` = `users`.`id` ),
                `finding_status`,
                `severity`,
                `runs`,
                `findings`
                LEFT JOIN `host_names` ON `findings`.`host` = `host_names`.`ip`
            WHERE
                `findings`.`workspace_id` = ? AND
                `findings`.`id` = ? AND
                `findings`.`id` = `finding_changes`.`finding_id` AND
                `finding_changes`.`severity` = `severity`.`id` AND
                `finding_changes`.`status` = `finding_status`.`id` AND
                `runs`.`id` = `finding_changes`.`run_id`
            ORDER BY `finding_changes`.`time` DESC, `finding_changes`.`id` DESC
            ";


        return sql( "return"	=> "ref",
                    "query"	=> $query,
                    "values"	=> [ $workspace_id, $finding_id ]
                  );
    } else {
        die "Permission denied!";
    }
}

=head2 update_finding

This function updates or creates a finding in the database. It takes a named
parameter list with the following parameters:

=over 2

=item Parameters

=over 4

=item finding_id  - If set, the function will try to update this finding

=item workspace_id  - Manditory

=item run_id

=item scan_id     - Manditory if no finding_id is given

=item asset_id     - Manditory if no finding_id is given

=item host        - Manditory if no finding_id is given

=item port        - Manditory if no finding id is given

=item plugin      - Manditory if no finding_id is given

=item finding     - The actual finding text

=item remark      -

=item severity    - 0 if not given and finding gets created

=item status      - NEW if not given and finding gets created

=item overwrite	  - 0 means append remark, 1 (default) means overwrite remark.

=item user_id     - User_id to "blame" in the log

Append only happens if the finding exists

=back

=item Returns

finding_id

=item Checks

Madatory parameters are checked. User must have write permission.

=cut

sub update_finding {
    my %arg = @_;

    # Check if the user has write permissions
    die "You don't have write permissions for this workspace!" unless may_write($arg{workspace_id});

    # Check for mandatory parameters
    foreach my $param ( qw(workspace_id) ) {
        die "Manditory parameter $param missing" unless exists $arg{$param};
    }
    # Check if status is a legal value
    if ( exists $arg{status} ) {
        unless ( ($arg{status} >=  1 && $arg{status} <= 6) || $arg{status} == 99 ) {
            die "Illegal status value $arg{status}";
        }
    }

    if ( ! $arg{finding_id} ) {
        # If we don't have a finding ID there are additional mandatory
        # parameters.
        foreach my $param ( qw(scan_id run_id host port plugin finding) ) {
            die "Manditory parameter $param missing" unless exists $arg{$param};
        }

        # Lets try to find out if a finding allready exists for this
        # host port plugin combination
        $arg{finding_id} = sql (
            "return"	=> "array",
            "query"		=> "
                SELECT `id`
                FROM `findings`
                WHERE `workspace_id` = ? AND
                    `scan_id` = ? AND
                    `host` = ? AND
                    `port` = ? AND
                    `plugin` = ?",
            "values"	=> [ $arg{workspace_id}, $arg{scan_id}, $arg{host}, $arg{port}, $arg{plugin} ],
            );

    }

    # Lets set some default values
    $arg{overwrite} = 1 if not exists $arg{overwrite};
    $arg{status} = 1 unless $arg{status} or $arg{finding_id};
    $arg{severity} = 0 unless exists $arg{severity} or $arg{finding_id};
    confess("Invalid severity $arg{severity}") if ($arg{severity} < 0 || $arg{severity} > 5);

    my ( @fields, @values );
    foreach my $field ( qw(scan_id host port plugin finding severity status run_id) ) {
        if ( exists($arg{$field}) ) {
            push @fields, $field;
            push @values, $arg{$field};
        }
    }
    if ( $arg{finding_id} ) {
        # We need to update the record
        my $query = "UPDATE findings SET ";
        $query .= join " = ? , ", @fields;
        $query .= " = ?";
        if ( exists $arg{remark} ) {

            if ( $arg{overwrite}  ) {
                $query .= ", `remark` = ? ";
                push @values, $arg{remark};
            } else {
                if ( $arg{remark} ) {
                    $query .= ", `remark` = CONCAT_WS('\n', `remark`, ?) ";
                    push @values, $arg{remark};
                }
            }
        }
        $query .= " WHERE `id` = ? AND `workspace_id` = ?";
        sql( "return"	=> "handle",
             "query" 	=> $query,
             "values"	=> [ @values, $arg{finding_id}, $arg{workspace_id} ]
           );
    } else {
        # We need to create the record
        push @fields, "workspace_id";
        push @values, $arg{workspace_id};
        if ( exists($arg{remark}) ) {
            push @fields, "remark";
            push @values, $arg{remark};
        }
        my $count = @fields;
        $count--;
        my $query = "insert into findings(";
        $query .= join ",", @fields;
        $query .= ") values (";
        $query .= "? ," x $count;
        $query .= "? );";
        $arg{finding_id} = sql( "return"	=> "id",
                    "query"		=> $query,
                    "values"	=> \@values,
                      );
    }
    # Create an audit record
    create_finding_change($arg{finding_id},$arg{timestamp},$arg{userid});
    return $arg{finding_id};
}

=head2 create_finding_change (hidden)

This function adds a record to the finding_changes table.

=over 2

=item Parameters

=over 4

=item finding_id  - Manditory

=item timestamp - Optional - Timestamp for this change record

=item user_id - Optional - User_id to "blame" for this change

=back

=item Returns

THe inserted id.

=item Checks

None, this is a hidden function that will not be called through the API. All
checking should have been doine a higher levels.

=back

=cut

sub create_finding_change {
    my $finding_id = shift or die "No fidnings_id given";
    my $timestamp = shift;
    my $user_id = shift;

    $user_id = get_user_id($ENV{SECCUBUS_USER}) unless $user_id;

    my @new_data = sql( "return"	=> "array",
            "query"		=> "SELECT `status`, `finding`, `remark`, `severity`, `run_id` FROM `findings` WHERE `id` = ?",
            "values"	=> [ $finding_id ],
              );
    my @old_data = sql( "return"	=> "array",
            "query"		=> "
                SELECT `status`, `finding`, `remark`, `severity`, `run_id` FROM `finding_changes`
                WHERE `finding_id` = ?
                ORDER BY `id` DESC
                LIMIT 1",
            "values"	=> [ $finding_id ],
    );
    my $changed = 0;
    foreach my $i ( (0..4) ) {
        if ( $old_data[$i] ne $new_data[$i] || ( defined($old_data[$i]) && !defined($new_data[$i]) ) ||  ( ! defined($old_data[$i]) && defined($new_data[$i]) ) ) {
            $changed = 1;
            last;
        }
    }
    if ( $changed ) {
        my $query = "INSERT INTO `finding_changes` (`finding_id`, `status`, `finding`, `remark`, `severity`, `run_id`, `user_id`";
        $query .= ", time" if $timestamp;
        $query .= ") values (?, ?, ?, ?, ?, ?, ?";
        $query .= ", ?" if $timestamp;
        $query .= ")";
        my $values = [ $finding_id, @new_data, $user_id ];
        push @$values, $timestamp if $timestamp;

        sql( "return"	=> "id",
             "query"	=> $query,
             "values"	=> $values,
           );
    }
}

=head2 process_status

This function calculates new statusses based on changes in the scan. This
function should be run immediately after a new scan is loaded into the system
parallel editing may interfere

=over 2

=item Parameters

=over 4

=item workscape_id - Workspace ID

=item scan_id - Scan ID number

=item run_id - Run ID number of the latest scan

=item verbose - Optional paarameter that sets the verbosity of the processing

=back

=item Returns

The number of changed findings

=item Checks

The user must have write rights on the workspace

=back

=cut

sub process_status {
    my $workspace_id = shift;
    my $scan_id = shift;
    my $run_id = shift;
    my $verbose = shift;

    my $ref;

    # Find the ids that need to be set to GONE, basically these are the
    # findings that currently have the status NEW (1), CHANGED(2), OPEN(3),
    # or NO ISSUE (4) (so basically 4 or lower) and isn't associated with
    # the current run
    $ref = sql(
        "return"    => "ref",
        "query"     => "
            SELECT `id`
            FROM `findings`
            WHERE  `workspace_id` = ? AND
                `scan_id` = ? AND
                `status` <= 4  AND
                `run_id` <> ?",
      "values"	=> [ $workspace_id, $scan_id, $run_id ],
    );

    foreach my $row ( @{$ref} ) {
        my $id = $$row[0]; # Get the id from the arrayref;
        print "Set finding $id to status GONE\n" if $verbose;
        update_finding(
            "workspace_id"	=> $workspace_id,
            "finding_id"	=> $id,
            "status"	=> 5,
        );
    }

    # Find ids for findings that were previously GONE (5) but
    # are associated with the current run
    $ref = sql(
        "return"    => "ref",
        "query"     => "
            SELECT `id`
            FROM    `findings`
            WHERE   `workspace_id` = ? AND
                `scan_id` = ? AND
                `status` = 5 AND
                `run_id` = ?",
        "values"	=> [ $workspace_id, $scan_id, $run_id ],
    );
    foreach my $row ( @{$ref} ) {
        my $id = $$row[0]; # Get the id from the arrayref;
        # Find status before gone
        my @sbg = sql(
            return  => "array",
            query   => "
                SELECT `status`, `run_id`
                FROM `finding_changes`
                WHERE
                    `finding_id` = ? AND
                    `status` <> 5 AND
                    `status` <> 6 AND
                    `run_id` <> ?
                ORDER BY `time` DESC
                LIMIT 1",
            values 	=> [ $id, $run_id ]
        );
        if ( $sbg[0] == 2 ) { # SBG is Changed,set to changed
            print "Set finding $id to status NEW\n" if $verbose;
            update_finding(
                "workspace_id"	=> $workspace_id,
                "finding_id"	=> $id,
                "status"		=> 2,
            );
        } elsif ( $sbg[0] == 4 ) { #SBG is No issue, need to check if it changed.
            # Get differences in diff format
            my @diff = diff_finding("diff", $workspace_id, $id, $run_id, $sbg[1]);
            if ( @diff ) {
                # Finding changed from previous non-gone finding. Setting to changed.
                print "Set finding $id to status CHANGED\n" if $verbose;
                update_finding(
                    "workspace_id"	=> $workspace_id,
                    "finding_id"	=> $id,
                    "status"		=> 2,
                );
            } else {
                # Finding did not change from previous non-gone finding. Setting to No Issue.
                print "Set finding $id to status NO ISSUE\n" if $verbose;
                update_finding(
                    "workspace_id"	=> $workspace_id,
                    "finding_id"	=> $id,
                    "status"		=> 4,
                );
            }
        } elsif ( $sbg[0] == 99 ) { #STB is MASKED, set to MASKED
            print "Set finding $id to status NEW\n" if $verbose;
            update_finding(
                "workspace_id"	=> $workspace_id,
                "finding_id"	=> $id,
                "status"		=> 99,
            );
        } else { # In all other cases the status goes to New.
            print "Set finding $id to status NEW\n" if $verbose;
            update_finding(
                "workspace_id"	=> $workspace_id,
                "finding_id"	=> $id,
                "status"		=> 1,
            );
        }
    }

    # Find the ids that need to be set to NEW, basically these are the
    # findings that currently have the status CLOSED (6) but
    # are associated with the current run (as provided by the user)
    # If a finding is created for the first time, it gets the status NEW by default
    $ref = sql(
        "return"    => "ref",
        "query"     => "
            SELECT `id`
            FROM `findings`
            WHERE `workspace_id` = ? AND
                `scan_id` = ? AND
                `status` = 6 AND
                run_id = ?",
          "values"  => [ $workspace_id, $scan_id, $run_id ],
    );
    foreach my $row ( @{$ref} ) {
        my $id = $$row[0]; # Get the id from the arrayref;
        print "Set finding $id to status NEW\n" if $verbose;
        update_finding(
            "workspace_id"	=> $workspace_id,
            "finding_id"	=> $id,
            "status"	=> 1,
        );
    }

    # Find out if there has been a previous run
    my $previous_run = sql(
        return	=> "array",
        query	=> "SELECT	MAX(`id`)
                    FROM	`runs`
                    WHERE	`scan_id` = ? AND
                            `id` <> ?",
        values	=> [ $scan_id, $run_id ]
    );
    print "Previous run is: $previous_run\n" if $verbose;
    if ( $previous_run ) {		# No need to check for changes if this
                                # is the first run

        # Find the ids that need to be tested for changes. basically
        # these are the findings with status OPEN(3), or NO ISSUE (4)
        # associated with the current run
        $ref = sql(
            "return"	=> "ref",
            "query"	=> "SELECT	`id`
                        FROM	`findings`
                        WHERE 	`workspace_id` = ? AND
                                `scan_id` = ? AND
                                ( `status` = 3 OR `status` = 4 ) AND
                                `run_id` = ?",
            "values"	=> [ $workspace_id, $scan_id, $run_id ],
        );
        foreach my $row ( @{$ref} ) {
            my $id = $$row[0]; # Get the id from the arrayref;
            print "Checking finding $id for changes\n" if $verbose;
            # Get differences in diff format
            my @diff = diff_finding("diff", $workspace_id, $id, $run_id, $previous_run);
            if ( @diff ) {
                print "Changes found\n" if $verbose;
                print join "\n", @diff if $verbose > 1;
                # update the finding to changed if there is a diff
                if ( @diff[0] eq "NEW" ) {
                    # This happens 'naturally' if we have set a finding back to No Issue when it was
                    # gone and the status before gone was No Issue. This is handled above.
                } elsif ( @diff ) {
                    update_finding (
                        "workspace_id"  => $workspace_id,
                        "finding_id"    => $id,
                        "status"        => 2,
                    );
                }
            }
        }
    }
}

=head2 diff_finding

This function calculates the differences between two runs of a finding.

=over 2

=item Parameters

=over 4

=item type - Type of output

"diff" output in diff format. Returns and array.
"html" output in HTML format. See wiki.
"txt" output in text format.

=item workspace_id - ID of the workspace

=item finding_id - ID of the finding to diff

=item this_run - ID of the current run

=item prev_run - ID of the previous run

=back

=item Returns

undef if there are no differences, otherwise the diff in the format requested

=item Checks

Must be able to read the workspaced

=back

=cut

sub diff_finding {
    my $type = shift;
    my $workspace_id = shift;
    my $finding_id = shift;
    my $this_run = shift;
    my $prev_run =shift;

    if ( may_read($workspace_id) ) {
        my @current = sql( return	=> "array",
                    query	=> "SELECT `finding`
                                FROM `findings`
                            WHERE `id` = ?
                            AND `workspace_id` = ?",
                    values	=> [ $finding_id, $workspace_id ],
                  );
        die "Unable to load current finding, ws: $workspace_id, id: $finding_id, run: $this_run" unless ( @current );
        my @prev = sql( return	=> "array",
                query	=> "SELECT `finding`
                           FROM `finding_changes`
                        WHERE `finding_id` = ?
                        AND `run_id` = ?
                        ORDER BY `time` DESC
                        LIMIT 1",
                   values	=> [ $finding_id, $prev_run ],
                 );
        if ( @prev ) {
            if ( $current[0] ne $prev[0] ) {
                # There is a difference

                @current = split(/\n/, $current[0]);
                @prev = split(/\n/, $prev[0]);
                my $diff = diff(\@prev, \@current);
                my @diff;
                foreach my $line ( @{$$diff[0]} ) {
                    push @diff, join " ", @$line;
                }

                if ( $type eq "diff" ) {
                    return @diff;
                } elsif ( $type eq "txt" ) {
                    return join "\n", @diff;
                } elsif ( $type eq "html" ) {
                    return join "<br>\n", @diff;
                } else {
                    die "Unknown return type '$type'";
                }
            } else{
                # No difference return empty array

                return;
            }
        } else {
            # There is no previous run, this should technically not
            # happen, but can apparently happen with imported scans
            return ( "NEW" );
        }
    } else {
        die("You are not allowed to read workspace '$workspace_id'")
    }
}

# Close the PM file.
return 1;
