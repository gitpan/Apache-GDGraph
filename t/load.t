#!/usr/bin/perl -w
# vim: syntax=perl

use strict;

my $loaded = 0;

sub BEGIN {
	$| = 1;
	print "1..1\n";
}

sub END {
	print "not ok 1\n" unless $loaded;
}

use Apache::GD::Graph;
$loaded = 1;

print "ok 1\n";
