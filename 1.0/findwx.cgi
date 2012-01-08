#!/usr/bin/perl

use strict;
use CGI::Carp qw(fatalsToBrowser);
use CGI;

use lib qw(./);
use Station;

	my $cgi = new CGI;
	my $call = $cgi->param('call');
	$call =~ tr/a-z/A-Z/;

	my $station = new Station ( $call );

	$station->set_header;
	$station->set_last_position;
	$station->set_last_weather;
	$station->set_footer;
	print $cgi->header('text/xml');
	$station->print;

