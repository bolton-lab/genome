#!/usr/bin/env genome-perl

use POSIX;
use Data::Dumper;
use Sort::Naturally qw/nsort/;
use IO::File;
use File::Temp qw/tempdir/;
use File::Slurp qw/read_file/;
use Test::More;
use above 'Genome';

use warnings;
use strict;
BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
}

my $pkg = 'Genome::Model::PhenotypeCorrelation::Command::CaseControl::Unrelated';
use_ok($pkg);

my $test_data_dir = $ENV{GENOME_TEST_INPUTS} . "/Genome-Model-PhenotypeCorrelation-testdata/CaseControl";

my $tmpdir = tempdir(
    't-ParallelClinicalCorrelation-XXXXX',
    TEMPDIR => 1,
    CLEANUP => 1
);

my $old_clinical_data_file = "$test_data_dir/clinical.txt.bad_pheno_encoding";
my $new_clinical_data_file = "$test_data_dir/clinical.txt";

my $old_dir = "$tmpdir/old";
my $new_dir = "$tmpdir/new";
mkdir($old_dir);
mkdir($new_dir);

my $ensembl_annotation_build_id = $ENV{GENOME_DB_ENSEMBL_DEFAULT_IMPORTED_ANNOTATION_BUILD};
my $annotation_build = Genome::Model::Build->get($ensembl_annotation_build_id);

test_with_clinical_data($old_dir, $old_clinical_data_file,
    case_label => "Invasive (high)",
    control_label => "Cutaneous (low)"
);
test_with_clinical_data($new_dir, $new_clinical_data_file);

sub test_with_clinical_data {
    my ($tmpdir, $clinical_data_file, %params) = @_;

    # Test with string encoding of binary trait (vs 0/1)
    my $input_vcf_file = "$test_data_dir/multisample.vcf.gz";
    my $input_vcf_file_index = "$input_vcf_file.tbi";
    my $glm_model_file = "$test_data_dir/glm-model.txt";
    my $sample_list_file = "$test_data_dir/samples.txt";
    my $output_file = "$tmpdir/parallel.txt.glm.tsv";
    my $orig_output_file_prefix = "$tmpdir/orig.txt";
    my $orig_output_file = "$orig_output_file_prefix.glm.tsv";
    my $per_site_report = "$test_data_dir/per_site_report.txt";

    print "Using temp directory: $tmpdir\n";

    # FIXME: This module currently tries to write things next to the multisample vcf
    # which would be in the test data directory. For now, we'll just make a symlink
    # to the vcf in the output directory.
    my $vcf_file = "$tmpdir/multisample.vcf.gz";
    my $vcf_file_index = "$vcf_file.tbi";
    symlink($input_vcf_file, $vcf_file);
    symlink($input_vcf_file_index, $vcf_file_index);
    symlink($clinical_data_file, "$tmpdir/clinical.txt");
    print "symlink($clinical_data_file, $tmpdir/clinical.txt)\n";
    $clinical_data_file = "$tmpdir/clinical.txt";

    my $cmd = $pkg->create(
            multisample_vcf => $vcf_file,
            ensembl_annotation_build => $annotation_build,
            output_directory => $tmpdir,
            sample_list_file => $sample_list_file,
            clinical_data_file => $clinical_data_file,
            glm_model_file => $glm_model_file,
            glm_max_cols_per_file => 5,
            identify_cases_by => $params{case_label},
            identify_controls_by =>  $params{control_label},
            per_site_report_file => $per_site_report,
        );
    ok($cmd, "Created command object");
    $cmd->dump_status_messages(1);
    ok($cmd->execute, "Executed command");

    ok(-d "$tmpdir/burden_analysis", "Burden analysis subdirectory exists");

    my @expected_files = (
        "clinical_correlation_result.glm.tsv",
        "clinical_correlation_result.glm.tsv.qqplot.png",
        "clinical_correlation_result.glm.tsv.common",
        "clinical_correlation_result.glm.tsv.common.qqplot.png",
        "clinical_correlation_result.categorical.tsv",
        "clinical_correlation_result.categorical.tsv.qqplot.png",
        "clinical_correlation_result.categorical.tsv.common",
        "clinical_correlation_result.categorical.tsv.common.qqplot.png",
        "multisample.vcf.gz.VEP_annotated",
        "multisample.vcf.gz.VEP_annotated.sorted",
        "multisample.vcf.gz.VEP_annotated.for_burden",
        "variant_matrix.txt",
        "burden_matrix.txt",
    );

    for my $f (@expected_files) {
        ok(-s "$tmpdir/$f", "Expected file $f exists and is not empty");
    }
}

done_testing();
