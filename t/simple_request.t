#!/usr/bin/perl
# vim: syntax=perl

use strict;
use Apache::FakeRequest;
use Apache::GD::Graph;

# Set AutoFlush on.
$| = 1;

# Number of tests.
print "1..1\n";

my $request = new Apache::FakeRequest (
	args		=> 'data1=[1,2,3,4,5]',
);

# Redirect STDOUT to a file to examine result.
my $result_file = "/tmp/Apache::GD::Graph-test-$$";

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
