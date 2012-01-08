# --------------------
#	Modules
# --------------------

	use Time::Local;
	use XML::Writer;
	use XML::Writer::String;
	use CGI;
	use DBI;

# --------------------
#	Config
# --------------------

	my $db_host = 'www2.findu.com';
	my $db_name = 'aprs';
	my $db_user = 'n8qq';
	my $db_pass = 'xmlproj';

	my $map_url = 'http://maps.aprsworld.net/mapserver/map.php';

# --------------------
#	Init
# --------------------

	use vars qw($cgi $string $writer $dbh);
	$cgi = new CGI;
	$string = new XML::Writer::String;
	$writer = new XML::Writer( DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => $string );
	$dbh = DBI->connect("dbi:mysql:database=$db_name;host=$db_host",$db_user,$db_pass) or die $DBI::errstr;

# --------------------
#	Routines
# --------------------

sub get_last_position
{
	my ($call) = @_;
	my $sql = qq
	{
		select month(time_rx) as month, dayofmonth(time_rx) as day, year(time_rx) as year,
		hour(time_rx) as hour, minute(time_rx) as minute, second(time_rx) as second,
		lat,lon,icon,speed,course,altitude
		from lastposit where call=?
	};
	my $sth = $dbh->prepare($sql) || die $dbh->errstr();
	$sth->execute($call) or die $DBI::errstr;
	my $rec = $sth->fetchrow_hashref;
	return if !$rec;
	$writer->startTag('position');
	$writer->startTag('report');
	$writer->dataElement('latitude', $rec->{lat});
	$writer->dataElement('longitude', $rec->{lon});
	$writer->dataElement('icon', $rec->{icon});
	$writer->dataElement('speed', $rec->{speed});
	$writer->dataElement('direction', get_direction($rec->{course}));
	$writer->dataElement('course', $rec->{course});
	$writer->dataElement('altitude', $rec->{altitude});

	$writer->startTag('maps');
	$writer->dataElement('street', get_map_url($call,$rec->{lat},$rec->{lon},$rec->{icon},'street'));
	$writer->dataElement('town', get_map_url($call,$rec->{lat},$rec->{lon},$rec->{icon},'town'));
	$writer->dataElement('regional', get_map_url($call,$rec->{lat},$rec->{lon},$rec->{icon},'regional'));
	$writer->endTag();

	my $nearest = get_nearest_loc($rec->{lat},$rec->{lon});
	$writer->startTag('nearest');
	$writer->dataElement('name', $nearest->{name});
	$writer->dataElement('state', $nearest->{state});
	$writer->dataElement('country', $nearest->{country});
	$writer->dataElement('distance', $nearest->{distance});
	$writer->dataElement('direction', $nearest->{direction});
	$writer->endTag();

	my $age = get_age($rec->{hour},$rec->{minute},$rec->{second},$rec->{month},$rec->{day},$rec->{year});
	$writer->startTag('age');
	$writer->dataElement('days', $age->{days});
	$writer->dataElement('hours', $age->{hours});
	$writer->dataElement('minutes', $age->{minutes});
	$writer->dataElement('seconds', $age->{seconds});
	$writer->endTag();

	$writer->startTag('date');
	$writer->dataElement('day', $rec->{day});
	$writer->dataElement('month', $rec->{month});
	$writer->dataElement('year', $rec->{year});
	$writer->endTag();
	$writer->startTag('time');
	$writer->dataElement('hour', $rec->{hour});
	$writer->dataElement('minute', $rec->{minute});
	$writer->dataElement('second', $rec->{second});
	$writer->endTag();

	$writer->endTag();
	$writer->endTag();
}

sub get_last_wx
{
	my ($call) = @_;
	my $sql = qq
	{
		select month(time_rx) as month, dayofmonth(time_rx) as day, year(time_rx) as year,
		hour(time_rx) as hour, minute(time_rx) as minute, second(time_rx) as second,
		humidity,barometer,comment,temp,direction,speed,gust,rain1h,rain24h,rainmn
		from weather where call=? and
		time_rx between date_sub(now(), interval 5 day) and now()
		order by time_rx desc limit 1
	};
	my $sth = $dbh->prepare($sql) || die $dbh->errstr();
	$sth->execute($call) or die $DBI::errstr;
	my $rec = $sth->fetchrow_hashref;
	return if !$rec;
	$writer->startTag('weather');
	$writer->startTag('report');
	$writer->dataElement('temperature', $rec->{temp});
	$writer->dataElement('humidity', $rec->{humidity});
	$writer->dataElement('barometer', $rec->{barometer});
	$writer->dataElement('comment', $rec->{comment});
	$writer->startTag('wind');
	$writer->dataElement('direction', $rec->{direction});
	$writer->dataElement('speed', $rec->{speed});
	$writer->dataElement('gust', $rec->{gust});
	$writer->endTag();
	$writer->startTag('rain');
	$writer->dataElement('hours1', $rec->{rain1h});
	$writer->dataElement('hours24', $rec->{rain24h});
	$writer->dataElement('month', $rec->{rainmn});
	$writer->endTag();
	$writer->startTag('date');
	$writer->dataElement('day', $rec->{day});
	$writer->dataElement('month', $rec->{month});
	$writer->dataElement('year', $rec->{year});
	$writer->endTag();
	$writer->startTag('time');
	$writer->dataElement('hour', $rec->{hour});
	$writer->dataElement('minute', $rec->{minute});
	$writer->dataElement('second', $rec->{second});
	$writer->endTag();
	$writer->endTag();
	$writer->endTag();
}

sub get_positions
{
	my ($call,$start,$length) = @_;
	my $sql = qq
	{
		select month(time_rx) as month, dayofmonth(time_rx) as day, year(time_rx) as year,
		hour(time_rx) as hour, minute(time_rx) as minute, second(time_rx) as second,
		lat,lon,icon,speed,course,altitude
		from position where call=? and
		time_rx between date_sub(now(), interval $start hour)
		and date_sub(now(), interval $start-$length hour)
		order by time_rx asc
	};
	my $sth = $dbh->prepare($sql) || die $dbh->errstr();
	$sth->execute($call) or die $DBI::errstr;
	$writer->startTag('position');
	while (my $rec = $sth->fetchrow_hashref)
	{
		return if !$rec;
		$writer->startTag('report');
		$writer->dataElement('latitude', $rec->{lat});
		$writer->dataElement('longitude', $rec->{lon});
		$writer->dataElement('icon', $rec->{icon});
		$writer->dataElement('speed', $rec->{speed});
		$writer->dataElement('course', $rec->{course});
		$writer->dataElement('altitude', $rec->{altitude});
		$writer->startTag('date');
		$writer->dataElement('day', $rec->{day});
		$writer->dataElement('month', $rec->{month});
		$writer->dataElement('year', $rec->{year});
		$writer->endTag();
		$writer->startTag('time');
		$writer->dataElement('hour', $rec->{hour});
		$writer->dataElement('minute', $rec->{minute});
		$writer->dataElement('second', $rec->{second});
		$writer->endTag();
		$writer->endTag();
	}
	$writer->endTag();
}

sub get_wx_reports
{
	my ($call,$start,$length) = @_;
	my $sql = qq
	{
		select month(time_rx) as month, dayofmonth(time_rx) as day, year(time_rx) as year,
		hour(time_rx) as hour, minute(time_rx) as minute, second(time_rx) as second,
		humidity,barometer,comment,temp,direction,speed,gust,rain1h,rain24h,rainmn
		from weather where call=? and
		time_rx between date_sub(now(), interval $start hour)
		and date_sub(now(), interval $start-$length hour)
		order by time_rx asc
	};
	my $sth = $dbh->prepare($sql) || die $dbh->errstr();
	$sth->execute($call) or die $DBI::errstr;
	$writer->startTag('weather');
	while (my $rec = $sth->fetchrow_hashref)
	{
		return if !$rec;
		$writer->startTag('report');
		$writer->dataElement('temperature', $rec->{temp});
		$writer->dataElement('humidity', $rec->{humidity});
		$writer->dataElement('barometer', $rec->{barometer});
		$writer->dataElement('comment', $rec->{comment});
		$writer->startTag('wind');
		$writer->dataElement('direction', $rec->{direction});
		$writer->dataElement('speed', $rec->{speed});
		$writer->dataElement('gust', $rec->{gust});
		$writer->endTag();
		$writer->startTag('rain');
		$writer->dataElement('hours1', $rec->{rain1h});
		$writer->dataElement('hours24', $rec->{rain24h});
		$writer->dataElement('month', $rec->{rainmn});
		$writer->endTag();
		$writer->startTag('date');
		$writer->dataElement('day', $rec->{day});
		$writer->dataElement('month', $rec->{month});
		$writer->dataElement('year', $rec->{year});
		$writer->endTag();
		$writer->startTag('time');
		$writer->dataElement('hour', $rec->{hour});
		$writer->dataElement('minute', $rec->{minute});
		$writer->dataElement('second', $rec->{second});
		$writer->endTag();
		$writer->endTag();
	}
	$writer->endTag();
}

# ----------------------------------------------------------------
#	Support
# ----------------------------------------------------------------

sub get_nearest_loc
{
	my ($lat,$lon) = @_;
	my $sql = qq
	{
		select lat,lon,name,sqrt(pow(lat-$lat,2)+pow(lon-$lon,2))*60 as distance,
		county,state,country from names order by distance asc limit 1
	};
	my $sth = $dbh->prepare($sql) || die $dbh->errstr();
	$sth->execute() or die $DBI::errstr;
	my $rec = $sth->fetchrow_hashref;

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


	return {
		'name' => $rec->{name},
		'state' => $rec->{state},
		'country' => $country,
		'distance' => $distance,
		'direction' => $direction,
	};
}

sub get_map_url
{
	my ($call,$lat,$lon,$icon,$scale) = @_;
	$icon =~ s/^.//; my $icon = sprintf("%.3d",ord($icon));
	return "$map_url?lat=$lat&lon=$lon&label=$call&icon=aprs_pri_$icon&scale=$scale";
}

sub get_age
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

sub get_direction
{
	my $degrees = shift;
	return '' if !$degrees;
	my $point = int ((($degrees + 11.25) % 360) / 22.5);
	(qw/N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW/)[$point];
}

sub convert_latitude
{
	my $posit = shift;
	my $dir = ($posit >= 0) ? 'N' : 'S';
	$posit = abs($posit);
	my $degrees = int($posit);
	my $minutes = $posit - $degrees;
	$minutes = sprintf("%.2f", $minutes * 60);
	my $string = "$degrees $minutes $dir";
}

sub convert_longitude
{
	my $posit = shift;
	my $dir = ($posit >= 0) ? 'E' : 'W';
	$posit = abs($posit);
	my $degrees = int($posit);
	my $minutes = $posit - $degrees;
	$minutes = sprintf("%.2f", $minutes * 60);
	my $string = "$degrees $minutes $dir";
}


1;

