#!/usr/bin/env genome-perl

use strict;
use warnings;

use above 'Genome';
use File::Compare;
use Test::More;
use Genome::Utility::Test qw(compare_ok);
use Net::SSLeay;

use_ok('Genome::Model::Tools::Dgidb::QueryGene');

my $test_dir = Genome::Config::get('test_inputs') . '/Genome-Model-Tools-Dgidb-QueryGene/';

my $expected_out = $test_dir.'v3/expected.out';
my $output_file  = Genome::Sys->create_temp_file_path('query_gene.out');

my $genes = 'FLT3,EGFR,KRAS';
my $cmd =Genome::Model::Tools::Dgidb::QueryGene->create(
    output_file         => $output_file,
    genes               => $genes,
    gene_categories     => 'KINASE',
    interaction_types   => 'inhibitor',
    interaction_sources => 'TALC,TEND,MyCancerGenome',
    antineoplastic_only => 1,
);

ok($cmd, 'command created ok');
SKIP: {
    skip('SSL version is too old', 6) if $Net::SSLeay::VERSION < 1.74;

    ok($cmd->execute, 'command completed successfully');
    ok(-e $output_file, 'Output file created as expected');

    my $expected_outputs = $cmd->output_hash_ref->{matchedTerms};

    my $reader = Genome::Utility::IO::SeparatedValueReader->create(
        input     => $output_file,
        separator => "\t",
    );

    my $resp = $cmd->get_response($genes);
    ok($resp->is_success, "Got a successful response from dgidb");

    my @outputs;
    while (my $data = $reader->next) {
        push @outputs, $data;
    }

    is_deeply(\@outputs, $expected_outputs, 'Array of hash outputs created as expected.');

    $output_file  = Genome::Sys->create_temp_file_path('query_gene2.out');
    $cmd =Genome::Model::Tools::Dgidb::QueryGene->create(
        output_file         => $output_file,
        genes               => 'NO_RESULTS',
    );

    ok($cmd->execute, "Command executed with a gene that gets no results");
    ok(-e $output_file, "Output file exists");
}


done_testing();
