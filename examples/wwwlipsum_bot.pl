use strict;
use warnings;

# VERSION

use lib qw(lib ../lib);
use POE qw(Component::IRC  Component::IRC::Plugin::WWW::Lipsum);

my $irc = POE::Component::IRC->spawn(
    nick        => 'LipsumBot',
    server      => 'irc.freenode.net',
    port        => 6667,
    ircname     => 'Lorem Ipsum Bot',
    plugin_debug => 1,
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
        'lipsum' =>
            POE::Component::IRC::Plugin::WWW::Lipsum->new
    );

    $irc->yield( connect => {} );
}

sub irc_001 {
    $_[KERNEL]->post( $_[SENDER] => join => '#zofbot' );
}