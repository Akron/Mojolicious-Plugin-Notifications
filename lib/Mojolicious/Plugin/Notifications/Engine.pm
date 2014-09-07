package Mojolicious::Plugin::Notifications::Engine;
use Mojo::Base 'Mojolicious::Plugin';

# Register the plugin - optional
sub register {
  # Nothing to register - but has to be called
};


# scripts attribute
sub scripts {
  $_[0]->{scripts} //= [];
  return @{$_[0]->{scripts}} if @_ == 1;
  push(@{shift->{scripts}}, @_);
};


# styles atttribute
sub styles {
  $_[0]->{styles} //= [];
  return @{$_[0]->{styles}} if @_ == 1;
  push(@{shift->{styles}}, @_);
};

# notifications method
sub notifications {
  return 'No notification engine specified!';
};


1;

=pod

=head1 Writing your own engine

A notification engine is a simple L<Mojolicious::Plugin::Notifications::Engine>,
having a C<register> method
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

Possible flags (boolean parameters marked with a dash) are passed as a hash reference.
All other parameters passed to the L<notifications> helper are simply appended.

The L<bundled engines|/Bundled engines> can serve as good examples on how
to write an engine, especially the simple
L<HTML|Mojolicious::Plugin::Notifications::HTML> engine.
