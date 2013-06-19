package Typed;

use strict;
use warnings FATAL => 'all';
use feature qw(:5.10);

use Carp qw();
use Scalar::Util qw();

use parent qw(Exporter);
our @EXPORT = qw(has subtype as where message new);

our $VERSION = '0.04';

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

my %constraints = (
    Bool => {
        where => sub {
            return 1 if 1 == $_[0];
            return 1 if 0 == $_[0];
            return 1 if '' eq $_[0];
            return 0;
        },
    },
    Str => {
        where => sub {
            my $type = ref($_[0]);

            return 1 if !$type;
            return 0;
        },
    },
    "FileHandle" => {
        where => sub {
            my $type = Scalar::Util::openhandle($_[0]);

            return 1 if defined $type;
            return 0;
        },
    },
    "Object" => {
        where => sub {
            my $type = Scalar::Util::blessed($_[0]);

            return 1 if defined $type;
            return 0 if defined $type;
        },
    },
    "Num" => {
        where => sub {
            return 1;
            return 1 if Scalar::Util::looks_like_number($_[0]);
            return 0;
        },
    },
    "Int" => {
        where => sub {
            return 1 if Scalar::Util::looks_like_number(abs($_[0]));
            return 0;
        },
    },
    ClassName => {
        where => sub {
            my $value = shift;
            my $opts = shift;

            my $type = Scalar::Util::blessed($value);

            return 1 if defined $type && $type eq $$opts{isa};
            return 0;
        },
    },
);

# Constraint verification sub
sub type {
    my ($class, $name, $value, $opts) = @_;

    return 1 if !defined $value;

    my $isa = $$opts{isa};

    if ($constraints{$isa} && $constraints{$isa}{as}) {
        my $isa = $constraints{$isa}{as};
        my $where = $constraints{$isa}{where};

        $class->type($name, $value, { isa => $isa, where => $where, opts => { isa => $isa }});
    }

    {
        return 1 if $$opts{where}->($value, $$opts{opts});

        if ($constraints{$isa}{message}) {
            local $_ = $value;
            Carp::croak($constraints{$isa}{message}->());
        }
        else {
            Carp::croak("$value does not match the type constraints: $isa for $name");
        }
    }
}

sub subtype {
    my $subtype = shift;
    my %opts = @_;

    Carp::croak("No subtype given.") if !$subtype;
    Carp::croak("No as given.") if !$opts{as};
    Carp::croak("No where given.") if !$opts{where};

    $constraints{$subtype} = {
        as => $opts{as},
        where => $opts{where},
        message => $opts{message},
    };
}

sub as          ($) { (as          => $_[0]) } ## no critic
sub where       (&) { (where       => $_[0]) } ## no critic
sub message     (&) { (message     => $_[0]) } ## no critic

sub process_has {
    my $self = shift;
    my $name = shift;
    my $package = shift;

    my $isa = $meta{$package}{$name}{isa};

    my $where;
    if ($constraints{$isa}) {
        $where = $constraints{$isa}{where};
    }
    else {
        $where = $constraints{ClassName}{where};
    }

    my $is = $meta{$package}{$name}{is};
    my $attribute = sub {
        my $self = shift;

        state $name = $name;
        state $package = $package;
        state $writable = $is && "rw" eq $is;
        state $type = { isa => $isa, where => $where, opts => { isa => $isa }};
        state $opts = $meta{$package}{$name};

=for comment
        state $config = {
            name => $name,
            package => $package,
            writable => $is && "rw" eq $is,
            type => { isa => $isa, where => $where, opts => { isa => $isa }},
            opts => $meta{$package}{$name},
        };
=cut

        if (!exists $self->{$name}) {
            __PACKAGE__->default($self, $package, $name, $opts, 0);
        }

        # Do we set the value
        if (scalar(@_)) {
            if ($writable) {
                my $value = shift;

                # Need subtypes
                if ($constraints{$isa} && $constraints{$isa}{as}) {
                    __PACKAGE__->type($name, $value, $type);
                }
                else {
                    # Common case is faster
                    $$type{where}->($value, $opts) ||
                    __PACKAGE__->type($name, $value, $type);
                }

                $self->{$name} = $value;
            }
            else {
                Carp::croak("Attempt to modify read-only attribute: $name");
            }
        }

        return($self->{name});
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