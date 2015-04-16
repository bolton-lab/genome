package Genome::Config::AnalysisProject::Command::AddMenuItem;

use strict;
use warnings;

use Genome;

class Genome::Config::AnalysisProject::Command::AddMenuItem {
    is => 'Genome::Config::AnalysisProject::Command::Base',
    has_input => [
        analysis_menu_items => {
            is                  => 'Genome::Config::AnalysisMenu::Item',
            is_optional         => 1,
            is_many             => 1,
            doc                 => 'the analysis menu items to associate with this project.',
            require_user_verify => 1,
        },
        reprocess_existing => {
            is => 'Boolean',
            default_value => 0,
            doc => 'Reprocess any existing instrument data with the new config',
        },
        tag => {
            is => 'Genome::Config::Tag',
            is_many => 1,
            doc => 'Tags to associate with the menu items',
            is_optional => 1,
        }
    ],
};

sub help_brief {
    return 'add a menu item to an existing analysis project';
}

sub help_synopsis {
    return <<"EOS";
genome config analysis-project add-menu-item <analysis-project>
genome config analysis-project add-menu-item --analysis-menu-item <menu-item> <analysis-project>
EOS
}

sub help_detail {
    return <<"EOS"
This command is used to link standard configurations ("menu items") to an analysis-project.

If run without specifying any menu items, an interactive prompt will allow selections from the list
of all available menu items.

(See also `genome config analysis-project add-config-file for adding a custom configuration.)
EOS
}

sub valid_statuses {
    return ("Pending", "Hold", "In Progress", "Template");
}

sub execute {
    my $self = shift;

    eval {
        my $menu_items = $self->_get_menu_items();
        my $config_items = $self->_add_config_items_to_project($self->analysis_project, $menu_items);
    };
    if (my $error = $@) {
        $self->error_message('Failed to add to Analysis Project!');
        die($error);
    }

    if($self->reprocess_existing){
        Genome::Config::AnalysisProject::Command::Reprocess->execute(
            analysis_project => $self->analysis_project
        );
    }

    return $self->analysis_project;
}

sub _get_menu_items {
    my $self = shift;

    if ($self->analysis_menu_items()) {
        return [$self->analysis_menu_items];
    } else {
        my $class_name = 'Genome::Config::AnalysisMenu::Item';
        return [$self->resolve_param_value_from_cmdline_text(
                {
                    name => 'analysis_menu_items',
                    class => $class_name,
                    value => [$class_name->get()],
                }
            )];
    }
}

sub _add_config_items_to_project {
    my $self = shift;
    my $project = shift;
    my $menu_items = shift;

    for (@$menu_items) {
        my $item = Genome::Config::Profile::Item->create(
            analysis_menu_item => $_,
            analysis_project => $project,
            status => 'active',
        );
        $self->_apply_tags($item);
    }

    return 1;
}

sub _apply_tags {
    my ($self, $profile_item) = @_;
    for my $tag ($self->tag){
        $profile_item->add_tag($tag);
    }
    return 1;
}

1;
