#!/usr/bin/perl

use strict;
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use XML::XML2JSON;


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
		$station->set_last_status;
		$station->set_station_footer;
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

	my $json = XML::XML2JSON->new();
	print $json->xml2json($station->value);


