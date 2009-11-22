package Nagios::Web::Controller::cmd;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::cmd - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

######################################
# index page
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{infoBoxTitle}   = "External Command Interface";
    $c->stash->{no_auto_reload} = 1;
    $c->stash->{page}           = 'cmd';


    my $cmd_typ = $c->{'request'}->{'parameters'}->{'cmd_typ'};
    $c->detach('/error/index/6') unless defined $cmd_typ;

    my $cmd_mod = $c->{'request'}->{'parameters'}->{'cmd_mod'};
    if(defined $cmd_mod) {
        use Data::Dumper;
        $c->log->debug(Dumper($c->{'request'}->{'parameters'}));
    }

    $c->stash->{template} = 'cmd/cmd_typ_'.$cmd_typ.'.tt';
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
