package Apache::GD::Graph;

($VERSION) = '$ProjectVersion: 0.6 $' =~ /\$ProjectVersion:\s+(\S+)/;

=head1 NAME

Apache::GD::Graph - Generate Charts in an Apache handler.

=head1 SYNOPSIS

In httpd.conf:

	PerlModule Apache::GD::Graph

	<Location /chart>
	SetHandler	perl-script
	PerlHandler	Apache::GD::Graph
	# These are optional.
	PerlSetVar	Expires		30 # days.
	PerlSetVar	CacheSize	5242880 # 5 megs.
	</Location>

Then send requests to:

C<http://www.server.com/chart?type=lines&x_labels=[1st,2nd,3rd,4th,5th]&data1=[1,2,3,4,5]&data2=[6,7,8,9,10]&dclrs=[blue,yellow,green]>

=head1 INSTALLATION

Like any other CPAN module, if you are not familiar with CPAN modules, see:
http://www.cpan.org/doc/manual/html/pod/perlmodinstall.html .

=head1 DESCRIPTION

The primary purpose of this module is to allow a very easy to use, lightweight
and fast charting capability for static pages, dynamic pages and CGI scripts,
with the chart creation process abstracted and placed on any server.

For example, embedding a pie chart can be as simple as:

	<img src="http://www.some-server.com/chart?type=pie&x_labels=[greed,pride,wrath]&data1=[10,50,20]&dclrs=[green,purple,red]" alt="pie chart of a few deadly sins">
	<!-- Note that all of the above options are optional except for data1!  -->

And it gets cached both server side, and along any proxies to the client, and
on the client's browser cache. Not to mention, chart generation is
very fast.

It is implemented as a simple Apache mod_perl handler that generates and
returns a png format graph (using Martien Verbruggen's GD::Graph module) based
on the arguments passed in via a query string. It responds with the
content-type "image/png" directly, and sends a Expires: header of 30 days (or
whatever is set via C<PerlSetVar Expires>, in days) ahead. In addition, it
keeps a server-side cache in the file system using DeWitt Clinton's File::Cache
module, whose size can be specified via C<PerlSetVar CacheSize> in bytes.

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
use Apache::Constants qw/OK/;
use HTTP::Date;
use GD::Graph;
use File::Cache;

use constant EXPIRES	=> 30;
use constant CACHE_SIZE	=> 5242880;

use constant TYPE_UNDEF		=> 0;
use constant TYPE_SCALAR	=> 1;
use constant TYPE_ARRAY		=> 2;
use constant TYPE_HASH		=> 3;
use constant TYPE_URL		=> 4;

# Sub prototypes:

sub handler ($);
sub parse ($;$);
sub error ($);
sub makeDir ($);

# Subs:

sub handler ($) {
	my $r = shift;
	$r->request($r);

# Files to delete after request is processed.
	my @cleanup_files;

	eval {
# Calculate Expires header based on either the Expires configuration variable
# (via PerlSetVar) or the EXPIRES constant, in days. Then convert into seconds
# and round to an integer.
		my $expires = 0+($r->dir_config('Expires')) || EXPIRES;
		$expires   *= 24 * 60 * 60;
		$expires    = sprintf ("%d", $expires);

		my $image_cache = new File::Cache ( {
			namespace	=> 'Images',
			max_size	=> 0+($r->dir_config('CacheSize')) ||
					   CACHE_SIZE,
			filemode	=> 0660
		} );

		my $params = scalar $r->args;

		if (my $cached_image = $image_cache->get($params)) {
			$r->header_out (
				"Expires" => time2str(time + $expires)
			);
			$r->send_http_header("image/png");
			$r->print($cached_image);

			return OK;
		}

		my %args = $r->args;

		my $type   = delete $args{type}   || 'lines';
		my $width  = delete $args{width}  || 400;
		my $height = delete $args{height} || 300;

		$type =~ m/^(\w+)$/;
		$type = $1;	# untaint it!

		my $x_labels = parse delete $args{x_labels}
			if exists $args{x_labels};

		my @data;
		my $key = "data1";
		while (exists $args{$key}) {
			push @data, parse delete $args{$key};
			$key++;
		}

		error "Please supply at least a data1 argument."
			if ref $data[0] ne 'ARRAY';

		my $length = scalar @{$data[0]};

		error "data1 empty!" if $length == 0;

# Validate the sizes in order to have a more friendly error.
		if ( (not defined $x_labels) || scalar @$x_labels == 0) {
			$x_labels = [1..$length];
		} elsif (scalar @$x_labels != $length) {
			error (
			 "Size of x_labels not the same as length of data."
			);
		}

		my $n = 2;
		for (@data[1..$#data]) {
			if (scalar @$_ != $length) {
				error (
				 "Size of data$n does not equal size of data1."
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
		 error (
		  "Could not create an instance of class GD::Graph::$type: $@"
		 );
		}

		for my $option (keys %args) {
			my ($value, $type) = parse ($args{$option});
			$args{$option}	   = $value;

			if ($type == TYPE_URL) {
				push @cleanup_files, $args{$option};
			}
		};

		$graph->set(%args);

		my $image = $graph->plot([$x_labels, @data])->png;
		$r->header_out("Expires" => time2str(time + $expires));
		$r->send_http_header("image/png");
		$r->print($image);

		$image_cache->set($params, $image);

	}; if ($@) {
		$r->log_error (__PACKAGE__.': '.$@);
	}

	if (@cleanup_files) {
		unlink @cleanup_files or
			$r->log_error (__PACKAGE__.': '.
			"Could not delete files: @cleanup_files, reason: $!");
	}

	return OK;
}

# Parse a datum into a scalar, arrayref or hashref. Using the following semi
# perl-like syntax:
#
# undef		  -- a real undef
# foo_bar         -- a scalar
# [1,2,3,foo,bar] -- an array
# {1,2,3,foo}     -- a hash
# or
# http://some/url.png -- pull a URL into a file, returning that. The file will
# be relative to a directory given as the second parameter, or /tmp if not
# specified.
sub parse ($;$) {
	local $_ = shift;
	my $dir  = shift || '/tmp';

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
		$file_name = $dir."/".$file_name;

		my $file = new IO::File "> ".$file_name or
			error "Could not open $file_name for writing: $!";
		binmode $file;
		print $file get($url);
		return $file_name;
	}

	return $_;
}

# Display an error message and throw exception.
sub error ($) {
	my $message = shift;
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
</html>
EOF
	die $message;
}

1;

__END__

=head1 AUTHOR

Rafael Kitover (caelum@debian.org)

=head1 COPYRIGHT

This program is Copyright (c) 2000 by Rafael Kitover. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=head1 ACKNOWLEDGEMENTS

This module owes its existance, obviously, to the availability of the wonderful
GD::Graph module from Martien Verbruggen.

Thanks to my employer, marketingmoney.com, for allowing me to work on projects
as free software.

Thanks to Vivek Khera for the bug fixes.

=head1 BUGS

Probably a few.

=head1 TODO

More extensive test suite.
Need to be easily able to generate graphs without axes.

=head1 SEE ALSO

L<perl>,
L<GD::Graph>,
L<GD>

=cut
