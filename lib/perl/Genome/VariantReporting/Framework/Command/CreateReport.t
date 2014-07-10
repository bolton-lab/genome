#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Test::Deep;
use File::Basename qw(basename);
use File::Spec;
use Genome::Utility::Test qw(compare_ok);
use Sub::Install qw(reinstall_sub);

my $pkg = 'Genome::VariantReporting::Framework::Command::CreateReport';
use_ok($pkg);

my $code_test_dir = __FILE__ . '.d';
my $test_dir = Genome::Sys->create_temp_directory;
Genome::Sys->rsync_directory($code_test_dir, $test_dir);

my $output_dir = Genome::Sys->create_temp_directory;
reinstall_sub( {
    into => $pkg,
    as => 'setup_environment',
    code => sub {
        local $ENV{UR_DUMP_DEBUG_MESSAGES} = 1;
        local $ENV{UR_COMMAND_DUMP_DEBUG_MESSAGES} = 1;
        local $ENV{UR_DUMP_STATUS_MESSAGES} = 1;
        local $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
        # no WF_USE_FLOW
    },
});

my $input_vcf = File::Spec->join($test_dir, "input.vcf");
my $cmd = $pkg->execute(
    input_vcf => $input_vcf,
    variant_type => 'snvs',
    output_directory => $output_dir,
    log_directory => Genome::Sys->create_temp_directory,
    plan_file => File::Spec->join($test_dir, 'plan.yaml'),
    resource_file => get_resource_file($input_vcf),
);

my $expected_dir = File::Spec->join($test_dir, "expected");
compare_dir_ok($output_dir, $expected_dir, 'All reports are as expected');

done_testing;

sub get_resource_file {
    my $input_vcf = shift;

    my $provider = Genome::VariantReporting::Framework::Component::ResourceProvider->create(
        attributes => {
            __provided__ => [$input_vcf, $input_vcf],
            translations => {},
        },
    );
    my $tmp_dir = Genome::Sys->create_temp_directory;
    my $resource_file = File::Spec->join($tmp_dir, 'resources.yaml');
    $provider->write_to_file($resource_file);
    return $resource_file;
}

sub compare_dir_ok {
    my ($got_dir, $expected_dir, $message) = @_;

    my @got_files = map {basename($_)} glob(File::Spec->join($got_dir, '*'));
    my @expected_files = map {basename($_)} glob(File::Spec->join($expected_dir, '*'));

    cmp_bag(\@got_files, \@expected_files, 'Got all expected files') or die;

    for my $filename (@got_files) {
        # this file has absolute paths to test files in it
        next if $filename eq 'resources.yaml';

        my $got = File::Spec->join($got_dir, $filename);
        my $expected = File::Spec->join($expected_dir, $filename);
        compare_ok($got, $expected, "File ($filename) is as expected");
    }
}
