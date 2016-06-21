#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'tests' => 1;

use FindBin;
use lib $FindBin::Bin . '/../lib';
use Exodus;

my $database = DBI->connect(
    'DBI:mysql:database=test;host=localhost',
    'root', undef,
    {'RaiseError' => 1}
);

my $exodus = Exodus->new(
    'database' => $database,
    'root' => 'clients',
);
isa_ok $exodus, 'Exodus';

# TODO proper tests