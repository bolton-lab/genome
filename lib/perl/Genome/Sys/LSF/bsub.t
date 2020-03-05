use strict;
use warnings;

use above 'Test::More';
use Test::Builder;
use Test::Fatal qw(exception);
use Genome::Sys::LSF::bsub qw();

plan tests => 12;

my $fake_queue = 'fake_queue';
my @queues = (map { Genome::Config::get($_) } qw(lsf_queue_build_worker lsf_queue_short));

ok( !Genome::Sys::LSF::bsub::_valid_lsf_queue($fake_queue),
    qq('$fake_queue' is not a valid queue));

ok( Genome::Sys::LSF::bsub::_valid_lsf_queue($queues[0]),
    qq('$queues[0]' is a valid queue));

like( exception { Genome::Sys::LSF::bsub::_args(queue => $fake_queue, cmd => 'true') },
    qr/valid LSF queue/,
    qq('$fake_queue' triggered exception));

is( exception { Genome::Sys::LSF::bsub::_args(queue => $queues[0], cmd => 'true') },
    undef,
    qq('$queues[0]' did not trigger exception));

do {
    my $_option_mapper = \&Genome::Sys::LSF::bsub::_option_mapper;
    no warnings 'redefine';
    local *Genome::Sys::LSF::bsub::_option_mapper = sub {
        my $option = $_option_mapper->(@_);
        $option =~ s/^-/-b:/;
        return $option;
    };
    is( Genome::Sys::LSF::bsub::_option_mapper('project'),
        '-b:P',
        q('project' arg maps to '-b:P' option with _option_mapper overridden));
};

is( Genome::Sys::LSF::bsub::_option_mapper('project'),
    '-P',
    q('project' arg maps to '-P' option));

my @cases = (
    [
        [
            email => 'nnutter@genome.wustl.edu',
            cmd => 'true',
        ], [qw(-u nnutter@genome.wustl.edu true)], 'single option',
    ],[
        [
            email => 'nnutter@genome.wustl.edu',
            project => 'HighPriority',
            cmd => 'true',
        ], [qw(-u nnutter@genome.wustl.edu -P HighPriority true)], 'multiple options',
    ],[
        [
            hold_job => 0,
            cmd => 'true',
        ], [qw(true)], 'disabled flag',
    ],[
        [
            hold_job => 1,
            cmd => 'true',
        ], [qw(-H true)], 'enabled flag',
    ],
    [
        [
            resource_string => '-R "select[mem>9876] rusage[mem=9753] span[hosts=1]" -M 10000000 -n 4',
            cmd => 'true',
        ], ['-R', 'select[mem>9876] rusage[mem=9753] span[hosts=1]','-n', 4,  '-M', '10000000', 'true'], 'parsed resource request',
    ],
    [
        [
            job_group => '/genome/test',
            user_group => 'compute-test',
            cmd => 'true',
        ], [qw(-g /genome/test -G compute-test true)], 'job and user groups',
    ]
);
for my $case (@cases) {
    my @input = @{$case->[0]};
    my $expected = $case->[1];
    my $name = $case->[2];
    my $got = [Genome::Sys::LSF::bsub::args_builder(@input)];
    is_deeply($got, $expected, $name);
}
