package Apache::GD::Graph;

($VERSION) = '$ProjectVersion: 0.4 $' =~ /\$ProjectVersion:\s+(\S+)/;

=head1 NAME

Apache::GD::Graph - Generate Charts in an Apache handler.

=head1 SYNOPSIS

In httpd.conf:

	PerlModule Apache::GD::Graph

	<Location /chart>
	SetHandler perl-script
	PerlHandler Apache::GD::Graph
	</Location>

Then send requests to:

C<http://www.server.com/chart?type=lines&x_labels=[1st,2nd,3rd,4th,5th]&data1=[1,2,3,4,5]&data2=[6,7,8,9,10]&dclrs=[blue,yellow,green]>

=head1 DESCRIPTION

This is a simple Apache mod_perl handler that generates and returns a png
format graph based on the arguments passed in via a query string. It responds
with the content-type "image/png" directly, and sends a Expires: header of 30
days ahead (since the same query string generates the same graph, they can be
cached). In addition, it keeps a server-side cache under
/var/cache/Apache::GD::Graph .

=head1 OPTIONS

=over 8

=item B<type>

Type of graph to generate, can be lines, bars, points, linespoints, area,
mixed, pie. For a description of these, see L<GD::Graph(3)>. Can also be one of
the 3d types if GD::Graph3d is installed, or anything else with prefix
GD::Graph::.

=item B<width>

Width of graph in pixels, 400 by default.

=item B<height>

Height of graph in pixels, 300 by default.

=back

For the following, look at the plot method in L<GD::Graph(3)>.

=over 8

=item B<x_labels>

Labels used on the X axis, the first array given to the plot method of
GD::Graph.

=item B<dataN>

Values to plot, where N is a number starting with 1. Can be given any number of
times with N increasing.

=back

ALL OTHER OPTIONS are passed as a hash to the GD::Graph set method using the
following rules for the values:

=over 8

=item B<undef>

Becomes a real undef.

=item B<[one,two,3]>

Becomes an array reference.

=item B<{one,1,two,2}>

Becomes a hash reference.

=item B<http://somewhere/file.png>

Is pulled into a file and the file name is passed to the respective option.
(Can be any scheme besides http:// that LWP::Simple supports.)

=back

=cut

use strict;
use Apache;
use HTTP::Date;
use GD::Graph;

use constant THIRTY_DAYS => 60*60*24*30;
use constant DIR         => "/var/cache/Apache::GD::Graph/";

BEGIN {
	my $server = Apache->can('server');

	if (!-d DIR && $server) {
		system "mkdir -p ".DIR;
		chmod 0755, DIR;
		chown $server->uid, $server->gid, DIR;
	}
}

sub handler {
	my $r = shift;
	Apache->request($r);
	my $cached_name = $r->args;
	$cached_name    =~ s|/|\%2f|g;
	$cached_name    = DIR."/".$cached_name.".png";

	if (-e $cached_name) {
		local $/ = undef;
		$r->header_out("Expires" => time2str(time + THIRTY_DAYS));
		$r->send_http_header("image/png");
# Slurp the whole thing out.
		{local (@ARGV,$/) = $cached_name; $r->print(<>)}
		return 1;
	}

	my %args = $r->args;

	my $type   = delete $args{type}   || 'lines';
	my $width  = delete $args{width}  || 400;
	my $height = delete $args{height} || 300;

	my $x_labels = parse (delete $args{x_labels})
		if exists $args{x_labels};

	my @data;
	my $key = "data1";
	while (exists $args{$key}) {
		push @data, parse (delete $args{$key});
		$key++;
	}

	return error("Please supply at least a data1 argument.")
		if ref $data[0] ne 'ARRAY';

	my $length = scalar @{$data[0]};

	return error("data1 empty!") if $length == 0;

# Validate the sizes in order to have a more friendly error.
	if ( (not defined $x_labels) || scalar @$x_labels == 0) {
		$x_labels = [1..$length];
	} elsif (scalar @$x_labels != $length) {
		return error (
		 "Size of x_labels not the same as length of data."
		);
	}

	my $n = 2;
	for (@data[1..$#data]) {
		if (scalar @$_ != $length) {
			return error (
			 "Size of data$n not the same as size of data1."
			);
		}
		$n++;
	}

	my $graph;
	eval {
		no strict 'refs';
		require "GD/Graph/$type.pm";
		$graph = ('GD::Graph::'.$type)->new($width, $height);
	}; if ($@) {
		return error (
		 "Could not create an instance of class GD::Graph::$type: $@"
		);
	}

	$args{$_} = parse ($args{$_}) for (keys %args);

	$graph->set(%args);

	my $image = $graph->plot([$x_labels, @data])->png;
	$r->header_out("Expires" => time2str(time + THIRTY_DAYS));
	$r->send_http_header("image/png");
	$r->print($image);

	my $cache = new IO::File ">$cached_name"
		or return error("Could not open $cached_name for writing: $!");

	binmode $cache;	# For win32 compatability.
	print $cache $image;
	close $cache;

	return 1;
}

# Parse a datum into a scalar, arrayref or hashref. Using the following semi
# perl-like syntax:
#
# undef		  -- a real undef
# foo_bar         -- a scalar
# [1,2,3,foo,bar] -- an array
# {1,2,3,foo}     -- a hash
# or
# http://some/url.png -- pull a URL into a file, returning that.
sub parse ($) {
	local $_ = shift;

	if ($_ eq 'undef') {
		return undef;
	}

	if (/^\[(.*)\]$/) {
		return [ split /,/, $1 ];
	}

	if (/^\{(.*)\}$/) {
		return { split /,/, $1 };
	}

	if (m!^\w+://!) {
		use LWP::Simple;

		my ($url, $file_name) = ($_, $_);
		$file_name =~ s|/|\%2f|g;
		$file_name = DIR."/".$file_name;

		my $file = new IO::File "> ".$file_name or
			error ("Could not open $file_name for writing: $!");
		binmode $file;
		print $file get($url);
		return $file_name;
	}

	return $_;
}

# Print an error message.
sub error ($) {
	my ($message) = @_;
	my $r = Apache->request;
	$r->send_http_header("text/html");
	$r->print(<<"EOF");
<html>
<head></head>
<body>
<font color="red"><h1>Error:</h1></font>
<p>
$message
</body>
EOF
	return 1;
}

1;

__END__

=head1 AUTHOR

Rafael Kitover (caelum@debian.org)

=head1 COPYRIGHT

This program is Copyright (c) 2000 by Rafael Kitover. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=head1 BUGS

Probably a few.

=head1 TODO

Configuration of cache dirs, value of the expires header and other options via
PerlSetEnv directives in httpd.conf.

Perhaps using mod_proxy for caching entirely, or improving this scheme to be
more intelligent.

Let me know.

=head1 SEE ALSO

L<perl(1)>,
L<GD::Graph(3)>,
L<GD(3)>,

=cut
