package Mojolicious::Plugin::Notifications::Alertify;
use Mojo::Base 'Mojolicious::Plugin::Notifications::Engine';
use Mojolicious::Plugin::Notifications::HTML qw/notify_html/;
use Mojo::ByteStream 'b';
use Mojo::Util qw/xml_escape quote/;
use Mojo::JSON qw/decode_json encode_json/;
use File::Spec;
use File::Basename;

has [qw/base_class base_timeout/];
state $path = '/alertify/';

# Register plugin
sub register {
  my ($plugin, $app, $param) = @_;

  # Set config
  $plugin->base_class(   $param->{base_class}   // 'default' );
  $plugin->base_timeout( $param->{base_timeout} // 5000 );

  $plugin->scripts($path . 'alertify.min.js');
  $plugin->styles(
    $path . 'alertify.core.css',
    $path . 'alertify.' . $plugin->base_class . '.css'
  );

  # Add static path to JavaScript
  push @{$app->static->paths},
    File::Spec->catdir( File::Basename::dirname(__FILE__), 'Alertify' );
};

# Notification method
sub notifications {
  my ($self, $c, $notify_array, $rule, @post) = @_;

  my $theme = shift @post // $self->base_class;

  my $js = '';
  unless ($rule->{no_include}) {
    $js .= $c->javascript( $self->scripts );

    unless ($rule->{no_css}) {
      $js .= $c->stylesheet( ($self->styles)[0] );
      $js .= $c->stylesheet( $path . 'alertify.' . $theme . '.css');
    };
  };

  # Start JavaScript snippet
  $js .= qq{<script>//<![CDATA[\n};
  my $noscript = "<noscript>";

  sub _ajax ($) {
    return 'r.open("POST",' . quote($_[0]) . ');r.send()';
  };

  # Add notifications
  foreach (@$notify_array) {

    # Get parameter
    my $param = $_->[1] if scalar @{$_} == 3;

    # Confirmation
    if ($param && ($param->{ok} || $param->{cancel})) {

      # Set labels
      if ($param->{ok_label} || $param->{cancel_label}) {
        $js .= 'alertify.set({labels:{';
        $js .= 'ok:'.quote($param->{ok_label} // 'OK') . ',' ;
        $js .= 'cancel:'.quote($param->{cancel_label} // 'Cancel');
        $js .= "}});\n";
      };

      # Create confirmation
      $js .= 'alertify.confirm(' . quote($_->[-1]);
      $js .= ',function(ok){';
      $js .= 'var r=new XMLHttpRequest();';
      if ($param->{ok} && $param->{cancel}) {
        $js .= 'if(ok){'. _ajax($param->{ok}) .
          '}else{' . _ajax($param->{cancel}) . '};';
      }
      elsif ($param->{ok}) {
        $js .= 'if(ok){' . _ajax($param->{ok}) . '};';
      }
      else {
        $js .= 'if(!ok){' . _ajax($param->{cancel}) . '};';
      };
      $js .= '},' . quote('notify notify-' . $_->[0]) . ");\n";
    }

    # Normal alert
    else {
      $js .= 'alertify.log(' . quote($_->[-1]);
      $js .= ',' . quote($_->[0]) . ',';
      if ($param) {
        $js .= $param->{timeout} // $self->base_timeout;
      }
      else {
        $js .= $self->base_timeout
      };
      $js .= ");\n";
    };
    $noscript .= notify_html(@$_);
  };

  return b($js . "//]]>\n</script>\n" . $noscript . '</noscript>');
};


1;


__END__

=pod

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Notifications::Alertify - Event notifications using Alertify.js


=head1 SYNOPSIS

  # Register the engine
  plugin Notifications => {
    Alertify => {
      base_class => 'bootstrap'
    }
  };

  # In the template
  %= notifications 'Alertify'


=head1 DESCRIPTION

This plugin is a notification engine using
L<Alertify.js|http://fabien-d.github.io/alertify.js/>.

If this does not suit your needs, you can easily
L<write your own engine|Mojolicious::Plugin::Notifications::Engine>.


=head1 METHODS

L<Mojolicious::Plugin::Notifications::Alertify> inherits all methods
from L<Mojolicious::Plugin::Notifications::Engine> and implements or overrides
the following.

=head2 register

  plugin Notifications => {
    Alertify => {
       base_class => 'bootstrap'
    }
  };

Called when registering the main plugin.
All parameters under the key C<Alertify> are passed to the registration.

Accepts the following parameters:

=over 4

=item B<base_class>

The theme for all alertify notifications.
Defaults to C<bootstrap>. See the
L<Alertify.js documentation|https://github.com/fabien-d/alertify.js>
for more information on themes.


=item B<base_timeout>

The base timeout for all alertify notifications. Defaults to C<5000 ms>.
Set to C<0> for no timeout.

=back


=head1 HELPERS

=head2 notify

  # In controllers
  $c->notify(warn => 'Something went wrong');
  $c->notify(success => { timeout => 2000 } => 'Everything went fine');
  $c->notify(success => { ok => 'http://example.com/ok' } => 'Everything went fine');

Notify the user on certain events.

See the documentation for your chosen theme
at L<Alertify.js|http://fabien-d.github.io/alertify.js/> to see,
which notification types are presupported.

In addition to types and messages, the C<timeout> can be defined
in a hash reference.

In case an C<ok> or C<cancel> parameter is passed, this will create a confirmation
notification. The C<ok> and C<cancel> URLs will receive a POST request,
once the buttons are pressed.
In case an C<ok_label> is passed, this will be the label
for the confirmation button.
In case a C<cancel_label> is passed, this will be the label
for the cancelation button.

B<Confirmation is EXPERIMENTAL!>


=head2 notifications

  # In templates
  %= notifications 'alertify';
  %= notifications 'alertify', 'bootstrap', -no_include, -no_css

Include alertify notifications in your template.

If you want to use a class different to the defined base class, you can
pass this as a string attribute.

If you don't want to include the javascript and css assets for C<Alertify.js>,
append C<-no_include>. If you just don't want to render the
stylesheet tag for the inclusion of the CSS, append C<-no_css>.

All notifications are also rendered in a C<E<lt>noscript /E<gt>> tag,
following the notation described in the
L<HTML|Mojolicious::Plugin::Notifications::HTML> engine.


=head1 SEE ALSO

L<Alertify.js|http://fabien-d.github.io/alertify.js/>.


=head1 AVAILABILITY

  https://github.com/Akron/Mojolicious-Plugin-Notifications


=head1 COPYRIGHT AND LICENSE

=head2 Mojolicious::Plugin::Notifications::Alertify

Copyright (C) 2014-2018, L<Nils Diewald|http://nils-diewald.de/>.

This program is free software, you can redistribute it
and/or modify it under the terms of the Artistic License version 2.0.


=head2 Alertify.js (bundled)

Copyright (c) Fabien Doiron

See L<https://github.com/fabien-d/alertify.js> for further information.

Licensed under the terms of the
L<MIT License|http://opensource.org/licenses/MIT>.

=cut
