#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok('Genome::Model::GenePrediction::Command::Eukaryotic::List') or die;

my $test_pp = Genome::ProcessingProfile::GenePrediction::Eukaryotic->create(
    name => 'test eukaryotic list',
    domain => 'eukaryotic',
    rnammer_version => 12.23.34, # set this to nonsense to make the pp params unique
);
ok($test_pp, 'created test processing profile successfully') or die;

my $test_taxon = Genome::Taxon->create(
    name => 'test taxon',
    domain => 'eukaryotic',
);
ok($test_taxon, 'created test taxon successfully') or die;

my $assembly_contigs = Genome::Config::get('test_inputs') . '/Genome-Model-GenePrediction-Eukaryotic/shorter_ctg.dna';

my $test_model = Genome::Model::GenePrediction::Eukaryotic->create(
    subject_name => $test_taxon->name,
    subject_type => $test_taxon->subject_type,
    subject_id => $test_taxon->id,
    processing_profile_id => $test_pp->id,
    name => 'test model',
    assembly_contigs_file => $assembly_contigs,
);
ok($test_model, 'created test model successfully') or die;

my $list_object = Genome::Model::GenePrediction::Command::Eukaryotic::List->create(
    show => 'domain,gram_stain,organism_name,ncbi_taxonomy_id,assembly_contigs_file,repeat_library,snap_models,fgenesh_model',
    filter => 'id=' . $test_model->id,
    style => 'pretty',
);
ok($list_object, 'created list command object successfully') or die;

my $rv = $list_object->execute;
ok($rv, 'list command executed successfully') or die;

done_testing();