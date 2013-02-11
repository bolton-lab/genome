#!/usr/bin/env genome-perl

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Compare;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

plan tests => 5;

use_ok( 'Genome::Model::Tools::Library::CheckLibs');

my $test_input_dir  = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Tools-Library-CheckLibs/'; #Expected output

#This build should be replaced with some new test model with a subset of the lanes to get a quicker test
my $test_build_id = 106410700;

my $expected_output_file = $test_input_dir . "build$test_build_id.expected";

my $test_output_dir = File::Temp::tempdir('Genome-Model-Tools-Library-CheckLibs-XXXXX', CLEANUP => 1, TMPDIR => 1);
$test_output_dir .= '/';

my $output_file = $test_output_dir . "build$test_build_id.out";

my $check_lib = Genome::Model::Tools::Library::CheckLibs->create(
        builds => $test_build_id,
        output_file => $output_file,
);

ok($check_lib, "created CheckLib object for build id $test_build_id");
ok($check_lib->execute(), "executed CheckLib object for build id $test_build_id");

ok(-s $output_file, 'generated output file');
is(compare($output_file, $expected_output_file), 0, "output for build $test_build_id matched expected results");
