#!/usr/bin/env genome-perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More tests => 1;
use Test::MockObject;

$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
$ENV{UR_DBI_NO_COMMIT} = 1;

use_ok('Genome::Model::Command::InstrumentData::Assign') or die;
