package Dist::Zilla::Plugin::Precompute;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;

use Data::Dump::OneLine qw(dump1);
use Moose;
with (
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::FileFinderUser' => {
        default_finders => [ ':InstallModules' ],
    },
);

use namespace::autoclean;

sub mvp_multivalue_args { qw(var) }

sub munge_files {
    my $self = shift;

    $self->munge_file($_) for @{ $self->found_files };
    return;
}

sub munge_file {
    my ($self, $file) = @_;

    my $content = $file->content;

    my $munged_date = 0;
    my $modified =
        $content =~ s{^
                      (\s*(?:(?:my|our|local)\s+))? #1 optional prefix
                      \$(\w+(?:::\w+)*) #2 variable name
                      (?:\s*=s\s*.+?)? #3 optional current value
                      (;\s*\#\s*PRECOMPUTE) #4 marker
                      $
                 }
                     {
                         $self->log_debug(['precomputing $%s in %s ...',
                                           $2, $file->name]);
                         $1. '$'.$2 . ' = '. dump1($self->precompute($2)) . $4
                     }egmx;
    use DD; dd $self;
    $file->content($content) if $modified;
}

sub precompute {
    "foo";
}

__PACKAGE__->meta->make_immutable;
1;
# ABSTRACT: Precompute variable values during building

=for Pod::Coverage .+

=head1 SYNOPSIS

In C<dist.ini>:

 [Precompute]
 var=foo Some::Module->_init_value;

in your module C<lib/Some/Module.pm>:

 our $foo; # PRECOMPUTE

The generated module file:

 our $foo = ["some", "value", "..."]; # PRECOMPUTE


=head1 DESCRIPTION

This plugin can be used to precompute (or initialize) a variable's value during
build time and put the resulting computed value into the built source code. This
is useful in some cases to reduce module startup time, especially if it takes
some time to compute the value.


=head1 SEE ALSO

L<Dist::Zilla>
