#!/usr/bin/perl

use strict;
use CGI::Carp qw(fatalsToBrowser);
use CGI;

use lib qw(./);
use Station;

	# get params
	#
	my $cgi = new CGI;
	my $call = $cgi->param('call');
	my $xql = $cgi->param('xql');
	my $strip_tags = $cgi->param('strip_tags');

	# filter params
	#
	$call =~ tr/a-z/A-Z/;

	# set up xml doc
	#
	my $station = new Station ( call=>$call, xql=>$xql, strip_tags=>$strip_tags );
	$station->set_header;
	$station->set_last_position;
	$station->set_last_weather;
	$station->set_last_status;
	$station->set_footer;

	# print xml doc or other result
	#
	if ($xql and $strip_tags) {
		print $cgi->header('text/plain');
	} else {
		print $cgi->header('text/xml');
	}
	$station->print;


