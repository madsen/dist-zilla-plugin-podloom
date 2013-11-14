#---------------------------------------------------------------------
package Dist::Zilla::Plugin::PodLoom;
#
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 7 Oct 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Process module documentation through Pod::Loom
#---------------------------------------------------------------------

our $VERSION = '5.00';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

=head1 SYNOPSIS

In your F<dist.ini>:

  [PodLoom]
  template = Default      ; this is the default
  data = loom.pl          ; there is no default for this

=head1 DESCRIPTION

If included, this plugin will process each F<.pm> and F<.pod> file
under F<lib> or in the root directory through Pod::Loom.

=cut

use Moose 0.65; # attr fulfills requires
use Moose::Autobox;
with(qw(Dist::Zilla::Role::FileMunger
        Dist::Zilla::Role::ModuleInfo
        Dist::Zilla::Role::FileFinderUser) => {
          default_finders => [ ':InstallModules' ],
        },
);

# List minimum versions for AutoPrereqs:
use 5.008;
use Dist::Zilla 4.200001 ();               # abstract_from_file change
use Dist::Zilla::Role::ModuleInfo 0.08 (); # from Plugins, not PluginBundle

use Hash::Merge::Simple ();
use Pod::Loom 0.05 (); # bugtracker

=attr finder

This is the name of a L<FileFinder|Dist::Zilla::Role::FileFinder>
whose files will be processed by L<Pod::Loom>.  It may be specified
multiple times.  The default value is C<:InstallModules>.

=attr template

This will be passed to Pod::Loom as its C<template>.
Defaults to C<Default>.

=cut

has template => (
  is      => 'ro',
  isa     => 'Str',
  default => 'Default',
);

=attr data

Since Pod::Loom templates may want configuration that doesn't fit in
an INI file, you can specify a file containing Perl code to evaluate.
The result should be a hash reference, which will be passed to
Pod::Loom's C<weave> method.

PodLoom automatically includes the following keys, which will be
merged with the hashref from your code.  (Your code can override these
values.)

=over

=item abstract

The abstract for the file being processed (if it can be determined)

=item authors

C<< $zilla->authors >>

=item dist

C<< $zilla->name >>

=item license_notice

C<< $zilla->license->notice >>

=item module

The primary package of the file being processed
(if Module::Build::ModuleInfo could determine it)

=item repository

C<< $zilla->distmeta->{resources}{repository}{web} >>
(or the C<url> key if C<web> is not set)

=item version

The version number of the file being processed
(if Module::Build::ModuleInfo could determine it)

=item zilla

The Dist::Zilla object itself

=back

=cut

has data_file => (
  is       => 'ro',
  isa      => 'Str',
  init_arg => 'data',
);

has data => (
  is       => 'ro',
  isa      => 'HashRef',
  init_arg => undef,
  lazy     => 1,
  builder  => '_initialize_data',
);

has loom => (
  is       => 'ro',
  isa      => 'Pod::Loom',
  init_arg => undef,
  lazy     => 1,
  default  => sub { Pod::Loom->new(template => shift->template) },
);

#---------------------------------------------------------------------
sub _initialize_data
{
  my $plugin = shift;

  my $fname = $plugin->data_file;

  return {} unless $fname;

  open my $fh, '<', $fname or die "can't open $fname for reading: $!";
  my $code = do { local $/; <$fh> };
  close $fh;

  local $@;
  my $result = eval "package Dist::Zilla::Plugin::PodLoom::_eval; $code";

  die $@ if $@;

  return $result;
} # end _initialize_data

#---------------------------------------------------------------------
sub munge_files {
  my ($self) = @_;

  $self->munge_file($_) for $self->found_files->flatten;
} # end munge_files

#---------------------------------------------------------------------
sub munge_file
{
  my ($self, $file) = @_;

  my $info = $self->get_module_info($file);

  my $abstract = Dist::Zilla::Util->abstract_from_file($file);
  my $repo     = $self->zilla->distmeta->{resources}{repository};

  my $dataHash = Hash::Merge::Simple::merge(
    {
      ($abstract ? (abstract => $abstract) : ()),
      authors        => $self->zilla->authors,
      dist           => $self->zilla->name,
      license_notice => $self->zilla->license->notice,
      ($info->name ? (module => $info->name) : ()),
      bugtracker     => $self->zilla->distmeta->{resources}{bugtracker},
      repository     => $repo->{web} || $repo->{url},
      # Have to stringify version object:
      ($info->version ? (version => q{} . $info->version) : ()),
      zilla          => $self->zilla,
    }, $self->data,
  );

  my $method = Dist::Zilla->VERSION < 5 ? 'content' : 'encoded_content';

  my $content = $file->$method;

  $file->$method( $self->loom->weave(\$content, $file->name, $dataHash) );

  return;
} # end munge_file

#---------------------------------------------------------------------
around dump_config => sub {
  my ($orig, $self) = @_;
  my $config = $self->$orig;

  $config->{'Pod::Loom version'} = Pod::Loom->VERSION;

  return $config;
}; # end dump_config

#---------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT

=for Pod::Coverage
munge_files?
