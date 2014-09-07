package Mojolicious::Plugin::Notifications::Assets;
use Mojo::Base -strict;

sub new {
  bless {
    styles => [],
    scripts => []
  }, shift;
};

sub styles {
  my $self = shift;
  return sort @{ $self->{styles} } unless @_;
  push(@{$self->{styles}}, @_);
};

sub scripts {
  my $self = shift;
  return sort @{ $self->{scripts} } unless @_;
  push(@{$self->{scripts}}, @_);
};


1;
