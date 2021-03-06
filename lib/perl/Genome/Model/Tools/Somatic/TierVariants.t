#!/usr/bin/env genome-perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 13;
use File::Compare;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

BEGIN {
    use_ok( 'Genome::Model::Tools::Somatic::TierVariants');
};

my $test_input_dir  = Genome::Config::get('test_inputs') . '/Genome-Model-Tools-Somatic-TierVariants/';
my $variant_file    = $test_input_dir . 'variants.in';
my $ucsc_file       = $test_input_dir . 'ucsc_annotation.in';
my $transcript_file = $test_input_dir . 'transcript.in';

my $expected_tier1_file = $test_input_dir . 'tier_1.expected';

my $test_output_dir = File::Temp::tempdir('Genome-Model-Tools-Somatic-TierVariants-XXXXX', CLEANUP => 1, TMPDIR => 1);
$test_output_dir .= '/';
my $tier1_file      = $test_output_dir . 'tier_1.out';
my $tier2_file      = $test_output_dir . 'tier_2.out';
my $tier3_file      = $test_output_dir . 'tier_3.out';
my $tier4_file      = $test_output_dir . 'tier_4.out';


my $tier_variants_1 = Genome::Model::Tools::Somatic::TierVariants->create(
    transcript_annotation_file  => $transcript_file,
    variant_file                => $variant_file,
    tier1_file                  => $tier1_file,
    tier2_file                  => $tier2_file,
    only_tier_1                 => 1,
);


ok($tier_variants_1, 'created TierVariants object for tier 1');
ok($tier_variants_1->execute(), 'executed TierVariants for tier 1');

ok(-s $tier1_file, 'generated tier 1 file');
ok(!-s $tier2_file, 'no unrequested output');

is(compare($tier1_file, $expected_tier1_file), 0, 'tier 1 output matches expected result');

my $tier1_file_for_comparison = $test_output_dir . 'tier_1.out.from_tier_1_only';
rename($tier1_file, $tier1_file_for_comparison);

my $tier_variants_all = Genome::Model::Tools::Somatic::TierVariants->create(
    transcript_annotation_file  => $transcript_file,
    ucsc_file                   => $ucsc_file,
    variant_file                => $variant_file,
    tier1_file                  => $tier1_file,
    tier2_file                  => $tier2_file,
    tier3_file                  => $tier3_file,
    tier4_file                  => $tier4_file,
);

ok($tier_variants_all, 'created TierVariants object for all tiers');
ok($tier_variants_all->execute(), 'executed TierVariants for all tiers');

ok(-s $tier1_file, 'generated tier 1 file');
ok(-s $tier2_file, 'generated tier 2 file');
ok(-e $tier3_file, 'generated (possibly empty) tier 3 file');
ok(-e $tier4_file, 'generated (possibly empty) tier 4 file');

is(compare($tier1_file, $tier1_file_for_comparison), 0, 'same tier 1 output regardless of only_tier_1 flag.');
