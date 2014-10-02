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

sub mvp_multivalue_args { qw(code) }
has code => (is => 'rw');

sub munge_files {
    my $self = shift;

    $self->munge_file($_) for @{ $self->found_files };
    return;
}

sub munge_file {
    my ($self, $file) = @_;

    my $content = $file->content;
    my $code = $self->code;
    my $var = $self->plugin_name;

    state %mem;
    unless ($code) {
        $self->log(["Skipping precomputing '\$var' because code is not defined"]);
        return;
    }
    if (ref($code) eq 'ARRAY') { $code = join '', @$code }

    my ($pkg) = $content =~ /^\s*package\s+(\w+(?:::\w+)*)/m;
    $var = "$pkg\::$var" unless $var =~ /::/;

    my $munged_date = 0;
    my $modified;

    $content =~ s{^
                  (\s*(?:(?:my|our|local)\s+))? #1 optional prefix
                  \$(\w+(?:::\w+)*) #2 variable name
                  (\s*=s\s*.+?)? # optional current value
                  (;\s*\#\s*PRECOMPUTE) #3 marker
                  $
             }
                 {
                     say "var=$var vs pkg+var=$pkg\::$2";
                     if ($var eq "$pkg\::$2") {
                         $modified++;
                         $self->log_debug(['precomputing $%s in %s ...',
                                           $2, $file->name]);
                         my $res = exists($mem{$var}) ? $mem{$var}:eval($code);
                         die if $@;
                         $mem{$var} = $res;
                         $1. '$'.$2 . ' = '. dump1($res) . $4;
                     } else {
                         # return original string
                         $1. '$'.$2 . ($3 // '') . $4
                     }
                 }egmx;
    $file->content($content) if $modified;
}

__PACKAGE__->meta->make_immutable;
1;
# ABSTRACT: Precompute variable values during building

=for Pod::Coverage .+

=head1 SYNOPSIS

In C<dist.ini>:

 [Precompute/FOO]
 code=Some::Module->_init_value;
 [Precompute / Some::Module::BAR]
 code=some Perl code

in your module C<lib/Some/Module.pm>:

 package Some::Module;
 our $FOO; # PRECOMPUTE
 our $BAR; # PRECOMPUTE

in your module C<lib/Some/OtherModule.pm>:

 package Some::OtherModule;
 our $FOO; # PRECOMPUTE
 our $BAR; # PRECOMPUTE

In the generated C<lib/Some/Module.pm>:

 our $FOO = ["some", "value", "..."]; # PRECOMPUTE
 our $BAR = "some other value"; # PRECOMPUTE

In the generated C<lib/Some/OtherModule.pm> (the second precompute only matches
C<$Some::Module::BAR> and not C<$BAR> from other package):

 our $FOO = ["some", "value", "..."]; # PRECOMPUTE
 our $BAR; # PRECOMPUTE


=head1 DESCRIPTION

This plugin can be used to precompute (or initialize) a variable's value during
build time and put the resulting computed value into the built source code. This
is useful in some cases to reduce module startup time, especially if it takes
some time to compute the value.


=head1 SEE ALSO

L<Dist::Zilla>
