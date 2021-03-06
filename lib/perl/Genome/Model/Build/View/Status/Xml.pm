#:boberkfe this looks like a good place to use memcache to cache up some build status.
#:boberkfe when build events update, stuff their status into memcache.  gathering info otherwise
#:boberkfe can get reaaaaal slow.

package Genome::Model::Build::View::Status::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;
use XML::LibXSLT;

class Genome::Model::Build::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has => [
        _doc    => {
            is_transient => 1,
            doc => 'the XML::LibXML document object used to build the content for this view'
        },
    ],
    has_optional => [
        section => {
            is => 'String',
            doc => "NOT IMPLEMENTED YET.  The sub-section of the document to return.  Options are 'all', 'events', etc.",
        },
    ],
};

# this is expected to return an XML string
# it has a "subject" property which is the model we're viewing
sub _generate_content {
    my $self = shift;

    #create the XML doc and add it to the object
    my $doc = XML::LibXML->createDocument();
    $self->_doc($doc);

    my $subject = $self->subject;
    return unless $subject;

    my $return_value = 1;

    #create the xml nodes and fill them up with data
    #root node
    my $build_status_node = $doc->createElement("build-status");
    my $time = UR::Context->current->now();
    $build_status_node->addChild( $doc->createAttribute("generated-at",$time) );

    #build node
    my $buildnode = $self->get_build_node();
    $build_status_node->addChild($buildnode);

    #processing profile--may fail if error grabbing events, but not critical to the view
    eval { $buildnode->addChild ( $self->get_processing_profile_node() ) };

    #TODO:  add method to build for logs, reports
    #$buildnode->addChild ( $self->tnode("logs","") );
    $buildnode->addChild ( $self->get_reports_node );

    #set the build status node to be the root
    $doc->setDocumentElement($build_status_node);

    #generate the XML string
    return $doc->toString(1);

}

=cut
    #print to the screen if desired
    if ( $self->display_output ) {
        if ( lc $self->output_format eq 'html' ) {
            print $self->to_html($self->_xml);
        } else {
            print $self->_xml;
        }
    }

    return $return_value;
sub xml {
    my $self = shift;
    return $self->_xml;
}

=cut

sub get_root_node {
    my $self = shift;
    return $self->_doc;
}


sub get_reports_node {
    my $self = shift;
    my $build = $self->subject;
    my $report_dir = $build->resolve_reports_directory;
    my $reports_node = $self->anode("reports", "directory", $report_dir);
    my @report_list = $build->reports;
    for my $each_report (@report_list) {
        my $report_node = $self->anode("report","name", $each_report->name );
        $self->add_attribute($report_node, "subdirectory", $each_report->name_to_subdirectory($each_report->name) );
        $reports_node->addChild($report_node);
    }

    return $reports_node;
}

sub get_events_node {
    my $self = shift;
    my $doc = $self->_doc;

    my $events_list = $doc->createElement("events");
    my @events = $self->subject->events;

    for my $event (@events) {
        my $event_node = $self->get_event_node($event);
        $events_list->addChild($event_node);
    }

    return $events_list;

}

sub get_build_node {

    my $self = shift;
    my $doc = $self->_doc;

    my $buildnode = $doc->createElement("build");

    my $build = $self->subject;
    my $model = $build->model;
    my $subject = $model->subject;

    my $source;
    if ($subject && $subject->can("source")) {
        $source = $subject->source;
    }

    my $disk_allocation = $build->disk_allocation;
    my $kb_requested = ($disk_allocation ? $disk_allocation->kilobytes_requested : 0);

    # grab any build-event allocations as well to include into total allocation held
    my @events = $build->events;
    my @event_allocations = Genome::Disk::Allocation->get(owner_id=>[map {$_->id} @events]);

    for (@event_allocations) {
        $kb_requested += $_->kilobytes_requested;
    }

    if (not defined $disk_allocation) {
        $kb_requested .= ' (incomplete)';
    }


    $buildnode->addChild( $doc->createAttribute("model-name",$model->name) );
    $buildnode->addChild( $doc->createAttribute("run-by", $build->run_by) );
    $buildnode->addChild( $doc->createAttribute("model-subject",$model->subject->__display_name__) );
    $buildnode->addChild( $doc->createAttribute("model-id",$model->id) );
    if ($source) {
        $buildnode->addChild(
            $doc->createAttribute("common-name", $source->common_name || 'UNSPECIFIED!')
        );
    }
    $buildnode->addChild( $doc->createAttribute("build-id",$build->id) );
    $buildnode->addChild( $doc->createAttribute("status",$build->status) );

    $buildnode->addChild( $doc->createAttribute("metric-count", ($build->status eq 'Succeeded' ? scalar @{[ $build->metrics ]} : 0) ) );

    if ($kb_requested) {
        $buildnode->addChild( $doc->createAttribute("kilobytes-requested",$kb_requested) );
    }
    $buildnode->addChild( $doc->createAttribute("data-directory",$build->data_directory) );

    $buildnode->addChild( $doc->createAttribute("software-revision", $build->software_revision) );

    my $event = $build->build_event;
    if ($event) {
        $buildnode->addChild( $doc->createAttribute("lsf-job-id", $event->lsf_job_id));

        my $out_log_file = $event->resolve_log_directory . "/" . $event->id . ".out";
        my $err_log_file = $event->resolve_log_directory . "/" . $event->id . ".err";

        if (-e $out_log_file) {
            $buildnode->addChild( $doc->createAttribute("output-log",$out_log_file));
        }
        if (-e $err_log_file) {
            $buildnode->addChild( $doc->createAttribute("error-log",$err_log_file));
        }
    }

    $buildnode->addChild( $doc->createAttribute("summary-report", $self->get_summary_report_location) );
    if ($build->can('genotype_microarray_build') and $build->genotype_microarray_build) {
        $buildnode->addChild( $doc->createAttribute("snp-array-concordance", $self->get_snp_array_concordance_url) );
    }

    $buildnode->addChild($self->get_model_node);

    $buildnode->addChild($self->get_inputs_node);
    $buildnode->addChild($self->get_links_node);
    $buildnode->addChild($self->get_notes_node);

    return $buildnode;
}

#Separate method to make it easy to override in subclasses
sub get_summary_report_location {
    my $self = shift;
    my $build = $self->subject;

    #A default value equivalent to what was previously hardcoded in the XSL.
    return $build->reports_directory . '/Summary/report.html';
}

sub get_snp_array_concordance_url {
    my $self = shift;
    my $build = $self->subject;
    my $url = "view/genome/model/build/set/intersect-snv.html?-" .
              "standard_build_id=" . $build->genotype_microarray_build->id . "&id=" . $build->id;
    return $url;
}

sub get_model_node {
    my $self = shift;
    my $doc = $self->_doc;

    my $modelnode = $doc->createElement("model");

    my $model = $self->subject->model;

    #For generating links
    $modelnode->addChild( $doc->createAttribute("id", $model->id) );
    $modelnode->addChild( $doc->createAttribute("type", $model->class) );
    my $namenode = $modelnode->addChild( $self->anode('aspect', 'name', 'name') );
    $namenode->addChild( $self->tnode('value', $model->name));

    my $model_subject = $model->subject;
    my $model_subject_aspect = $modelnode->addChild( $self->anode('aspect', 'name', 'subject') );
    my $model_subject_object = $model_subject_aspect->addChild( $doc->createElement('object') );

    $model_subject_object->addChild( $doc->createAttribute("id", $model_subject->id) );
    $model_subject_object->addChild( $doc->createAttribute("type", $model_subject->class) );
    $model_subject_object->addChild( $self->tnode('display_name', $model_subject->__display_name__) );

    return $modelnode;
}

sub get_processing_profile_node {

    my $self = shift;
    my $build = $self->subject;
    my $model = $build->model;
    my $doc = $self->_doc;


    my $pp = $model->processing_profile;
    my $pp_name = $pp->name;
    my $pp_type = $pp->type_name;

    my $stages_node = $self->anode("stages","processing_profile",$pp_name);
    $stages_node->addChild( $doc->createAttribute("processing_profile_id", $pp->id));
    $stages_node->addChild( $doc->createAttribute("processing_profile_type", $pp_type));

    if($pp->can('stages')) {

        for my $stage_name ($pp->stages($build)) {
            my $stage_node = $self->anode("stage","value",$stage_name);
            my $commands_node = $doc->createElement("command_classes");
            my $operating_on_node = $doc->createElement("operating_on");

            my @objects = $pp->objects_for_stage($stage_name,$model);
            foreach my $object (@objects) {

                my $object_node;

                if (ref($object) eq "HASH" && exists $object->{segment}) {
                    $object = $object->{object};
                }

                #if we have a full blown object (REF), get the object data
                if ( ref(\$object) eq "REF" ) {
                    if ($object->isa('Genome::InstrumentData')) {
                        my $id_node = $self->get_instrument_data_node($object);
                        $object_node = $self->anode("object","value","instrument_data");
                        $object_node->addChild($id_node);
                    } else {
                        $object_node = $self->anode("object","value",$object);
                    }
                } else {
                    $object_node = $self->anode("object","value",$object);
                }

                $operating_on_node->addChild($object_node);
            }

            my @command_classes = $pp->classes_for_stage($stage_name, $model);
            foreach my $classes (@command_classes) {
                #$commands_node->addChild( $self->anode("command_class","value",$classes ) );
                my $command_node =  $self->anode("command_class","value",$classes );
                #get the events for each command class
                $command_node->addChild($self->get_events_for_class_node($classes));
                $commands_node->addChild( $command_node );
            }
            $stage_node->addChild($commands_node);
            $stage_node->addChild($operating_on_node);
            $stages_node->addChild($stage_node);
        }
    }

    return $stages_node;
}

sub get_events_for_class_node {
    my $self = shift;
    my $class = shift;
    my $doc = $self->_doc;
    my $build = $self->subject;

    my $events_list_node = $doc->createElement("events");
    my @events = $class->get( model_id => $build->model->id, build_id => $build->id);

    unless(@events) {
        #Try to find an event for this stage that may not exist anymore
        my @all_events = $build->events;
        my $type = $class->command_name;
        @events = grep($_->event_type =~ /^$type/, @all_events);
    }

    for my $event (@events) {
        my $event_node = $self->get_event_node($event);
        $events_list_node->addChild($event_node);
    }

    return $events_list_node;

}


sub get_instrument_data_node {

    my $self = shift;
    my $object = shift;

    my $id = $self->anode("instrument_data","id", $object->id);
    for (qw/flow_cell_id project_name run_name run_identifier read_length library_name library_id lane subset_name run_type gerald_directory id/) {
        if ($object->class ne 'Genome::InstrumentData::Imported' && $object->can($_)) {
            $id->addChild($self->tnode($_, $object->$_));
        } else {
            $id->addChild($self->tnode($_, "N/A"));
        }
    }

    return $id;

}

sub get_inputs_node {
    my $self = shift;
    my $doc = $self->_doc;
    my $build = $self->subject;

    my $aspect_node = $doc->createElement('aspect');
    $aspect_node->addChild( $doc->createAttribute('name', 'inputs') );

    my @inputs = $build->inputs;

    for my $input (@inputs) {
        my $view = $input->create_view(
            perspective => 'default',
            toolkit => 'xml',
            aspects => [ 'name', 'value_class_name', 'value_id', 'value' ],
            parent_view => $self,
        );

        $view->_generate_content;

        my $delegate_xml_doc = $view->_xml_doc;
        my $delegate_root = $delegate_xml_doc->documentElement;
        #cloneNode($deep = 1)
        $aspect_node->addChild( $delegate_root->cloneNode(1) );
    }

    return $aspect_node;
}

sub get_links_node {
    my $self = shift;
    my $doc = $self->_doc;
    my $build = $self->subject;

    my $links_node = $doc->createElement('links');

    my $to_aspect_node = $doc->createElement('aspect');
    $to_aspect_node->addChild( $doc->createAttribute('name', 'to_builds'));
    $links_node->addChild($to_aspect_node);

    for my $to_build ( $build->to_builds ) {
        my $view = $to_build->create_view(
            perspective => 'default',
            toolkit => 'xml',
            aspects => ['id'],
            parent_view => $self,
        );

        $view->_generate_content;

        my $delegate_xml_doc = $view->_xml_doc;
        my $delegate_root = $delegate_xml_doc->documentElement;
        #cloneNode($deep = 1)
        $to_aspect_node->addChild( $delegate_root->cloneNode(1) );
    }

    my $from_aspect_node = $doc->createElement('aspect');
    $from_aspect_node->addChild( $doc->createAttribute('name', 'from_builds'));
    $links_node->addChild($from_aspect_node);

    for my $from_build ( $build->from_builds ) {
        my $view = $from_build->create_view(
            perspective => 'default',
            toolkit => 'xml',
            aspects => ['id'],
            parent_view => $self,
        );

        $view->_generate_content;

        my $delegate_xml_doc = $view->_xml_doc;
        my $delegate_root = $delegate_xml_doc->documentElement;
        #cloneNode($deep = 1)
        $from_aspect_node->addChild( $delegate_root->cloneNode(1) );
    }

    return $links_node;
}

sub get_notes_node {
    my $self = shift;
    my $build = $self->subject;
    my $doc = $self->_doc;
    my $parser = XML::LibXML->new();

    my $notes_node = $doc->createElement('aspect');
    $notes_node->addChild( $doc->createAttribute("name", "notes") );

    my @notes = $build->notes;
    for my $note ( @notes ) {
        my $v         = Genome::MiscNote::View::Status::Xml->create(subject => $note);
        my $xml       = $v->content;
        my $note_node = $parser->parse_string($xml);
        my $note_root = $note_node->getDocumentElement;
        $notes_node->addChild($note_root);
    }

    return $notes_node;
}

sub get_event_node {

    my $self = shift;
    my $event = shift;
    my $doc = $self->_doc;

    my $event_node = $self->anode("event","id",$event->id);
    $event_node->addChild( $doc->createAttribute("command_class",$event->class));
    $event_node->addChild( $self->tnode("event_status",$event->event_status));
    $event_node->addChild( $self->tnode("date_scheduled",$event->date_scheduled));
    $event_node->addChild( $self->tnode("date_completed",$event->date_completed));
    $event_node->addChild( $self->tnode("elapsed_time", $self->calculate_elapsed_time($event->date_scheduled,$event->date_completed) ));
    $event_node->addChild( $self->tnode("instrument_data_id",$event->instrument_data_id));

    return $event_node;
}

sub create_node_with_attribute {

    my $self = shift;
    my $node_name = shift;
    my $attr_name = shift;
    my $attr_value = shift;

    my $doc = $self->_doc;

    my $node = $doc->createElement($node_name);
    $node->addChild($doc->createAttribute($attr_name,$attr_value));
    return $node;

}

#helper methods.  just pass through to the more descriptive names
#anode = attribute node
sub anode {
    my $self = shift;
    return $self->create_node_with_attribute(@_);
}

#tnode = text node
sub tnode {
    my $self = shift;
    return $self->create_node_with_text(@_);
}

sub create_node_with_text {

    my $self = shift;
    my $node_name = shift;
    my $node_value = shift;

    my $doc = $self->_doc;

    my $node = $doc->createElement($node_name);
    if ( defined($node_value) ) {
        $node->addChild($doc->createTextNode($node_value));
    }
    return $node;

}

sub add_attribute {
    my $self = shift;
    my $node = shift;
    my $attr_name = shift;
    my $attr_value = shift;

    my $doc = $self->_doc;

    $node->addChild($doc->createAttribute($attr_name,$attr_value) );
    return $node;

}

sub calculate_elapsed_time {
    my $self = shift;
    my $date_scheduled = shift;
    my $date_completed = shift;

    my $diff;

    if ($date_completed) {
        $diff = UR::Time->datetime_to_time($date_completed) - UR::Time->datetime_to_time($date_scheduled);
    } else {
        $diff = time - UR::Time->datetime_to_time( $date_scheduled);
    }

    # convert seconds to days, hours, minutes
    my $seconds = $diff;
    my $days = int($seconds/(24*60*60));
    $seconds -= $days*24*60*60;
    my $hours = int($seconds/(60*60));
    $seconds -= $hours*60*60;
    my $minutes = int($seconds/60);
    $seconds -= $minutes*60;

    my $formatted_time;
    if ($days) {
        $formatted_time = sprintf("%d:%02d:%02d:%02d",$days,$hours,$minutes,$seconds);
    } elsif ($hours) {
        $formatted_time = sprintf("%02d:%02d:%02d",$hours,$minutes,$seconds);
    } elsif ($minutes) {
        $formatted_time = sprintf("%02d:%02d",$minutes,$seconds);
    } else {
        $formatted_time = sprintf("%02d:%02d",$minutes,$seconds);
    }

    return $formatted_time;

}

1;
