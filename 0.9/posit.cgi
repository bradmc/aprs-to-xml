#!/usr/bin/perl

use strict;
use CGI::Carp qw(fatalsToBrowser);
use vars qw($cgi $string $writer $dbh);
require "lib.pl";

# --------------------
#	Init
# --------------------

	my ($call,$start,$length);

	$call = $cgi->param('call');
	$start = $cgi->param('start');
	$length = $cgi->param('length');

	$call =~ tr/a-z/A-Z/;
	$start = ($start and ($start > 0)) ? int($start) : 24;
	$length = ($length and ($length > 0)) ? int($length) : $start;

# --------------------
#	Main
# --------------------

	$writer->xmlDecl( 'UTF-8' );
	$writer->startTag('station');
	$writer->dataElement('call', $call);
	get_positions($call,$start,$length);
	$writer->endTag();
	$writer->end();

	print $cgi->header('text/xml');
	print $string->value();

