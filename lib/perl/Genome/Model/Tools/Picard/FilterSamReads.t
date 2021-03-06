#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings FATAL => 'all';

use above 'Genome';
use Test::More tests => 4;

my $pkg = 'Genome::Model::Tools::Picard::FilterSamReads';
use_ok($pkg);

my $test_dir = __FILE__.'.d';

# Params
my $picard_version = '1.130';

# Inputs
my $input_bam_file = File::Spec->join($test_dir, 'cf651d3d8af5484a80bbe2f1498aab9b_chr22_1k.bam');
my $read_list_file = File::Spec->join($test_dir, 'chr22_unique_reads_100.txt');

# Expected Outputs
my $expected_bam_file = File::Spec->join($test_dir,'cf651d3d8af5484a80bbe2f1498aab9b_chr22_100-v'.$picard_version .'.bam');

# Test Outputs
my $output_bam_file = Genome::Sys->create_temp_file_path('cf651d3d8af5484a80bbe2f1498aab9b_chr22_100-v'. $picard_version .'.bam');

my $cmd = $pkg->create(
   input_file => $input_bam_file,
   read_list_file => $read_list_file,
   write_reads_files => 0,
   output_file => $output_bam_file,
   filter => 'includeReadList',
   use_version => $picard_version,
); 
ok($cmd,'create FilterSamReads command');

ok($cmd->execute,'execute FilterSamReads command');

ok(-e $output_bam_file,'output BAM file exists');

# Need an approach for comparing the BAM contents vs. expected


