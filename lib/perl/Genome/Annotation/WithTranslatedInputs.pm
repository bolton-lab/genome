package Genome::Annotation::WithTranslatedInputs;

use strict;
use warnings;
use Genome;

class Genome::Annotation::WithTranslatedInputs {
    attributes_have => [
        is_translated => {is => 'Boolean', default => 0},
    ],
};

sub translated_inputs {
    my $self = shift;
    my $meta = $self->__meta__;
    return map {$_->property_name} $meta->properties(
        is_translated => 1,
    );
}
1;

