package Fennec::TestSet::SubSet;
use strict;
use warnings;

use base 'Fennec::TestSet';

use Try::Tiny;
use Fennec::Util::Accessors;
use B;

use Fennec::Util::Alias qw/
    Fennec::Runner
    Fennec::Workflow
    Fennec::Output::Result
    Fennec::TestSet
    Fennec::TestSet::SubSet::Setup
/;

use List::Util   qw/shuffle/;
use Time::HiRes qw/time/;
use Benchmark qw/timeit :hireswallclock/;

Accessors qw/setups teardowns tests/;

sub new {
    my $class = shift;
    return bless(
        {
            setups => [],
            teardowns => [],
            tests => [],
            created_in => $$,
            @_,
        },
        $class
    );
}

sub lines_for_filter {
    my $self = shift;
    return 0 unless wantarray;
    map { $_->lines_for_filter } @{$self->tests}, @{$self->setups}, @{$self->teardowns};
}

sub run {
    my $self = shift;
    return Result->skiparallel_testset( $self, $self->skip )
        if $self->skip;

    $self->run_setups;
    $self->run_tests;
    $self->run_teardowns;
}

sub add_testset {
    my $self = shift;
    my ( $name, $sub ) = @_;
    my $line = B::svref_2object( $sub )->START->line;
    my $ts = TestSet->new( $name, method => $sub, line => $line );
    $ts->workflow( $self->workflow );
    push @{ $self->{ tests }} => $ts;
}

sub add_setup {
    my $self = shift;
    my $setup = Setup->new( @_ );
    $setup->testfile( $self->testfile );
    push @{ $self->{ setups }} => $setup;

}

sub add_teardown {
    my $self = shift;
    my $setup = Setup->new( @_ );
    $setup->testfile( $self->testfile );
    push @{ $self->{ teardowns }} => $setup;
}

sub run_setups {
    my $self = shift;
    return unless my $setups = $self->setups;
    $_->run for @$setups;
}

sub run_tests {
    my $self = shift;
    return unless $self->tests;
    try {
        my @sets = @{ $self->tests };
        if ( Runner->search ) {
            @sets = $self->workflow->search_filter( Runner->search, \@sets );
        }

        @sets = shuffle @sets if $self->testfile->fennec_meta->random;
        @sets = sort { $a->name cmp $b->name } @sets
            if $self->testfile->fennec_meta->sort;

        my $benchmark = timeit( 1, sub {
            for my $set ( @sets ) {
                $set->run()
            }
        });
        Result->pass_testset( $self, $benchmark ) unless $self->no_result;
    }
    catch {
        Result->fail_testset( $self, $_ );
    };
}

sub run_teardowns {
    my $self = shift;
    return unless my $teardowns = $self->teardowns;
    $_->run for reverse @$teardowns;
}

sub observed {
    my $self = shift;
    my ( $val ) = @_;
    return $self->SUPER::observed unless $val;

    $self->SUPER::observed( $val );
    $_->observed( $val ) for @{ $self->tests };
}

1;

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Fennec is free software; Standard perl licence.

Fennec is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
F