package Genome::Show;

use strict;
use warnings;


class Genome::Show {
    is => 'Command::V2',

    has => [
        target => {
            is => 'Text',
            shell_args_position => 1,
            doc => 'The string, id, or partial id to search for.',
        },
    ],
};


sub execute {
    my $self = shift;

    my ($type, $id) = $self->get_type_and_id;
    $self->show($type, $id);

    return 1;
}


sub show {
    my ($self, $type, $id) = @_;

    my $object = $self->get_object($type, $id);
    $self->show_object($type, $object);
}


my %OBJECT_GETTERS = (
    'build' => 'Genome::Model::Build',
#    "illumina_run"
#    "imported_instrument_data"
#    "individual"
#    "instrument data"
#    "library"
#    "mail"
#    "model - ClinSeq"
#    "model - alignment"
#    "model - convergence"
#    "model - lane_qc"
#    "model - microarray"
#    "model - other"
#    "model - rna"
#    "model - somatic"
#    "modelgroup"
#    "population_group"
#    "processing_profile"
#    "project"
#    "sample"
#    "solexa_instrument_data"
#    "taxon"
#    "user"
#    "wiki-page"
#    "work-order"
);

sub get_object {
    my ($self, $type, $id) = @_;

    my $getter = $OBJECT_GETTERS{$type};
    return $getter->get($id);
}

my %OBJECT_SHOWERS = (
    'build' => 'Genome::Show::Build',
#    "illumina_run"
#    "imported_instrument_data"
#    "individual"
#    "instrument data"
#    "library"
#    "mail"
#    "model - ClinSeq"
#    "model - alignment"
#    "model - convergence"
#    "model - lane_qc"
#    "model - microarray"
#    "model - other"
#    "model - rna"
#    "model - somatic"
#    "modelgroup"
#    "population_group"
#    "processing_profile"
#    "project"
#    "sample"
#    "solexa_instrument_data"
#    "taxon"
#    "user"
#    "wiki-page"
#    "work-order"
);

sub show_object {
    my ($self, $type, $object) = @_;

    my $shower = $OBJECT_SHOWERS{$type};

    $shower->execute($object);
}

sub get_type_and_id {
    my $self = shift;

    my $doc = $self->get_doc;
    return ($doc->{type}, $doc->{object_id});
}

sub get_doc {
    my $self = shift;

    my $content = $self->get_content;
    return $content->{response}{docs}[0];
}

sub get_content {
    my $self = shift;

    my $response = Genome::Search->search($self->target, {rows => 1});
    unless (defined($response)) {
        die "Invalid response from Search";
    }

    $self->validate_response_content($response->content);

    return $response->content;
}


my $SCORE_WARNING_THRESHOLD = 5;
sub validate_response_content {
    my ($self, $content) = @_;

    if ($content->{response}{numFound} <= 0) {
        die "No results found";
    } elsif ($content->{response}{numFound} > 1) {
        die "Too many results found";
    }

    if ($content->{response}{maxScore} < $SCORE_WARNING_THRESHOLD) {
        warn sprintf("Warning: Low search score (%s).",
            $content->{response}{maxScore});
    }
}


1;
