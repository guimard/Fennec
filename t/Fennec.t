#!/usr/bin/perl
use strict;
use warnings;

use Fennec::Runner;
Fennec::Runner->new( file_types => [ 'TDir' ], ignore => [ qr{fakeroots} ]);
Fennec::Runner->get->run;
