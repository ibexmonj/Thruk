package Thruk::BP::Components::Node;

use strict;
use warnings;
use Thruk::Utils;
use Thruk::BP::Functions;
use Thruk::BP::Utils;

=head1 NAME

Thruk::BP::Components::Node - Node Class

=head1 DESCRIPTION

Business Process Node

=head1 METHODS

=cut

my @stateful_keys = qw/status status_text last_check last_state_change short_desc
                       scheduled_downtime_depth acknowledged/;

##########################################################

=head2 new

return new node

=cut

sub new {
    my ( $class, $data ) = @_;
    my $self = {
        'id'                => $data->{'id'},
        'label'             => $data->{'label'},
        'function'          => '',
        'function_ref'      => undef,
        'function_args'     => [],
        'depends'           => Thruk::Utils::list($data->{'depends'} || []),
        'parents'           => $data->{'parents'} || [],
        'host'              => '',
        'service'           => '',
        'scheduled_downtime_depth' => 0,
        'acknowledged'      => 0,

        'status'            => defined $data->{'status'} ? $data->{'status'} : 4,
        'status_text'       => $data->{'status_text'} || '',
        'short_desc'        => $data->{'short_desc'}  || '',
        'last_check'        => 0,
        'last_state_change' => 0,
    };
    bless $self, $class;

    $self->_set_function($data);

    return $self;
}

##########################################################

=head2 load_runtime_data

update runtime data

=cut
sub load_runtime_data {
    my($self, $data) = @_;
    # return if there is a a newer result already
    if($self->{'last_state_change'} && $data->{'last_state_change'} && $self->{'last_state_change'} >= $data->{'last_state_change'}) {
        return;
    }
    for my $key (@stateful_keys) {
        $self->{$key} = $data->{$key} if defined $data->{$key};
    }
    return;
}

##########################################################

=head2 set_id

set new id for this node

=cut
sub set_id {
    my($self, $id) = @_;
    $self->{'id'} = $id;
    return;
}

##########################################################

=head2 append_child

append new child noew

=cut
sub append_child {
    my($self, $append) = @_;
    push @{$self->{'depends'}}, $append;
    return;
}

##########################################################

=head2 get_stateful_data

return data which needs to be statefully stored

=cut
sub get_stateful_data {
    my($self) = @_;
    my $data = {};
    for my $key (@stateful_keys) {
        $data->{$key} = $self->{$key};
    }
    return $data;
}

##########################################################

=head2 save_to_string

get textual representation of this node

=cut
sub save_to_string {
    my ( $self ) = @_;
    my $string = "  <node>\n";

    # normal keys
    for my $key (qw/id label host service/) {
        $string .= sprintf("    %-10s = %s\n", $key, $self->{$key});
    }

    # function
    if($self->{'function'}) {
        $string .= sprintf("    %-10s = %s(%s)\n", "function", $self->{'function'}, Thruk::BP::Utils::join_args($self->{'function_args'}));
    }

    # depends
    for my $d (@{$self->{'depends'}}) {
        $string .= sprintf("    %-10s = %s\n", 'depends', $d->{'id'});
    }
    $string .= "  </node>\n";
    return $string;
}

##########################################################

=head2 update_status

update status of node

=cut
sub update_status {
    my($self, $c, $bp) = @_;
    delete $bp->{'need_update'}->{$self->{'id'}};

    return unless $self->{'function_ref'};
    my $function = $self->{'function_ref'};
    eval {
        my($status, $short_desc, $status_text, $extra) = &$function($c, $bp, $self, @{$self->{'function_args'}});
        $self->_set_status($status, ($status_text || $short_desc), $bp, $extra);
        $self->{'short_desc'} = $short_desc;
    };
    if($@) {
        $self->_set_status(3, 'Internal Error: '.$@, $bp);
    }

    return;
}

##########################################################
sub _set_status {
    my($self, $state, $text, $bp, $extra) = @_;

    my $last_state = $self->{'status'};

    # update last check time
    my $now = time();
    $self->{'last_check'} = $now;

    $self->{'status'}      = $state;
    $self->{'status_text'} = $text;

    if($last_state != $state) {
        $self->{'last_state_change'} = $now;
        # put parents on update list
        if($bp) {
            for my $p (@{$self->{'parents'}}) {
                $bp->{'need_update'}->{$p->{'id'}} = $p;
            }
        }
    }

    # update some extra attributes
    for my $key (qw/last_check last_state_change scheduled_downtime_depth acknowledged/) {
        $self->{$key} = $extra->{$key} if defined $extra->{$key};
    }

    # if this node has no parents, use this state for the complete bp
    if($bp and scalar @{$self->{'parents'}} == 0) {
        my $text = $self->{'status_text'};
        if(scalar @{$self->{'depends'}} > 0) {
            my $sum = Thruk::BP::Functions::_get_nodes_grouped_by_state($self, $bp);
            if($sum->{'3'}) {
                $text = Thruk::BP::Utils::join_labels($sum->{'3'}).' unknown';
            }
            elsif($sum->{'2'}) {
                $text = Thruk::BP::Utils::join_labels($sum->{'2'}).' failed';
            }
            elsif($sum->{'1'}) {
                $text = Thruk::BP::Utils::join_labels($sum->{'1'}).' warning';
            }
            else {
                $text = 'everyhing is fine';
            }
            $text = Thruk::BP::Utils::state2text($self->{'status'}).' - '.$text;
        }
        $bp->set_status($self->{'status'}, $text);
    }
    return;
}

##########################################################
sub _set_function {
    my($self, $data) = @_;
    if($data->{'function'}) {
        my($fname, $fargs) = $data->{'function'} =~ m|^(\w+)\((.*)\)|mx;
        my $function = \&{'Thruk::BP::Functions::'.lc($fname)};
        if(!defined &$function) {
            $self->_set_status(3, 'Unknown function: '.($fname || $data->{'function'}));
        } else {
            $self->{'function_args'} = Thruk::BP::Utils::clean_function_args($fargs);
            $self->{'function_ref'}  = $function;
            $self->{'function'}      = $fname;
        }
    }
    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;