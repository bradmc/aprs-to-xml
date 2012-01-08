#!/usr/bin/perl

use strict;
use CGI::Carp qw(fatalsToBrowser);
use CGI;

use lib qw(./);
use Station;

	# get params
	#
	my $cgi = new CGI;
	my @calls = $cgi->param('call');
	my $xql = $cgi->param('xql');
	my $strip_tags = $cgi->param('strip_tags');

	my $station = new Station ( xql=>$xql, strip_tags=>$strip_tags );

	$station->set_declaration;
	$station->set_multiple_station_header if int(@calls) > 1;
	foreach my $call (@calls)
	{	
		$call =~ tr/a-z/A-Z/;
		$station->set_call($call);
		$station->set_station_header;
		$station->set_last_position;
		$station->set_last_weather;
		# $station->set_last_status; # the laststatus table no longer appears to be used in aprsworld 2011-01-17
		$station->set_station_footer;
# bam testing to see if this makes it easier on me and aprsworld - 20090821
sleep 1;
	}
	$station->set_station_footer if int(@calls) > 1;
	$station->set_end;

	# print xml doc or other result
	#
	if ($xql and $strip_tags) {
		print $cgi->header('text/plain');
	} else {
		print $cgi->header('text/xml');
	}
	$station->print;


