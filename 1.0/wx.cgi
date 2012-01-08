#!/usr/bin/perl

use strict;
use CGI::Carp qw(fatalsToBrowser);
use CGI;

use lib qw(./);
use Station;

	my $cgi = new CGI;
    my $call = $cgi->param('call');
    my $start = $cgi->param('start');
    my $length = $cgi->param('length');

    $call =~ tr/a-z/A-Z/;
    $start = ($start and ($start > 0)) ? int($start) : 24;
    $length = ($length and ($length > 0)) ? int($length) : $start;

	my $station = new Station ( $call );

	$station->set_header;
	$station->set_last_position;
	$station->set_multiple_weather($start,$length);
	$station->set_footer;
	print $cgi->header('text/xml');
	$station->print;

