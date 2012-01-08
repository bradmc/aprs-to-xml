#!/usr/bin/perl

use strict;
use CGI::Carp qw(fatalsToBrowser);
use vars qw($cgi $string $writer $dbh);
require "lib.pl";

# --------------------
#	Init
# --------------------

	my $call = $cgi->param('call');
	$call =~ tr/a-z/A-Z/;

# --------------------
#	Main
# --------------------


	$writer->xmlDecl( 'UTF-8' );
	$writer->startTag('station');
	$writer->dataElement('call', $call);
	get_last_position($call);
	$writer->endTag();
	$writer->end();

	print $cgi->header('text/xml');
	print $string->value();

