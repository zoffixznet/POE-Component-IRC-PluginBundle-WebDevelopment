package POE::Component::IRC::Plugin::AntiSpamMailTo;

use warnings;
use strict;

# VERSION

use HTML::Entities;
use base 'POE::Component::IRC::Plugin::BaseWrap';

sub _make_default_args {
    return (
        trigger          => qr/^mailto\s+(?=\S)/i,
        response_event   => 'irc_antispam_mailto',
        max_length       => 350,
    );
}

sub _make_response_message {
    my ( $self, $in_ref ) = @_;

    my $prefix = '';
    if ( $in_ref->{type} eq 'public' ) {
        $prefix = (split /!/, $in_ref->{who})[0] . ', ';
    }

    my $val = encode_entities( $in_ref->{what}, '\\W\\w' );
    if ( length $val > $self->{max_length} ) {
        $val = substr($val, 0, $self->{max_length}) . '...';
    }
    return $prefix . $val;
}

sub _message_into_response_event { 'out'; }

1;
__END__

=for stopwords bot bots mailto privmsg regexen usermask usermasks

=encoding utf8

=head1 NAME

POE::Component::IRC::Plugin::AntiSpamMailTo - little IRC plugin to generate mailto: links that avoid dumb spam bots

=head1 SYNOPSIS

    use strict;
    use warnings;

    use POE qw(Component::IRC  Component::IRC::Plugin::AntiSpamMailTo);

    my $irc = POE::Component::IRC->spawn(
        nick        => 'MailtoBot',
        server      => 'irc.freenode.net',
        port        => 6667,
        ircname     => 'MailtoBot',
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
            'mailto' =>
                POE::Component::IRC::Plugin::AntiSpamMailTo->new
        );

        $irc->yield( connect => {} );
    }

    sub irc_001 {
        $irc->yield( join => '#zofbot' );
    }


    Zoffix> MailtoBot, mailto mailto:zoffix@cpan.org
    <MailtoBot> &#109;&#97;&#105;&#108;&#116;&#111;&#58;&#122;&#111;
                &#102;&#102;&#105;&#120;&#64;&#99;&#112;&#97;&#110;&#46;&#111;&#114;&#103;

=head1 DESCRIPTION

This module is a small L<POE::Component::IRC> plugin which uses
L<POE::Component::IRC::Plugin> for its base. It provides interface to
generate C<< <a href="mailto:foo@bar">... >> links that escape every single characters
preventing dumb spam bots from harvesting the email addresses. I did not do any actual research
on how useful this technique actually is but people who employ it say that it's effective
as long as you encode the C<mailto:> part as well.
The plugin accepts input from public channel events, C</notice> messages as well
as C</msg> (private messages); although that can be configured at will.

=head1 CONSTRUCTOR

=head2 C<new>

    # plain and simple
    $irc->plugin_add(
        'mailto' => POE::Component::IRC::Plugin::AntiSpamMailTo->new
    );

    # juicy flavor
    $irc->plugin_add(
        'mailto' =>
            POE::Component::IRC::Plugin::AntiSpamMailTo->new(
                max_length       => 350,
                auto             => 1,
                response_event   => 'irc_antispam_mailto',
                banned           => [ qr/aol\.com$/i ],
                root             => [ qr/mah.net$/i ],
                addressed        => 1,
                trigger          => qr/^mailto\s+(?=\S)/i,
                triggers         => {
                    public  => qr/^mailto\s+(?=\S)/i,
                    notice  => qr/^mailto\s+(?=\S)/i,
                    privmsg => qr/^mailto\s+(?=\S)/i,
                },
                listen_for_input => [ qw(public notice privmsg) ],
                eat              => 1,
                debug            => 0,
            )
    );

The C<new()> method constructs and returns a new
C<POE::Component::IRC::Plugin::AntiSpamMailTo> object suitable to be
fed to L<POE::Component::IRC>'s C<plugin_add> method. The constructor
takes a few arguments, but I<all of them are optional>. B<Note:>
you can change the values of the arguments dynamically by accessing
them as hashref keys in your plugin's object; e.g. to ban some
user during runtime simply do
C<< push @{ $your_plugin_object->{banned} }, qr/user!mask/ >>
The possible arguments/values are as follows:

=head3 C<max_length>

    ->new( max_length => 350 );

B<Optional>. Takes a positive integer as a value. Specifies the maximum length of the
output (this does not include the prepended nickname or '...' at the end of cut output).
If length of the output is longer than the value you specify here it will be cut off
and C<'...'> will be appended to the output indicating it was cut off. B<Defaults to:> C<350>

=head3 C<auto>

    ->new( auto => 0 );

B<Optional>. Takes either true or false values, specifies whether or not
the plugin should auto respond to requests. When the C<auto>
argument is set to a true value plugin will respond to the requesting
person with the results automatically. When the C<auto> argument
is set to a false value plugin will not respond and you will have to
listen to the events emitted by the plugin to retrieve the results (see
EMITTED EVENTS section and C<response_event> argument for details).
B<Defaults to:> C<1>.

=head3 C<response_event>

    ->new( response_event => 'event_name_to_receive_results' );

B<Optional>. Takes a scalar string specifying the name of the event
to emit when the results of the request are ready. See EMITTED EVENTS
section for more information. B<Defaults to:> C<irc_antispam_mailto>

=head3 C<banned>

    ->new( banned => [ qr/aol\.com$/i ] );

B<Optional>. Takes an arrayref of regexes as a value. If the usermask
of the person (or thing) making the request matches any of
the regexes listed in the C<banned> arrayref, plugin will ignore the
request. B<Defaults to:> C<[]> (no bans are set).

=head3 C<root>

    ->new( root => [ qr/\Qjust.me.and.my.friend.net\E$/i ] );

B<Optional>. As opposed to C<banned> argument, the C<root> argument
B<allows> access only to people whose usermasks match B<any> of
the regexen you specify in the arrayref the argument takes as a value.
B<By default:> it is not specified. B<Note:> as opposed to C<banned>
specifying an empty arrayref to C<root> argument will restrict
access to everyone.

=head3 C<trigger>

    ->new( trigger => qr/^mailto\s+(?=\S)/i );

B<Optional>. Takes a regex as an argument. Messages matching this
regex, irrelevant of the type of the message, will be considered as requests. See also
B<addressed> option below which is enabled by default as well as
B<triggers> option which is more specific. B<Note:> the
trigger will be B<removed> from the message, therefore make sure your
trigger doesn't match the actual data that needs to be processed.
B<Defaults to:> C<qr/^mailto\s+(?=\S)/i>

=head3 C<triggers>

    ->new( triggers => {
            public  => qr/^mailto\s+(?=\S)/i,
            notice  => qr/^mailto\s+(?=\S)/i,
            privmsg => qr/^mailto\s+(?=\S)/i,
        }
    );

B<Optional>. Takes a hashref as an argument which may contain either
one or all of keys B<public>, B<notice> and B<privmsg> which indicates
the type of messages: channel messages, notices and private messages
respectively. The values of those keys are regexes of the same format and
meaning as for the C<trigger> argument (see above).
Messages matching this
regex will be considered as requests. The difference is that only messages of type corresponding to the key of C<triggers> hashref
are checked for the trigger. B<Note:> the C<trigger> will be matched
irrelevant of the setting in C<triggers>, thus you can have one global and specific "local" triggers. See also
B<addressed> option below which is enabled by default as well as
B<triggers> option which is more specific. B<Note:> the
trigger will be B<removed> from the message, therefore make sure your
trigger doesn't match the actual data that needs to be processed.
B<Defaults to:> C<qr/^mailto\s+(?=\S)/i>

=head3 C<addressed>

    ->new( addressed => 1 );

B<Optional>. Takes either true or false values. When set to a true value
all the public messages must be I<addressed to the bot>. In other words,
if your bot's nickname is C<Nick> and your trigger is
C<qr/^trig\s+/>
you would make the request by saying C<Nick, trig EXAMPLE>.
When addressed mode is turned on, the bot's nickname, including any
whitespace and common punctuation character will be removed before
matching the C<trigger> (see above). When C<addressed> argument it set
to a false value, public messages will only have to match C<trigger> regex
in order to make a request. Note: this argument has no effect on
C</notice> and C</msg> requests. B<Defaults to:> C<1>

=head3 C<listen_for_input>

    ->new( listen_for_input => [ qw(public  notice  privmsg) ] );

B<Optional>. Takes an arrayref as a value which can contain any of the
three elements, namely C<public>, C<notice> and C<privmsg> which indicate
which kind of input plugin should respond to. When the arrayref contains
C<public> element, plugin will respond to requests sent from messages
in public channels (see C<addressed> argument above for specifics). When
the arrayref contains C<notice> element plugin will respond to
requests sent to it via C</notice> messages. When the arrayref contains
C<privmsg> element, the plugin will respond to requests sent
to it via C</msg> (private messages). You can specify any of these. In
other words, setting C<( listen_for_input => [ qr(notice privmsg) ] )>
will enable functionality only via C</notice> and C</msg> messages.
B<Defaults to:> C<[ qw(public  notice  privmsg) ]>

=head3 C<eat>

    ->new( eat => 0 );

B<Optional>. If set to a false value plugin will return a
C<PCI_EAT_NONE> after
responding. If eat is set to a true value, plugin will return a
C<PCI_EAT_ALL> after responding. See L<POE::Component::IRC::Plugin>
documentation for more information if you are interested. B<Defaults to>:
C<1>

=head3 C<debug>

    ->new( debug => 1 );

B<Optional>. Takes either a true or false value. When C<debug> argument
is set to a true value some debugging information will be printed out.
When C<debug> argument is set to a false value no debug info will be
printed. B<Defaults to:> C<0>.

=head1 EMITTED EVENTS

=head2 C<response_event>

    $VAR1 = {
        'out' => 'Zoffix,
                &#109;&#97;&#105;&#108;&#116;&#111;&#58;&#122;&#111;&#102;&#102;&#105;&#120;&#6
                4;&#99;&#112;&#97;&#110;&#46;&#111;&#114;&#103;',
        'who' => 'Zoffix!n=Zoffix@unaffiliated/zoffix',
        'what' => 'mailto:zoffix@cpan.org',
        'type' => 'public',
        'channel' => '#zofbot',
        'message' => 'MailtoBot, mailto mailto:zoffix@cpan.org'
    };

The event handler set up to handle the event, name of which you've
specified in the C<response_event> argument to the constructor
(it defaults to C<irc_antispam_mailto>) will receive input
every time request is completed. The input will come in C<$_[ARG0]>
on a form of a hashref.
The possible keys/values of that hashrefs are as follows:

=head3 C<out>

    {
        'out' => 'Zoffix,
                &#109;&#97;&#105;&#108;&#116;&#111;&#58;&#122;&#111;&#102;&#102;&#105;&#120;&#6
                4;&#99;&#112;&#97;&#110;&#46;&#111;&#114;&#103;',
    }

The C<out> key will contain the message that would be outputted to IRC when C<auto> mode
in constructor is set to a true value (the default).

=head3 C<who>

    { 'who' => 'Zoffix!n=Zoffix@unaffiliated/zoffix', }

The C<who> key will contain the user mask of the user who sent the request.

=head3 C<what>

    { 'what' => 'mailto:zoffix@cpan.org', }

The C<what> key will contain user's message after stripping the C<trigger>
(see CONSTRUCTOR).

=head3 C<message>

    { 'message' => 'MailtoBot, mailto mailto:zoffix@cpan.org' }

The C<message> key will contain the actual message which the user sent; that
is before the trigger is stripped.

=head3 C<type>

    { 'type' => 'public', }

The C<type> key will contain the "type" of the message the user have sent.
This will be either C<public>, C<privmsg> or C<notice>.

=head3 C<channel>

    { 'channel' => '#zofbot', }

The C<channel> key will contain the name of the channel where the message
originated. This will only make sense if C<type> key contains C<public>.

=head1 REPOSITORY

Fork this module on GitHub:
L<https://github.com/zoffixznet/POE-Component-IRC-PluginBundle-WebDevelopment>

=head1 BUGS

To report bugs or request features, please use
L<https://github.com/zoffixznet/POE-Component-IRC-PluginBundle-WebDevelopment/issues>

If you can't access GitHub, you can email your request
to C<bug-POE-Component-IRC-PluginBundle-WebDevelopment at rt.cpan.org>

=head1 AUTHOR

Zoffix Znet <zoffix at cpan.org>
(L<http://zoffix.com/>, L<http://haslayout.net/>)

=head1 LICENSE

You can use and distribute this module under the same terms as Perl itself.
See the C<LICENSE> file included in this distribution for complete
details.

=cut

