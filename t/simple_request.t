#!/usr/bin/perl
# vim: syntax=perl

use strict;
use Apache::FakeRequest;
use Apache::GD::Graph;
use Benchmark;

# Number of tests.
print "1..2\n";

my $request = new Apache::FakeRequest (
	args => 'data1=[1,2,3,4,5]&cache=0',
);

# Redirect STDOUT to a file to examine result.
my $result_file = "/tmp/Apache::GD::Graph-test-$$";

*OLDOUT = 0; # Silence "used only once" warning...
open OLDOUT, ">&STDOUT";
open STDOUT, ">$result_file" or do {
	print STDERR "Could not redirect STDOUT to $result_file: $!\n";
	print "not ok 1\n";
	exit;
};

my $return_val = Apache::GD::Graph::handler($request);

close STDOUT;
open STDOUT, ">&OLDOUT";

if ($return_val < 0) {
	print STDERR "Handler returned unsuccessfully.\n";
	print "not ok 1\n";
	exit;
}

open RESULT, $result_file or do {
	print STDERR "Could not open $result_file: $!\n";
	print "not ok 1\n";
	exit;
};

my $line1 = scalar <RESULT>;
close RESULT;
unlink $result_file;

if ($line1 !~ /PNG/) {
	print STDERR "Result not a PNG file!\n";
	print "not ok 1\n";
	exit;
}

print "ok 1\n";

print STDERR "\nTiming 100 Line Graphs, this may take a few seconds...\n";

open OLDOUT, ">&STDOUT";
open STDOUT, ">/dev/null";

my $time = timeit (100, sub { Apache::GD::Graph::handler($request) });

close STDOUT;
open STDOUT, ">&OLDOUT";

print STDERR "\n100 Line Graphs took ", timestr($time), " to draw.\n";
print "ok 2\n";

package Apache::FakeRequest;

# Not all versions return args in a list context properly.
sub args {
	my ($self) = shift;
	return wantarray ?  map { 
	    s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
	    $_;
	} split /[=&;]/, $self->{args}, -1 : $self->{args};
}

sub dir_config {
	my ($self, $key, $value) = @_;
	$self->{dir_config}{$key} = $value if $value;
	return $self->{dir_config}{$key};
}

1;
