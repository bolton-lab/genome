package Genome::Sys;

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Compare;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from a 64-bit machine";
    } else {
        plan tests => 13;
    }
};

use_ok( 'Genome::Model::Tools::Somatic::IdentifyDnpAdv');

#The following are just tests I set up to determine the code was functioning correctly. More tests would be good for edge cases and any dependencies.
# test for subroutin _is_dnp()

my $fake_read_seq = "ACTATCG";
my $fake_read_pos = 228;
my $fake_cigar = "3M1D4M";

my $offset = Genome::Model::Tools::Somatic::IdentifyDnpAdv->_calculate_offset(231,$fake_read_pos, $fake_cigar);
ok(!defined($offset), 'test _calculate_offset() begin');
$offset = Genome::Model::Tools::Somatic::IdentifyDnpAdv->_calculate_offset(232,$fake_read_pos, $fake_cigar);
ok(substr($fake_read_seq,$offset,1) eq "A", 'Finished test of _calculate_offset()');


# test for high confidence part

my $test_input_dir  = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Tools-Somatic-IdentifyDnpAdv/';

my $sniper_file     = $test_input_dir . 'sniper.in';
my $tumor_bam_file  = $test_input_dir . 'tumor.tiny.bam';

my $bed_lc_file_default_expected = $test_input_dir . 'bed_lc_file_default.expected';
my $bed_hc_file_default_expected = $test_input_dir . 'bed_hc_file_default.expected';
my $anno_lc_file_default_expected = $test_input_dir . 'anno_lc_file_default.expected';
my $anno_hc_file_default_expected = $test_input_dir . 'anno_hc_file_default.expected';

my $test_output_dir = File::Temp::tempdir('Genome-Model-Tools-Somatic-IdentifyDnpAdv-XXXXX', CLEANUP => 1, TMPDIR => 1);
$test_output_dir .= '/';

my $bed_lc_file_default    = $test_output_dir . 'bed_lc_file_default.out';
my $bed_hc_file_default     = $test_output_dir . 'bed_hc_file_default.out';
my $anno_lc_file_default     = $test_output_dir . 'anno_lc_file_default.out';
my $anno_hc_file_default     = $test_output_dir . 'anno_hc_file_default.out';

my $identify_dnp_adv_default = Genome::Model::Tools::Somatic::IdentifyDnpAdv->create(
    snp_input_file         => $sniper_file,
    bam_file      => $tumor_bam_file,
    bed_lc_file         => $bed_lc_file_default,
    bed_hc_file         => $bed_hc_file_default,
    anno_lc_file        => $anno_lc_file_default,
    anno_hc_file        => $anno_hc_file_default,
    min_mapping_quality => 40,
    min_somatic_score => 40,
);

ok($identify_dnp_adv_default, 'created IdentifyDnpAdv object (default mapping & somatic quality)');
ok($identify_dnp_adv_default->execute(), 'executed IdenfityDnpAdv object');

ok(-s $bed_lc_file_default, 'generated an low confidence bed format output file');
ok(-s $bed_hc_file_default, 'generated an high confidence bed format output file');
ok(-s $anno_lc_file_default, 'generated an low confidence anno format output file');
ok(-s $anno_hc_file_default, 'generated an high confidence anno format output file');

is(compare($bed_lc_file_default, $bed_lc_file_default_expected), 0, 'bed_lc_file output matched expected output');
is(compare($bed_hc_file_default, $bed_hc_file_default_expected), 0, 'bed_hc_file output matched expected output');
is(compare($anno_lc_file_default, $anno_lc_file_default_expected), 0, 'anno_lc_file output matched expected output');
is(compare($anno_hc_file_default, $anno_hc_file_default_expected), 0, 'anno_hc_file output matched expected output');
