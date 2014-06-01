package Mojolicious::Plugin::Notifications;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util qw/camelize/;

our $TYPE_RE = qr/^[-a-zA-Z_]+$/;

our $VERSION = '0.3';

# Register plugin
sub register {
  my ($plugin, $mojo, $param) = @_;

  $param ||= {};

  my $debug = $mojo->mode eq 'development' ? 1 : 0;

  # Load parameter from Config file
  if (my $config_param = $mojo->config('Notifications')) {
    $param = { %$param, %$config_param };
  };

  unless (keys %$param) {
    $param->{HTML} = 1;
  };

  # Add engines from configuration
  my %engine;
  foreach my $name (keys %$param) {
    my $engine = camelize $name;
    if (index($engine,'::') < 0) {
      $engine = __PACKAGE__ . '::' . $engine;
    };

    # Load engine
    my $e = $mojo->plugins->load_plugin($engine);
    $e->register($mojo, ref $param->{$name} ? $param->{$name} : undef);
    $engine{lc $name} = $e;
  };


  # Add notifications
  $mojo->helper(
    notify => sub {
      my $c = shift;
      my $type = shift;
      my @msg = @_;

      # Ignore debug messages in production
      return if $type !~ $TYPE_RE || (!$debug && $type eq 'debug');

      my $array;

      # Notifications already set
      if ($array = $c->stash('notify.array')) {
	push (@$array, [$type => @msg]);
      }

      # New notifications
      else {
	$c->stash('notify.array' => [[$type => @msg]]);

	# Watch out - may break whenever something weird in the order
	# between after_dispatch and resume happens
	$c->tx->once(
	  resume => sub {
	    my $tx = shift;
	    if ($tx->res->is_status_class(300)) {
	      $c->flash('n!.a' => delete $c->stash->{'notify.array'});
	      $c->app->sessions->store($c);
	    };
	  });
      };
    }
  );


  # Embed notification display
  $mojo->helper(
    notifications => sub {
      my $c = shift;
      my $e_type = lc (shift // 'HTML');
      my @param = @_;

      my @notify_array;

      # Get flash notifications
      my $flash = $c->flash('n!.a');
      if ($flash && ref $flash eq 'ARRAY') {

	# Ensure that no harmful types are injected
	push @notify_array, grep { $_->[0] =~ $TYPE_RE } @$flash;

	# Use "n!.a" instead of notify.array as this goes into the cookie
	$c->flash('n!.a' => undef);
      };

      # Get stash notifications
      if ($c->stash('notify.array')) {
	push @notify_array, @{ delete $c->stash->{'notify.array'} };
      };

      # Nothing to do
      return '' unless @notify_array || @_;

      # Forward messages to notification center
      if (exists $engine{$e_type}) {
	return $engine{$e_type}->notifications($c, \@notify_array, @param);
      }
      else {
	$c->app->log->error(qq{Unknown notification engine "$e_type"});
	return;
      };
    }
  );
};


1;


__END__

=pod

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Notifications - Event Notifications for your Users


=head1 SYNOPSIS

  # Register the plugin and several engines
  plugin Notifications => {
    Humane => {
      base_class => 'libnotify'
    },
    JSON => 1
  };

  # Add notification messages in controllers
  $c->notify(warn => 'Something went wrong');

  # Render notifications in templates ...
  %= notifications 'humane';

  # ... or in any other responses
  my $json = { text => 'That\'s my response' };
  $c->render(json => $c->notifications(json => $json));


=head1 DESCRIPTION

L<Mojolicious::Plugin::Notifications> supports several engines
to notify users on events. Notifications will survive redirects
and can be served depending on response types.


=head1 METHODS

L<Mojolicious::Plugin::Notifications> inherits all methods
from L<Mojolicious::Plugin> and implements the following new one.

=head2 register

  plugin Notifications => {
    Humane => {
      base_class => 'libnotify'
    },
    HTML => 1
  };

Called when registering the plugin.

Accepts the registration of multiple L<engines|/ENGINES> for notification
responses. Configurations of the engines can be passed as hash
references. If no configuration should be passed, just pass a scalar value.

All parameters can be set either as part of the configuration
file with the key C<Notifications> or on registration
(that can be overwritten by configuration).


=head1 HELPERS

=head2 notify

  $c->notify(error => 'Something went wrong');1
  $c->notify(error => { timeout => 4000 } => 'Something went wrong');

Notify the user about an event.
Expects an event type and a message as strings.
In case a notification engine supports further refinements,
these can be passed in a hash reference as a second parameter.
Event types are free and its treatment is up to the engines,
however notifications of the type C<debug> will only be passed in
development mode.

=head2 notifications

  %= notifications 'humane' => [qw/warn error success/];
  %= notifications 'html';

  $c->render(json => $c->notifications(json => {
    text => 'My message'
  }));

Serve notifications to your user based on an engine.
The engine's name has to be passed as the first parameter
and the engine has to be L<registered|/register> in advance.
Notifications won't be invoked in case no notifications are
in the queue and no further engine parameters are passed.
Engine parameters are documented in the respective plugins.


=head1 ENGINES

=head2 Bundled engines

The following engines are bundled with this plugin:
L<HTML|Mojolicious::Plugin::Notifications::HTML>,
L<JSON|Mojolicious::Plugin::Notifications::JSON>,
L<Humane.js|Mojolicious::Plugin::Notifications::Humane>, and
L<Alertify.js|Mojolicious::Plugin::Notifications::Alertify>,


=head2 Writing your own engine

A notification engine is a simple L<Mojolicious::Plugin>, having a C<register> method
and a C<notifications> method.
The register method is called when the engine is loaded and can be used to establish
further configurations, helpers, hooks etc. There is no need to define anything in
the method.

The C<notifications> method will be called whenever notifications are rendered.
The first parameter passed is the plugin object, the second parameter is the current
controller object and the third parameter is an array reference containing all
notifications as array references. The first element of the notification is the
notification type, the last element is the message. An optional second element may
contain further parameters in a hash reference.

All parameters passed to the L<notifications> helper following the engine's name are
appended.

The L<bundled engines|/Bundled engines> can serve as good examples on how
to write an engine, especially the simple
L<HTML|Mojolicious::Plugin::Notifications::HTML> engine.


=head1 AVAILABILITY

  https://github.com/Akron/Mojolicious-Plugin-Notifications


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, L<Nils Diewald|http://nils-diewald.de/>.

Part of the code was written at the
L<Mojoconf 2014|http://www.mojoconf.org/mojo2014/> hackathon.

This program is free software, you can redistribute it
and/or modify it under the terms of the Artistic License version 2.0.

=cut
