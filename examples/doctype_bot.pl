#!/usr/bin/env perl

use strict;
use warnings;

# VERSION

use lib qw(lib ../lib);
use POE qw(Component::IRC  Component::IRC::Plugin::WWW::DoctypeGrabber);

my $irc = POE::Component::IRC->spawn(
    nick        => 'DoctypeBot',
    server      => 'irc.freenode.net',
    port        => 6667,
    ircname     => 'DoctypeBot',
);

POE::Session->create(
    package_states => [
        main => [ qw(_start irc_001) ],
    ],
);

$poe_kernel->run;

sub _start {
    $irc->yield( register => 'all' );

    $irc->plugin_add(
        'Doctype' =>
            POE::Component::IRC::Plugin::WWW::DoctypeGrabber->new
    );

    $irc->yield( connect => {} );
}

sub irc_001 {
    $_[KERNEL]->post( $_[SENDER] => join => '#zofbot' );
}

