package Apache::GD::Graph;

$VERSION = 0.92;

=head1 NAME

Apache::GD::Graph - Generate Graphs in an Apache handler.

=head1 SYNOPSIS

In httpd.conf:

	<Location /chart>
	SetHandler	perl-script
	PerlHandler	+Apache::GD::Graph
	# These are optional.
	#PerlSetVar	Expires		30	# days default.
	#PerlSetVar	CacheSize	5242880	# 5 megs default.
	#PerlSetVar	ImageType	png	# Default.
	# The default image type that graphs should be.
	# png is default, gif requires <= GD 1.19.
	# Any type supported by the installed version of GD will work.
	#
	# The next specifies the quality of generated JPEG images, best not to
	# specify this one and let GD figure it out.
	#PerlSetVar	JpegQuality	75 # 0 to 100
	# TTFFontPath tells GD::Text where to look for true type fonts. The
	# example here is the default value used.
	#PerlSetVar	TTFFontPath	/usr/ttfonts:/var/ttfonts:/usr/X11R6/lib/X11/fonts/ttf/:/usr/X11R6/lib/X11/fonts/truetype/:/usr/share/fonts/truetype
	</Location>

Then send requests to:

	http://www.server.com/chart?type=lines&x_labels=[1st,2nd,3rd,4th,5th]&
	data1=[1,2,3,4,5]&data2=[6,7,8,9,10]&dclrs=[blue,yellow,green]>

Options can also be sent as x-www-form-urlencoded data (ie., a form). This
works better for large data sets, and allows simple charting forms to be set
up. IE, for example, does not allow query strings larger than a kilobyte.
Parameters in the query string take precedence over a form if specified.

=head1 INSTALLATION

Like any other CPAN module, if you are not familiar with CPAN modules, see:
http://www.cpan.org/doc/manual/html/pod/perlmodinstall.html

MAKE SURE TO RESTART YOUR APACHE SERVER using C<apachectl graceful> after
upgrading this or any other Apache Perl module.

=head1 DESCRIPTION

The primary purpose of this module is to allow a very easy to use, lightweight
and fast charting capability for static pages, dynamic pages and CGI scripts,
with the chart creation process abstracted and placed on any server.

For example, embedding a pie chart can be as simple as:

	<img src="http://www.some-server.com/chart?type=pie&
	x_labels=[greed,pride,wrath]&data1=[10,50,20]&dclrs=[green,purple,red]"
	alt="pie chart of a few deadly sins">
	<!-- Note that all of the above options are optional except for data1!  -->

And it gets cached both server side, and along any proxies to the client, and
on the client's browser cache. Not to mention, chart generation is
very fast.

Of course, more complex things will be better done directly in your own Perl
handlers, but this module allows a non-Perl environment to have access to the
capabilities of GD::Graph.

Another solution is to use ASP scripting with Microsoft Excel, which of course
requires a Windows NT server and I have no idea how easy this is to do, or how
fast.

There are also many other ways to connect programs with charting capabilities,
such as GNUPlot, or rrdtool to a web server. These may or may not be
faster/more featureful etc.

=head1 TIPS

Most more complicated things depend on knowing the GD::Graph interface.

Firstly, B<make sure you are not using any spaces!> If you want to pass a space in
a parameter in a URL-encoded string, use C<%20>, in a form use a C<+>.

Make sure to use C<cache=0> or C<PerlSetVar CacheSize 0> when debugging,
otherwise you will spend hours being very confused.

=head1 FONTS

GD::Graph has some options that take a font description, such as title_font,
legend_font, etc. (these map to the appropriate set_FOO methods in GD::Graph,
see that manpage). See the TTFFontPath variable under SYNOPSIS for how to set
the search path for fonts. MAKE SURE your fonts are readable by the user the
Apache server runs under, this is usually "www-data" or "nobody". Otherwise
your fonts will mysteriously fail with no notice.

Sizes can be specified by using a list with the name and size. For example, if
arial.ttf can be found somewhere in your TTFFontPath, you can do:

	...title_font=(arial.ttf,20)

To get a title using font Arial, in 20 points.

Note that GD::Text does not parse out the names of fonts and such, you have to
give it an actual filename, in the right case. So if using the Microsoft
Windows core fonts, Arial Bold would be C<arialbd.ttf>. Here's an example:

	http://server/chart?data1=[1,2,3,4,5]&title_font=(arialbd.ttf,20)&title=Just%20A%20Line

=head1 IMAGES

You can place a logo in any corner of the graph using the C<logo>,
C<logo_resize> and C<logo_position> options. See L<GD::Graph>. If you just want
a background image that is resized to fit your graph, see the
C<background_image> option herein.

=head1 TEXT/CAPTIONS

The following GD::Graph options control placing text on the graph: title,
x_label and y_label. L<GD::Graph> for those and related options. In addition,
this modules allows you to use the captionN option(s), to draw arbitrary
strings on the graph. See below.

=head1 IMPLEMENTATION

This module is implemented as a simple Apache mod_perl handler that generates
and returns a png format graph (using Martien Verbruggen's GD::Graph module)
based on the arguments passed in via a query string. It responds with the
content-type "image/png" (or whatever is set via C<PerlSetVar ImageType>), and
sends a Expires: header of 30 days (or whatever is set via C<PerlSetVar
Expires>, or expires in the query string, in days) ahead.

In addition, it keeps a server-side cache in the file system using DeWitt
Clinton's File::Cache module, whose size can be specified via C<PerlSetVar
CacheSize> in bytes.

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

=item B<expires>

Date of Expires header from now, in days. Same as C<PerlSetVar Expires>.

=item B<image_type>

Same as C<PerlSetVar ImageType>. "png" by default, but can be anything
supported by GD.

If not specified via this option or in the config file, the image type can also
be deduced from a single value in the 'Accept' header of the request.

=item B<jpeg_quality>

Same as C<PerlSetVar JpegQuality>. A number from 0 to 100 that determines the
jpeg quality and the size. If not set at all, the GD library will determine the
optimal setting. Changing this value doesn't seem to do much as far as line
graphs go, but YMMV.

=item B<background_image>

Set an image as the background for the graph. You are responsible for choosing
a sane image to go with your graph, the background should be either transparent
or the same color you will use. This is the same as using the C<logo> parameter
with an image of the same size as the graph, except this option will resize the
image if necessary, making it more convenient for this purpose. The file or URL
can be of any type your copy of GD supports.

=item B<captionN>

Draws a character string using a TrueType font at an arbitrary location.  Takes
an array of C<($fgcolor,$fontname,$ptsize,$angle,$x,$y,$string)> where $fgcolor
is the foreground color, $fontname is the name of a TTF font see L</FONTS> ,
$ptsize is the point size, $x and $y are the coordinates, and $string is the
actual characters to draw.

N is an integer from 1 onward, like for the dataN option. This lets you specify
multiple strings to draw.

This follows exactly the GD stringTTF method, see L<GD>.

Angle is in degrees, you will primarily use angle C<0> for normal left-to-right
text. $x and $y are pixel coordinates from the upper left corner. $fontname is
the name of a true-type font that will be found in the font path (see FONTS).
Example:

	http://isis/chart?data1=[1,2,3,4,5]&caption1=(1,arial.ttf,9,0,30,30,Hello)

=item B<cache>

Boolean value which determines whether or not the image will get cached
server-side (for client-side caching, use the "expires" parameter). It is true
(1) by default. Setting C<PerlSetVar CacheSize 0> in the config file will
achieve the same affect as C<cache=0> in the query string.

=item B<to_file>

The graph will not be sent back, but instead saved to the file indicated on the
server. Apache will need permission to write to that directory. The result will
not be cached. This is basically the same as making an RPC call to a Perl
process to make a graph and store it to a file.

=item B<no_axes>

This sets x_labels to an empty lists and sets y_number_format to "",
effectively disabling axes labels.

=back

For the following, look at the plot method in L<GD::Graph(3)>.

=over 8

=item B<x_labels>

Labels used on the X axis, the first array given to the plot method of
GD::Graph. If unspecified or undef, no labels will be drawn.

=item B<dataN>

Values to plot, where N is a number starting with 1. Can be given any number of
times with N increasing.

=back

ALL OTHER OPTIONS are passed to the corresponding set_<option> method, or the
set(<option hash>) method using the following rules for the values:

=over 8

=item B<undef>

Becomes a real undef.

=item B<[one,two,3]>

Becomes an array reference.

=item B<(one,two,3)>

This becomes a list, you can pass lists to set_SOMETHING methods of GD::Graph,
if there is no corresponding set_ method, the list will be silently converted
to an anonymous array and used in an ordinary option.

=item B<{one,1,two,2}>

Becomes a hash reference.

=item B<http://somewhere/file.png>

Is pulled into a file and the file name is passed to the respective option.
(Can be any scheme besides http:// that LWP::Simple supports.)

=item B<[undef,something,undef] or {key,undef}>

You can create an array or hash with undefs.

=item B<['foo',bar] or 'baz' or {'key','value'}>

Single and double quoted strings are supported, either as singleton values or
inside arrays and hashes.

DON'T USE SPACES, this is a common mistake. A space in a URL-encoded string is
%20, or a + in a form.

Nested structures are still not supported, maybe later.

=back

=cut

use strict;
use Apache;
use Apache::Constants qw/OK/;
use HTTP::Date;
use GD;
use GD::Text;
use GD::Graph;
use GD::Graph::colour;
use File::Cache;

use constant EXPIRES	=> 30;
use constant CACHE_SIZE	=> 5242880;
use constant IMAGE_TYPE => 'png';
use constant TTF_FONT_PATH	=> '/usr/ttfonts:/var/ttfonts:/usr/X11R6/lib/X11/fonts/ttf/:/usr/X11R6/lib/X11/fonts/truetype/:/usr/share/fonts/truetype';

use constant TYPE_UNDEF		=> 0;
use constant TYPE_SCALAR	=> 1;
use constant TYPE_ARRAY		=> 2;
use constant TYPE_HASH		=> 3;
use constant TYPE_URL		=> 4;
use constant TYPE_LIST		=> 5;

use constant STRIP_QUOTES => qr/['"]?(.*)['"]?/;

use constant ARRAY_OPTIONS => qw(
	dclrs borderclrs line_types markers types
);

# Sub prototypes:

sub handler ($);
sub parse ($;$);
sub arrayCheck ($$);
sub error ($);
sub makeDir ($);
sub parseURL ($;$);
sub findFont ($);

# Subs:

sub handler ($) {
	my $r = shift;
	$r->request($r);

# Files to delete after request is processed.
	my @cleanup_files;

	eval {
		my $args = scalar $r->args;
		my %args = ($r->args);

		unless ($args) {
			$args = $r->content;
			%args = map {
					Apache::unescape_url_info($_)
				} split /[=&;]/, $args, -1;
		}

		die <<EOF unless $args;
Please supply arguments in the query string, see the Apache::GD::Graph man
page for details.
EOF

# Calculate Expires header based on either an "expires" parameter, the Expires
# configuration variable (via PerlSetVar) or the EXPIRES constant, in days.
# Then convert into seconds and round to an integer.
		my $expires = exists $args{expires} ? $args{expires} :
			      $r->dir_config('Expires') || EXPIRES;

		$expires   *= 24 * 60 * 60;
		$expires    = sprintf ("%d", $expires);

# Determine the type of image that the graph should be.
# Allow an Accept: header with one specific image type to set it, a
# PerlSetVar, or the image_type parameter.
		my $image_type = lc($r->dir_config('ImageType')) || IMAGE_TYPE;

# Set the GD::Text fontpath.
		GD::Text->font_path(
			$r->dir_config('TTFFontPath') ||
			TTF_FONT_PATH
		);

		my $accepts_header = $r->header_in('Accept');
		if (defined $accepts_header and
		    $accepts_header =~ m!^\s*image/(\w+)\s*$!) {
			my $image_type = $1;
		}

		$image_type = $args{image_type} if $args{image_type};

		$image_type = 'jpeg' if $image_type eq 'jpg';

		die <<EOF unless GD::Image->can($image_type);
The version of GD installed on this server does not support
ImageType $image_type.
EOF

		my $jpeg_quality;
		if ($image_type eq 'jpeg') {
			$jpeg_quality = $args{jpeg_quality} ||
					$r->dir_config('JpegQuality');
		}

		my $image_cache;

		if (not exists $args{cache} or $args{cache} != 0) {
			my $cache_size = $r->dir_config('CacheSize');

			if (defined $cache_size and $cache_size != 0) {
				$image_cache = new File::Cache ( {
					namespace	=> 'Images',
					max_size	=> $cache_size ||
								CACHE_SIZE,
					filemode	=> 0660
				} );

				if (my $cached_image =
				    $image_cache->get($args)) {
					$r->header_out (
						"Expires" => time2str (
							time + $expires
						)
					);
					$r->send_http_header (
						"image/$image_type"
					);
					$r->print($cached_image);

					return OK;
				}
			}
		}

		my $type   = delete $args{type}   || 'lines';
		my $width  = delete $args{width}  || 400;
		my $height = delete $args{height} || 300;

		$type =~ m/^(\w+)$/;
		$type = $1;	# untaint it!

		my @data;
		my $ctr = 1;
		my $key = "data$ctr";
		while (exists $args{$key}) {
			my ($type, $array, @rest) = (parse delete $args{$key});
			if ($type == TYPE_LIST) {
				$array = [ $array, @rest ];
			}
			arrayCheck $key, $array;
			push @data, $array;
			$key = "data".(++$ctr);
		}

		die "Please supply at least a data1 argument."
			if ref $data[0] ne 'ARRAY';

		my $length = scalar @{$data[0]};
		die "data1 empty!" if $length == 0;

		if (exists $args{no_axes}) {
			delete $args{x_labels};
			$args{y_number_format} = "";
			delete $args{no_axes};
		}

		my ($x_labels, $x_labels_type);
		if (exists $args{x_labels}) {
			($x_labels, $x_labels_type) =
				(parse delete $args{x_labels})[1];
		} else {
			$x_labels = undef;
		}
		
# Validate the sizes in order to have a more friendly error.
		if (defined $x_labels) {
			arrayCheck "x_labels" => $x_labels;
			if (scalar @$x_labels != $length) {
				die <<EOF;
Size of x_labels not the same as length of data.
EOF
			}
		} else {
# If x_labels is not an array or empty, fill it with undefs.
			for (1..$length) {
				push @$x_labels, undef;
			}
		}

		my $n = 2;
		for (@data[1..$#data]) {
			if (scalar @$_ != $length) {
				die <<EOF;
Size of data$n does not equal size of data1.
EOF
			}
			$n++;
		}

		my $graph;
		eval {
			no strict 'refs';
			require "GD/Graph/$type.pm";
			$graph = ('GD::Graph::'.$type)->new($width, $height);
		}; if ($@) {
		 die <<EOF;
Could not create an instance of class GD::Graph::$type: $@
EOF
		}

		my $to_file = delete $args{to_file};

		for my $option (keys %args) {
			my ($type, $value, @rest) = parse ($args{$option});

			if (my $method = $graph->can("set_$option")) {
				$graph->$method($value, @rest);
			} else {
				if ($type == TYPE_LIST) {
					$value = [ $value, @rest ];
				}
				$args{$option} = $value;
			}

			arrayCheck $option, $value
				if index (ARRAY_OPTIONS, $option) != -1;

			if ($type == TYPE_URL) {
				push @cleanup_files, $args{$option};
			}

		};

# Check if background image specified.
		if (exists $args{background_image}) {
			my $image = new GD::Image($args{background_image});

			die <<EOF if not defined $image;
Could not open your background image: $!
EOF
			$graph->gd->copyResized(
				$image, 0, 0,
				0, 0, $width, $height,
				$image->getBounds
			); 

			delete $args{background_image};
		}

# Check if we need to draw captions, draw them after graph is plotted.
		my @captions;
		$ctr = 1;
		$key = "caption$ctr";
		while (exists $args{$key}) {
			die <<EOF unless UNIVERSAL::isa($args{$key}, 'ARRAY');
Caption must be an array. See the Apache::GD::Graph man page or the StringTTF
method in the GD man page for details.
EOF
			push @captions, $args{$key};
			delete $args{$key};
			$key = "caption".(++$ctr);
		}

		$graph->set(%args);

		my $result = $graph->plot([$x_labels, @data]);

# Draw captions.
		for my $caption (@captions) {
			undef $@;
# Argument 2 to caption is the font name, GD expects a full path.
			$caption->[1] = findFont($caption->[1]);
			my @bounds = $result->stringTTF(@$caption);
			die "Could not draw caption: @{[ join ', ', @$caption ]}: $@" if $@;
		}

		die <<EOF if not defined $result;
Could not create graph: @{[ $graph->error ]}
EOF

		my $image;
		if (defined $jpeg_quality) {
			$image = $result->jpeg($jpeg_quality);
		} else {
			$image = $result->$image_type();
		}

		if (not $to_file) {
			$r->header_out("Expires" => time2str(time + $expires));
			$r->send_http_header("image/$image_type");
			$r->print($image);

			$image_cache->set($args, $image) if defined $image_cache;
		} else {
			my $destination = new IO::File ">$to_file"
				or die "Could not writ to $to_file: $!";
			print $destination $image;

			$r->send_http_header("text/plain");
			$r->print("Image created successfully.");
		}
	}; if ($@) {
		error $@;
	}

	if (@cleanup_files) {
		my %unique; @unique{@cleanup_files} = ();

		for (keys %unique) {
			unlink $_ or
				$r->log_error (__PACKAGE__.': '.
				"Could not delete $_, reason: $!");
		}
	}

	return OK;
}

# parse ($datum[, $tmp_dir])
#
# Parse a datum into a scalar, arrayref or hashref. Using the following semi
# perl-like syntax:
#
# undef			-- a real undef
# foo_bar		-- a scalar
# [1,2,undef,"foo",bar]	-- an array
# [3,4,undef,"baz"]	-- a list
# {1,2,'3',foo}		-- a hash
# or
# http://some/url.png	-- pull a URL into a file, returning that. The file
# will be relative to a directory given as the second parameter, or /tmp if not
# specified.
sub parse ($;$) {
	local $_ = shift;
	my $dir  = shift || '/tmp';

	return (TYPE_UNDEF, undef) if $_ eq 'undef';

	if (/^\[(.*)\]$/) {
		return (TYPE_ARRAY, [ map { $_ eq 'undef' ? undef : (parseURL $_, $dir)[1] }
				split /,/, $1, -1
		        ]);
	}

	if (/^\{(.*)\}$/) {
		return (TYPE_HASH, { map { $_ eq 'undef' ? undef : (parseURL $_, $dir)[1] }
				split /,/, $1, -1
		        });
	}

	if (/^\((.*)\)$/) {
		return (TYPE_LIST, map { $_ eq 'undef' ? undef : (parseURL $_, $dir)[1] }
				split /,/, $1, -1
		       );
	}

	return parseURL $_, $dir;
}

# parseURL ($value)
#
# First strips quotes off the ends of $value.  Then checks whether $value is a
# URL, and if so, fetches it into a file and returns the (TYPE_URL, file_name),
# otherwise returns (TYPE_SCALAR, $value).
sub parseURL ($;$) {
	$_	= shift;
	my $dir	= shift || '/tmp';
	($_) = (/@{[STRIP_QUOTES]}/);

	if (m!^\w+://!) {
		use LWP::Simple;

		my ($url, $file_name) = ($_, $_);
		$file_name =~ s|/|\%2f|g;
		$file_name = $dir."/".$file_name.$$;

		my $file = new IO::File "> ".$file_name or
			error "Could not open $file_name for writing: $!";
		binmode $file;
		my $contents = get($url);

		error <<EOF unless defined $contents;
Could not retrieve data from: $url
EOF

		print $file $contents;
		return (TYPE_URL, $file_name);
	} else {
		return (TYPE_SCALAR, $_);
	}
}

# arrayCheck ($name, $value)
#
# Makes sure $value is a defined array reference, otherwise calls error.
sub arrayCheck ($$) {
	my ($name, $value) = @_;
	error <<EOF if !defined $value or !UNIVERSAL::isa($value, 'ARRAY');
$name must be an array, eg. [1,2,3,5]
EOF
}

# error ($message)
#
# Sends a page with the error message to the browser.
sub error ($) {
	my $message	= shift;
# Ending newlines look ugly in the error log.
	chomp $message;
	my $r		= Apache->request;
	my $contact	= $r->server->server_admin;
	$r->send_http_header("text/html");
	$r->print(<<"EOF");
<html>
<head></head>
<body bgcolor="lightblue">
<font color="red"><h1>Error:</h1></font>
<p>
$message
<p>
The Request was:<br>
@{[ $r->the_request ]}
<p>
Please contact the server administrator, <a href="$contact">$contact</a> and
inform them of the time the error occured, and anything you might have done to
cause the error.
</body>
</html>
EOF

	$r->log_error (__PACKAGE__.': '.$r->the_request.': '.$message);
}

# findFont ($basename)
#
# Searches the true type font path for a file, returns the first match.
#
# Returns undef if no font was found.
sub findFont ($) {
	my $name = shift;
	my @path = map { m!(.*?)/*$! } split /:/, GD::Text->font_path;

	for my $path (@path) {
		for my $font (<$path/*>) {
			return $font if $font =~ m!/$name$!;
		}
	}
}

1;

__END__

=head1 AUTHOR

Rafael Kitover (caelum@debian.org)

=head1 COPYRIGHT

This program is Copyright (c) 2000,2001 by Rafael Kitover. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=head1 ACKNOWLEDGEMENTS

This module owes its existance, obviously, to the availability of the wonderful
GD::Graph module from Martien Verbruggen <mgjv@comdyn.com.au>.

Thanks to my employer, Gradience, Inc., for allowing me to work on projects
as free software.

Thanks to Vivek Khera, Scott Holdren and Drew Negentesh for the bug fixes.

=head1 BUGS

Probably a few.

We should probably just let people set up their own PerlFixupHandlers for
errors, but this makes it more difficult to set up. At least, it should be an
option.

=head1 TODO

Boxed captions.
Variable mapping of x-labels to data points.
If possible, a comprehensive test suite.
Make it faster?

=head1 SEE ALSO

L<perl>,
L<GD::Graph>,
L<GD>

=cut
