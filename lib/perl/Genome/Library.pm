package Genome::Library;

use strict;
use warnings;
use Genome;

use Genome::Utility::List;

class Genome::Library {
    roles => [qw(
        Genome::Role::ObjectWithLockedConstruction
        Genome::Role::Notable
        Genome::Role::Searchable
    )],
    table_name => 'instrument.fragment_library',
    id_generator => '-uuid',
    id_by => [
        library_id => {
            is => 'Text',
            len => 32,
        },
    ],
    has => [
        name => {
            is => 'Text',
            len => 64,
            column_name => 'FULL_NAME',
            doc => 'Name of the library. Usually has the sample name and an extension.',
        },
        sample_id => {
            is => 'Text',
            len => 32,
        },
        sample => {
            is => 'Genome::Sample',
            id_by => 'sample_id',
            doc => 'Sample that this library came from.',
            constraint_name => 'FLIB_GS_FK',
        },
        sample_name => {
            is => 'Text',
            via => 'sample',
            to => 'name',
        },
    ],
    has_optional => [
        original_insert_size => {
            is => 'Text',
            len => 64,
            doc => 'The original insert size of the fragments. This may be a number or a range.',
        },
        library_insert_size => {
            is => 'Text',
            len => 64,
            doc => 'The relative insert size of fragments. This may be a number or a range.',
        },
        protocol => {
            is => 'Text',
            len => 64,
            doc => 'Protocol used to generate the library.',
        },
        transcript_strand => {
            is => 'Text',
            len => 16,
            doc => 'The strand targeted during RNA-seq prep.',
            valid_values => [qw/ unstranded firststrand secondstrand /],
        },
        bisulfite_conversion => {
            is => 'Text',
            len => 32,
            doc => 'name of the bisulfite conversion kit used if any'
        },
        taxon_id => {
            is => 'Number',
            via => 'sample',
        },
        taxon => {
            is => 'Genome::Taxon',
            via => 'sample',
        },
        species_name => {
            is => 'Text',
            via => 'taxon',
        },
        sample_source => {
            via => 'sample',
            to => 'source',
            doc => 'Source of the sample',
        },
        sample_source_name => {
            via => 'sample_source',
            to => 'name',
            doc => q(Name of the sample's source),
        },
        sample_source_id => {
            via => 'sample_source',
            to => 'id',
            doc => q(ID of the sample's source),
        },
        models => {
            is => 'Genome::Model',
            via => 'sample',
            is_many => 1,
            is_many => 1,
        },
        instrument_data => {
            is => 'Genome::InstrumentData',
            reverse_as => 'library',
            is_many => 1,
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub __display_name__ {
    return $_[0]->name.' ('.$_[0]->id.')';
}

sub delete {
    my $self = shift;

    $self->status_message("Deleting library " . $self->__display_name__);

    my @instrument_data = Genome::InstrumentData->get(
        library_id => $self->id,
    );
    for my $instrument_data (@instrument_data) {
        $instrument_data->delete;
    }

    return $self->SUPER::delete(@_);
}

sub is_bisulfite_converted {
    my $self = shift;
    return $self->bisulfite_conversion ? 1 : 0;
}

sub is_rna {
    my $self = shift;

    return 1 if $self->transcript_strand;

    #fallback in case above was not set
    return 1 if Genome::Utility::List::in(
        $self->sample->extraction_type, (
            'rna', 'total rna',
            'cdna', 'cDNA', 'cdna library',
            'mrna', 'pooled rna',
        )
    );

    return 0;
}

sub is_10x_atac {
    my $self = shift;

    return 1 if Genome::Utility::List::in(
        $self->protocol, (
            "10x_SC_ATAC_SEQ"
        )
    );

    return 0;
}

sub is_10x_barcoded {
    my $self = shift;

    return 1 if $self->protocol =~ /^10x.*featurebarcod/i;

    return 0;
}

sub is_10x_gex {
    my $self = shift;

    return 1 if $self->protocol =~ /^10x.*GEX/i;

    return 0;
}

sub is_10x_vdj {
    my $self = shift;

    return 1 if $self->protocol =~ /10x.*SC.5.*Enriched.[TB]CELL/i;

    return 0;
}

sub lock_id {
    my $class = shift;
    my %args = @_;
    return $args{name};
}

1;

