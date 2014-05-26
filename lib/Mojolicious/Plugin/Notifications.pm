package Mojolicious::Plugin::Notifications;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util qw/camelize/;

our $TYPE_RE = qr/^[-a-zA-Z_]+$/;

our $VERSION = '0.1';

# Register plugin
sub register {
  my ($plugin, $mojo, $param) = @_;

  $param ||= {};

  my $debug = $mojo->mode eq 'development' ? 1 : 0;

  # Load parameter from Config file
  if (my $config_param = $mojo->config('Notifications')) {
    $param = { %$config_param, %$param };
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
  %= notifications 'humane'

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
references. If no configuration should be passed, add a scalar value.

All parameters can be set either on registration or
as part of the configuration file with the key C<Notifications>.


=head1 HELPERS

=head2 notify

  $c->notify(error => 'Something went wrong');1
  $c->notify(error => { timeout => 4000 } => 'Something went wrong');

Notify the user about an event.
Expects an event type as a string and a message.
In case a notification engine supports further refinement,
these can be passed in a hash reference passed as a second parameter.


=head2 notifications

  %= notifications humane => qw/warn error success/;
  %= notifications 'html';

  $c->render(json => $c->notifications(json => {
    text => 'My message'
  }));

Serve notifications to your user based on an engine.
The engine's name has to be passed as the first parameter
and the engine has to be L<registered|/register>.
Notifications won't be invoked in case no notifications are
in the queue and no further engine parameters are passed.
Engine parameters are documented in the respective plugins.


=head1 ENGINES

=head2 Bundled engines

L<Humane|Mojolicious::Plugin::Notifications::Humane>,
L<HTML|Mojolicious::Plugin::Notifications::HTML>,
L<JSON|Mojolicious::Plugin::Notifications::JSON>.


=head2 Writing your own engine

...


=head1 AVAILABILITY

  https://github.com/Akron/Mojolicious-Plugin-Notifications


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, L<Nils Diewald|http://nils-diewald.de/>.

Most of the code was done at the
L<Mojoconf2014|http://www.mojoconf.org/mojo2014/> hackathon.

This program is free software, you can redistribute it
and/or modify it under the terms of the Artistic License version 2.0.

=cut
