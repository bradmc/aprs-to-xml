package Station;

use strict;
use Time::Local;
use XML::Writer;
use XML::Writer::String;
use DBI;

my $db_host = '';
my $db_name = '';
my $db_user = '';
my $db_pass = '';
my $map_url = 'http://maps.aprsworld.net/mapserver/map.php';

my $loc_db_host = '';
my $loc_db_name = '';
my $loc_db_user = '';
my $loc_db_pass = '';

my $string = new XML::Writer::String;
my $writer = new XML::Writer( DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => $string );
my $dbh = DBI->connect("dbi:mysql:database=$db_name;host=$db_host",$db_user,$db_pass) or die $DBI::errstr;
my $loc_dbh = DBI->connect("dbi:mysql:database=$loc_db_name;host=$loc_db_host",$loc_db_user,$loc_db_pass) or die $DBI::errstr;

# -----------------------------------------
#	Methods
# -----------------------------------------

sub new
{
	# my ($pkg,$call) = @_;
	my ($pkg,%args) = @_;
	bless {
		_call => $args{call},
		_xql  => $args{xql},
		_strip_tags => $args{strip_tags}
	}, $pkg;
}

sub set_header
{
	my $self = shift;
	$writer->xmlDecl( 'UTF-8' );
	$writer->startTag('station');
	my $call = $self->{_call};
	$writer->dataElement('callsign', $call);
}

sub set_footer
{
	$writer->endTag();
	$writer->end();
}

sub print
{
	my $self = shift;
	my $print;
	my $print = $self->{_xql} ? _xql_filter($self->{_xql},$string->value()) : $string->value();
	$print = _strip_tags($print) if $self->{_strip_tags};
	print $print;
}

sub set_last_position
{
	my $self = shift;
	my $sql = qq
	{
		select month(packet_date) as month, dayofmonth(packet_date) as day, year(packet_date) as year,
		hour(packet_date) as hour, minute(packet_date) as minute, second(packet_date) as second,
		latitude,longitude,speed,course,altitude,packet_id,symbol_code,symbol_table
		from lastposition where source=?
	};
	my $sth = $dbh->prepare($sql) || die $dbh->errstr();
	$sth->execute($self->{_call}) or die $DBI::errstr;
	my $rec = $sth->fetchrow_hashref;
	return if !$rec;

	# indented to indicate xml hierarchy
	$writer->dataElement('symbol_table', $rec->{symbol_table} || '');
	$writer->dataElement('symbol_code', $rec->{symbol_code} || '');
	$writer->startTag('position');

		$writer->startTag('latitude');
			$writer->dataElement('degrees', $rec->{latitude} || '');
			$writer->dataElement('degrees_minutes', _convert_latitude($rec->{latitude}));
		$writer->endTag();
		
		$writer->startTag('longitude');
			$writer->dataElement('degrees', $rec->{longitude} || '');
			$writer->dataElement('degrees_minutes', _convert_longitude($rec->{longitude}));
		$writer->endTag();

		$writer->startTag('speed');
			$writer->dataElement('kph', $rec->{speed} || '');
			$writer->dataElement('mph', _convert_kph_to_mph($rec->{speed}));
			$writer->dataElement('knots', _convert_kph_to_knots($rec->{speed}));
		$writer->endTag();
		$writer->startTag('course');
			$writer->dataElement('direction', _get_direction($rec->{course}));
			$writer->dataElement('degrees', $rec->{course} || '');
		$writer->endTag();
		$writer->startTag('altitude');
			$writer->dataElement('meters', $rec->{altitude} || '');
			$writer->dataElement('feet', _convert_meters_to_feet($rec->{altitude}));
		$writer->endTag();
		$writer->startTag('maps');
			$writer->dataElement('street', _get_map_url($self->{_call},$rec->{latitude},$rec->{longitude},$rec->{symbol_code},'street'));
			$writer->dataElement('town', _get_map_url($self->{_call},$rec->{latitude},$rec->{longitude},$rec->{symbol_code},'town'));
			$writer->dataElement('county', _get_map_url($self->{_call},$rec->{latitude},$rec->{longitude},$rec->{symbol_code},'county'));
			$writer->dataElement('regional', _get_map_url($self->{_call},$rec->{latitude},$rec->{longitude},$rec->{symbol_code},'regional'));
		$writer->endTag();
		my $nearest = _get_nearest_loc($rec->{latitude},$rec->{longitude});
		$writer->startTag('nearest');
			$writer->dataElement('name', $nearest->{name} || '');
			$writer->dataElement('state', $nearest->{state} || '');
			$writer->dataElement('country', $nearest->{country} || '');
			$writer->dataElement('distance', $nearest->{distance} || '');
			$writer->dataElement('direction', $nearest->{direction} || '');
		$writer->endTag();
		my $age = _get_age($rec->{hour},$rec->{minute},$rec->{second},$rec->{month},$rec->{day},$rec->{year});
		$writer->startTag('age');
			$writer->dataElement('days', $age->{days});
			$writer->dataElement('hours', $age->{hours});
			$writer->dataElement('minutes', $age->{minutes});
			$writer->dataElement('seconds', $age->{seconds});
		$writer->endTag();
		$writer->startTag('date');
			$writer->dataElement('day', $rec->{day} || '');
			$writer->dataElement('month', $rec->{month} || '');
			$writer->dataElement('year', $rec->{year} || '');
		$writer->endTag();
		$writer->startTag('time');
			$writer->dataElement('hour', $rec->{hour} || '');
			$writer->dataElement('minute', $rec->{minute} || '');
			$writer->dataElement('second', $rec->{second} || '');
		$writer->endTag();
	$writer->endTag();
	$self->{_packet_id} = $rec->{packet_id};
}

sub set_last_weather
{
	my $self = shift;
	my $sql = qq
	{
		select humidity,barometer,temperature,
		wind_direction,wind_speed,wind_gust,wind_sustained
		rain_hour,rain_calendar_day,rain_24hour_day,luminosity
		from lastweather where packet_id=?
	};
	my $sth = $dbh->prepare($sql) || die $dbh->errstr();
	$sth->execute($self->{_packet_id}) or die $DBI::errstr;
	my $rec = $sth->fetchrow_hashref;
	return if !$rec;

	# indented to indicate xml hierarchy
	$writer->startTag('weather');
		$writer->startTag('temperature');
			$writer->dataElement('celsius', $rec->{temperature} || '');
			$writer->dataElement('fahrenheit', _convert_celsius_to_fahrenheit($rec->{temperature}));
		$writer->endTag();
		$writer->dataElement('humidity', $rec->{humidity} || '');
		$writer->startTag('barometer');
			$writer->dataElement('hpa', $rec->{barometer} || '');
			$writer->dataElement('mmhg', _convert_hPa_to_mmHg($rec->{barometer}));
			$writer->dataElement('inhg', _convert_hPa_to_inHg($rec->{barometer}));
		$writer->endTag();
		$writer->dataElement('luminosity', $rec->{luminosity} || '');
		$writer->startTag('wind');
			$writer->startTag('direction');
				$writer->dataElement('degrees', $rec->{wind_direction} || '');
				$writer->dataElement('direction', _get_direction($rec->{wind_direction}));
			$writer->endTag();
			$writer->startTag('speed');
				$writer->dataElement('kph', $rec->{wind_speed} || '');
				$writer->dataElement('mph', _convert_kph_to_mph($rec->{wind_speed}));
				$writer->dataElement('knots', _convert_kph_to_knots($rec->{wind_speed}));
			$writer->endTag();
			$writer->startTag('gust');
				$writer->dataElement('kph', $rec->{wind_gust} || '');
				$writer->dataElement('mph', _convert_kph_to_mph($rec->{wind_gust}));
				$writer->dataElement('knots', _convert_kph_to_knots($rec->{wind_gust}));
			$writer->endTag();
			$writer->startTag('sustained');
				$writer->dataElement('kph', $rec->{wind_sustained} || '');
				$writer->dataElement('mph', _convert_kph_to_mph($rec->{wind_sustained}));
				$writer->dataElement('knots', _convert_kph_to_knots($rec->{wind_sustained}));
			$writer->endTag();
		$writer->endTag();
		$writer->startTag('rain');
			$writer->startTag('hour');
				$writer->dataElement('cm', $rec->{rain_hour} || '');
				$writer->dataElement('in', _convert_cm_to_in($rec->{rain_hour}));
			$writer->endTag();
			$writer->startTag('day_calendar');
				$writer->dataElement('cm', $rec->{rain_calendar_day} || '');
				$writer->dataElement('in', _convert_cm_to_in($rec->{rain_calendar_day}));
			$writer->endTag();
			$writer->startTag('day_24hour');
				$writer->dataElement('cm', $rec->{rain_24hour_day} || '');
				$writer->dataElement('in', _convert_cm_to_in($rec->{rain_24hour_day}));
			$writer->endTag();
		$writer->endTag();
	$writer->endTag();
}

sub set_last_status
{
	my $self = shift;
	my $sql = qq
	{
		select 
		comment,power,height,gain,directivity,rate
		from laststatus where packet_id=?
	};
	my $sth = $dbh->prepare($sql) || die $dbh->errstr();
	$sth->execute($self->{_packet_id}) or die $DBI::errstr;
	my $rec = $sth->fetchrow_hashref;
	return if !$rec;

	# indented to indicate xml hierarchy
	$writer->startTag('status');
		$writer->dataElement('comment', $rec->{comment} || '');
		$writer->dataElement('power', $rec->{power} || '');
		$writer->dataElement('height', $rec->{height} || '');
		$writer->dataElement('gain', $rec->{gain} || '');
		$writer->dataElement('directivity', $rec->{directivity} || '');
		$writer->dataElement('rate', $rec->{rate} || '');
	$writer->endTag();
}


# ----------------------------------------------------------------
#	Internals
# ----------------------------------------------------------------

sub _xql_filter
{
	my ($xql,$xml) = @_;
	use XML::XQL;
	use XML::XQL::DOM;
	my $parser = new XML::DOM::Parser;
	my $doc = $parser->parse($xml);
	my @result = $doc->xql($xql);
	my $return;
	$return .= qq{<?xml version="1.0" encoding="UTF-8"?>\n\n};
	$return .= "<xql:result>\n";
	foreach (@result) { $return .= $_->toString."\n" }
	$return .= "</xql:result>\n";
	return $return;
}

sub _strip_tags
{
	my $string = shift;
	$string =~ s/<.*?[^\/]>//g;
	$string =~ s/^ *(.*?) *$/$1/gm;
	$string =~ tr/\n\n//s;
	$string =~ s/<.*?>//g;
	return $string;
}

sub _get_nearest_loc
{
	my ($lat,$lon) = @_;
	my $sql = qq
	{
		select lat,lon,name,sqrt(pow(lat-$lat,2)+pow(lon-$lon,2))*60 as distance,
		state,country from locations order by distance asc limit 1
	};
	my $sth = $loc_dbh->prepare($sql) || die $loc_dbh->errstr();
	$sth->execute() or die $DBI::errstr;
	my $rec = $sth->fetchrow_hashref;

	# if distance is greater than 100 miles, then return nothing
	return {} if $rec->{distance} > 100;

	my ($lat_dir,$lon_dir) = '';
	if ($lat < $rec->{lat}) {
		$lat_dir = 'S'
	} elsif ($lat > $rec->{lat}) {
		$lat_dir = 'N'
	}
	if ($lon < $rec->{lon}) {
		$lon_dir = 'W'
	} elsif ($lon > $rec->{lon}) {
		$lon_dir = 'E'
	}
	my $direction = "$lat_dir$lon_dir";
	my $distance = sprintf("%1.1f", $rec->{distance});
	my $country = $rec->{country};
	$country =~ s/^\s*(.*)\s*$/$1/g;
	my $state = $rec->{state};
	$state =~ s/[\(|\)]//g;

	return {
		'name' => $rec->{name},
		'state' => $state,
		'country' => $country,
		'distance' => $distance,
		'direction' => $direction,
	};
}

sub _get_map_url
{
	my ($call,$lat,$lon,$icon,$scale) = @_;
	# $icon =~ s/^.//;
	$icon = sprintf("%.3d",ord($icon));
	return "$map_url?lat=$lat&lon=$lon&label=$call&icon=aprs_pri_$icon&scale=$scale";
}

sub _get_age
{
	my ($hour,$minute,$second,$month,$day,$year) = @_;
	my $time = timegm($second, $minute, $hour, $day, $month-1, $year);
	my $timediff = time - $time;
	my $diffdays = int($timediff/86400); $timediff -= $diffdays*86400 if $diffdays >= 1;
	my $diffhours = int($timediff/3600); $timediff -= $diffhours*3600 if $diffhours >= 1;
	my $diffminutes = int($timediff/60); $timediff -= $diffminutes*60 if $diffminutes >= 1;
	my $diffseconds = $timediff;
	return
	{
		'days' => $diffdays,
		'hours' => $diffhours,
		'minutes' => $diffminutes,
		'seconds' => $diffseconds
	};
}

sub _get_direction
{
	my $degrees = shift;
	return '' if !$degrees;
	my $point = int ((($degrees + 11.25) % 360) / 22.5);
	(qw/N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW/)[$point];
}

sub _convert_latitude
{
	my $posit = shift;
	my $dir = ($posit >= 0) ? 'N' : 'S';
	$posit = abs($posit);
	my $degrees = int($posit);
	my $minutes = $posit - $degrees;
	$minutes = sprintf("%.2f", $minutes * 60);
	my $string = "$degrees $minutes $dir";
}

sub _convert_longitude
{
	my $posit = shift;
	my $dir = ($posit >= 0) ? 'E' : 'W';
	$posit = abs($posit);
	my $degrees = int($posit);
	my $minutes = $posit - $degrees;
	$minutes = sprintf("%.2f", $minutes * 60);
	my $string = "$degrees $minutes $dir";
}

sub _convert_kph_to_mph
{
	my $kph = shift;
	return '' if !$kph;
	return int($kph / 1.609344);
}

sub _convert_kph_to_knots
{
	my $kph = shift;
	return '' if !$kph;
	return int($kph / 1.852);
}

sub _convert_meters_to_feet
{
	my $meters = shift;
	return '' if !$meters;
	return int($meters * 3.2808399);
}

sub _convert_celsius_to_fahrenheit
{
	my $celsius = shift;
	return '' if !$celsius;
	return int(($celsius * 1.8) + 32);
}

sub _convert_hPa_to_mmHg
{
	my $hPa = shift;
	return '' if !$hPa;
	return int($hPa * .75006);
}

sub _convert_hPa_to_inHg
{
	my $hPa = shift;
	return '' if !$hPa;
	return sprintf("%1.2f",$hPa * .02953);
}

sub _convert_cm_to_in
{
	my $cm = shift;
	return '' if !$cm;
	return sprintf("%1.2f",$cm * .39370079);
}

1;

