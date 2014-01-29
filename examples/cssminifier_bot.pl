#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(lib ../lib);
use POE qw(
    Component::IRC
    Component::IRC::Plugin::OutputToPastebin
    Component::IRC::Plugin::CSS::Minifier
);

my $irc = POE::Component::IRC->spawn(
    nick        => 'CSSMinifierBot',
    server      => 'irc.freenode.net',
    port        => 6667,
    ircname     => 'CSSMinifierBot',
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
        'Paster' =>
            POE::Component::IRC::Plugin::OutputToPastebin->new(
                debug => 1,
            )
    );

    $irc->plugin_add(
        'CSSMinifier' =>
            POE::Component::IRC::Plugin::CSS::Minifier->new(
                debug => 1,
            )
    );

    $irc->yield( connect => {} );
}

sub irc_001 {
    $_[KERNEL]->post( $_[SENDER] => join => '#zofbot' );
}

