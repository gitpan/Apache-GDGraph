package Apache::GD::Graph;

($VERSION) = '$ProjectVersion: 0.2 $' =~ /\$ProjectVersion:\s+(\S+)/;

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

http://www.your-server.com/chart?type=lines&x_labels=1st,2nd,3rd,4th,5th&x_values=1,2,3,4,5&y_values=6,7,8,9,10

=head1 DESCRIPTION

This is a simple Apache mod_perl handler that generates and returns a png
format graph based on the arguments passed in via a query string. It responds
with the content-type "image/png" directly, and sends a Expires: header of 30
days ahead (since the same query string generates the same graph, they can be
cached). In addition, it keeps a server-side cache under /tmp/graph-(PID) for
the lifetime of the Apache process. (These are safe to periodically clean out
with a cron job).

=head1 OPTIONS

=over 8

=item B<type>

Type of graph to generate, can be lines, bars, points, linespoints, area,
mixed, pie. For a description of these, see L<GD::Graph(3)>.

=item B<width>

Width of graph in pixels.

=item B<height>

Height of graph in pixels.

=back

For the following three, look at the plot method in L<GD::Graph(3)>.

=over 8

=item B<x_labels>

Labels used on the X axis, the first array given to the plot method of
GD::Graph.

=item B<x_values>

Values to plot for x.

=item B<y_values>

Values to plot for y.

=back

ALL OTHER OPTIONS are passed as a hash to the GD::Graph set method.

=cut

use strict;
use Apache;
use HTTP::Date;
use GD::Graph;
use GD::Graph::lines;
use GD::Graph::bars;
use GD::Graph::points;
use GD::Graph::linespoints;
use GD::Graph::area;
use GD::Graph::mixed;
use GD::Graph::pie;

use constant THIRTY_DAYS => 60*60*24*30;
use constant DIR         => "/tmp/graph-$$/";

# Create directory on load.
mkdir DIR, 0777;
chown Apache->server->uid, Apache->server->gid, DIR;

# And delete on process exit.
END {
	if (-d DIR) {
		system "rm -rf ".DIR;
	}
}

sub handler {
	my $r = shift;
	Apache->request($r);
	my $cached_name = DIR.$r->args.'.png';

	if (-e $cached_name) {
		local $/ = undef;
		$r->header_out("Expires" => time2str(time + THIRTY_DAYS));
		$r->send_http_header("image/png");
		$r->print((new IO::File $cached_name)->getlines());
		return 1;
	}

	my %args = $r->args;

	my $type   = delete $args{type}   || 'lines';
	my $width  = delete $args{width}  || 400;
	my $height = delete $args{height} || 300;

	my $x_labels = [ split /,/, delete $args{x_labels} ]
		|| [ qw( 1st 2nd 3rd 4th 5th ) ];

	my $x_values = [ split /,/, delete $args{x_values} ]
		|| [1..5];

	my $y_values = [ split /,/, delete $args{y_values} ]
		|| [1..5];

	my $graph;
	eval {
		no strict 'refs';
		$graph = ('GD::Graph::'.$type)->new($width, $height);
	}; if ($@) {
		error (
		 $r,
		 "Could not create an instance of class GD::Graph::$type: $@"
		);
	}

	$graph->set(%args);

	my $image = $graph->plot([$x_labels, $x_values, $y_values])->png;
	$r->header_out("Expires" => time2str(time + THIRTY_DAYS));
	$r->send_http_header("image/png");
	$r->print($image);

	my $cache = new IO::File ">$cached_name"
		or error($r, "Could not open $cached_name for writing: $!");

	print $cache $image;
	close $cache;

	return 1;
}

sub error {
	my ($r, $message) = @_;
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

Let me know.

=head1 SEE ALSO

L<perl(1)>,
L<GD::Graph(3)>,
L<GD(3)>,

=cut
