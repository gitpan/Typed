package Typed;

use strict;
use warnings FATAL => 'all';
use feature qw(:5.10);

use Carp qw();
use Scalar::Util qw(blessed);

use Types::Standard "-types";
use Type::Utils qw();
use Exporter::Tiny;

use parent qw(Exporter::Tiny);

our @EXPORT = qw(has new as from subtype);
our @TINY_UTILS = qw(message where inline_as declare coerce);

our $VERSION = '0.09';

sub import {
    shift->SUPER::import({ into => scalar(caller(0)) }, @EXPORT );
    Type::Utils->import({ into => scalar(caller(0)) }, @TINY_UTILS );
}

sub new {
    my $self = shift;
    
    my $class = ref($self) || $self;
    my $blessed = bless({}, $class);

    my $meta_pkg = __PACKAGE__;
    my $meta = do { no strict 'refs'; \%{"${meta_pkg}::meta"}; };

    if ($meta && $$meta{$class}) {
        my $has = $$meta{$class};
        foreach my $name (keys %{ $has }) {
            my $opts = $$meta{$class}{$name};

            __PACKAGE__->default($blessed, $class, $name, $opts, $$opts{lazy});
        }
    }

    my %user_vals = @_;
    foreach my $k (keys %user_vals) {
        $blessed->{$k} = $user_vals{$k}; # TODO: Use the attribute method.
    }

    my $build = $blessed->can("BUILD");
    if ($build) {
        $build->($blessed);
    }

    return($blessed);
}

sub default {
    my $meta_pkg = shift;
    my $self = shift;
    my $package = shift;
    my $name = shift;
    my $opts = shift;
    my $lazy = shift;

    my $default;
    unless ($lazy) {
        if ($$opts{default}) {
            my $type = ref($$opts{default});
            if ($type && "CODE" eq $type) {
                $default = $$opts{default}->();
            }
            else {
                $default = $$opts{default};
            }
        }

        if ($$opts{builder}) {
            my $builder = do { no strict 'refs'; \&{"${package}::$$opts{builder}"}; };

            if ($builder) {
                $default = $builder->($self);
            }
        }

        $self->{$name} = $default; # TODO: Use the attribute method.
    }
    
    return($default);
}

# Yes, we use a global cache for metadata
our %meta = (
);

sub process_has {
    my $self = shift;
    my $name = shift;
    my $package = shift;

    my $isa = $meta{$package}{$name}{isa};

    my $is = $meta{$package}{$name}{is};
    my $writable = $is && "rw" eq $is;
    my $opts = $meta{$package}{$name};

    my $attribute = sub {
        if (!exists $_[0]->{$name}) {
            __PACKAGE__->default($_[0], $package, $name, $opts, 0);
        }

        # Do we set the value
        if (1 == $#_) {
            if ($writable) {
                return($_[0]->{$name} = undef) if !defined $_[1];

                if ($isa) {
                    my $package = blessed($_[0]);
                    my $type = Types::Standard->get_type($isa) || $meta{subtype}{$package}{$isa};

                    if ($type) {
                        my $msg = $type->validate($_[1]);
                        Carp::croak($msg) if $msg; 
                    }
                }

                $_[0]->{$name} = $_[1];
            }
            else {
                Carp::croak("Attempt to modify read-only attribute: $name");
            }
        }

        return($_[0]->{$name});
    };

    return($attribute);
}

sub has {
    my $name = shift;
    my %opts = @_;
    my $package = caller;

    $meta{$package}{$name} = \%opts;

    my $attribute = __PACKAGE__->process_has($name, $package);

    { no strict 'refs'; *{"${package}::$name"} = $attribute; }
}

sub as (@) {
	unless (blessed($_[0])) {
        my $type = shift(@_);
        unshift(@_, __PACKAGE__->$type);
    }

    Type::Utils::as(@_);
}

sub from (@)
{
	unless (blessed($_[0])) {
        my $type = shift(@_);
        unshift(@_, __PACKAGE__->$type);
    }

    Type::Utils::from(@_);
}

sub subtype
{
    my $subtype = Type::Utils::subtype(@_);
    my $package = caller;
    my $name = $_[0];
    $meta{subtype}{$package}{$name} = $subtype;
}

1;

__END__

=head1 NAME

Typed - Minimal typed Object Oriented layer

=head1 SYNOPSIS

    package User;
    
    use Typed;
    use Email::Valid;
    
    subtype 'Email'
    
        => as 'Str'
        => where { Email::Valid->address($_) }
        => message { $_ ? "$_ is not a valid email address" : "No value given for address validation" };
    
    has 'id' => ( isa => 'Int', is => 'rw' );
    
    has 'email' => ( isa => 'Email', is => 'rw' );
    
    has 'password' => ( isa => 'Str', is => 'rw' );
    
    1;
    
    package main;
    
    use strict;
    use warnings;
    use feature qw(:5.10);
    
    my $user = User->new();
    
    $user->id(1);
    
    say($user->id());
    
    eval {
        $user->email("abc");
    };
    if ($@) {
        $user->email('abc@nowhere.com');
    }
    say($user->email());

=head1 DESCRIPTION

L<Typed> is a minimalistic typed Object Oriented layer.

The goal is to be mostly compatible with L<Moose::Manual::Types>.

=cut
