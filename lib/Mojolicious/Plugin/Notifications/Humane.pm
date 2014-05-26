package Mojolicious::Plugin::Notifications::Humane;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::JSON;
use File::Spec;
use File::Basename;

has json => sub {
  state $json = Mojo::JSON->new
};

has [qw/base_class base_timeout/];

# Register plugin
sub register {
  my ($plugin, $mojo, $param) = @_;

  # Set config
  $plugin->base_class(   $param->{base_class}   // 'libnotify' );
  $plugin->base_timeout( $param->{base_timeout} // 3000 );

  # Add static path to JavaScript
  push @{$mojo->static->paths},
    File::Spec->catdir( File::Basename::dirname(__FILE__), 'Humane' );
};


# Notification method
sub notifications {
  my ($self, $c, $notify_array, @post) = @_;

  my $types = shift @post if ref $post[0] && ref $post[0] eq 'ARRAY';

  return unless @$notify_array || @$types;

  my %rule;
  while ($post[-1] && index($post[-1], '-') == 0) {
    $rule{pop @post} = 1;
  };

  my $base_class = shift @post // $self->base_class;

  my $js = '';
  unless ($rule{-no_include}) {
    $js .= $c->javascript('humane.min.js');

    unless ($rule{-no_css}) {
      $js .= $c->stylesheet($base_class . '.css');;
    };
  };

  # Start JavaScript snippet
  $js .= qq{<script>\n} .
    qq!var notify=humane.create({baseCls:'humane-$base_class',timeout:! .
      $self->base_timeout . ",clickToClose:true});\n";

  my ($log, %notify) = ('');

  my $json = $self->json;

  # Add notifications
  foreach (@$notify_array) {
    $notify{$_->[0]} = 1;
    $log .= '.' . $_->[0] . '(' . $json->encode($_->[-1]);
    $log .= ', ' . $json->encode($_->[1]) if scalar @{$_} == 3;
    $log .= ')';
  };
  $log = "notify$log;\n" if $log;

  # Ceate notification classes
  foreach (sort(keys %notify), @$types) {
    $js .= "notify.$_=notify.spawn({addnCls:'humane-$base_class-$_'});\n";
  };

  return b($js . $log . '</script>');
};


1;


__END__

=pod

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Notifications::Humane - Event notification using Humane.js


=head1 SYNOPSIS

  # Register the engine
  plugin Notifications => { HTML => 1 };

  # In the template
  %= notifications


=head1 DESCRIPTION

This plugin is a notification engine using
L<Humane.js|http://wavded.github.io/humane-js/>.

If this does not suit your needs, you can easily
L<write your own engine|Mojolicious::Plugin::Notifications/Writing your own engine>.

If you want to use Humane.js without L<Mojolicious::Plugin::Notifications>,
you should have a look at L<Mojolicious::Plugin::Humane>,
which was the oriinal inspiration for this plugin.


=head1 METHODS

=head2 register

  plugin Notifications => {
    Humane => {
       base_class => 'libnotify'
    }
  };

Called when registering the main plugin.
All parameters under the key C<Humane> are passed to the registration.

Accepts the following parameters:

=over 4

=item B<base_class>

The base class for all humane notifications.
Defaults to C<libnotify>. See the
L<Humane.js documentation|http://wavded.github.io/humane-js/>
for more information.


=item B<base_timeout>

The base timeout for all humane notifications. Defaults to C>3000 ms>.
Set to C<0> for no timeout.

=back


=head1 HELPERS

=head2 notify

  # In controllers
  $c->notify(warn => 'Something went wrong');
  $c->notify(success => {
    clickToClose => Mojo::JSON->true
  } => 'Everything went fine');

Notify the user on certain events.

See the documentation for your chosen class
at L<Humane.js|http://wavded.github.io/humane-js/> to see,
which notification types are presupported.

In addition to types and messages, further refinements can
be passed at the second position.


=head2 notifications

  # In tempates
  %= notifications 'humane';
  %= notifications 'humane' => [qw/warn success/];
  %= notifications 'humane' => [qw/warn success/], -no_css;
  %= notifications 'humane' => [qw/warn success/], 'jackedup', -no_css;

Include humane notifications in your template.

You can add notification types in a list reference to ensure, they are
established (even if they were not called by L</notify>), in case you
want them to be used in conjunction with JavaScript in your application.

If you want to use a class different to the defined base class, you can
pass this as a string attribute.

If you don't want to include the javascript and css assets for Humane.js,
append C<-no_include>. If you just don't want to render the
stylesheet tag for the inclusion of the CSS, append C<-no_css>.


=head1 SEE ALSO

L<Humane.js|http://wavded.github.io/humane-js/>,
L<Mojolicious::Plugin::Humane>.


=head1 AVAILABILITY

  https://github.com/Akron/Mojolicious-Plugin-Notifications


=head1 COPYRIGHT AND LICENSE

=head2 Mojolicious::Plugin::Humane

Copyright (C) 2014, L<Nils Diewald|http://nils-diewald.de/>.

This program is free software, you can redistribute it
and/or modify it under the terms of the Artistic License version 2.0.


=head2 Humane.js (bundled)

Copyright (c) 2011, Marc Harter

See L<https://github.com/wavded/humane-js> for further information.

Licensed under the terms of the
L<MIT License|http://opensource.org/licenses/MIT>.

=cut
