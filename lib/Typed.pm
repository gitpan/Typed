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

our $VERSION = '0.11';

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

     my %user_vals = @_;
     foreach my $k (keys %user_vals) {
         $blessed->$k($user_vals{$k});
     }

    my $build = $blessed->can("BUILD");
    if ($build) {
        $build->($blessed);
    }

    return($blessed);
}

# Yes, we use a global cache for metadata
our %meta = (
);

sub process_has {
    my $self = shift;
    my $name = shift;
    my $package = shift;

    my $is = $meta{$package}{$name}{is};
    my $writable = $is && "rw" eq $is;
    my $opts = $meta{$package}{$name};

    my $default;
    
    if ($$opts{default}) {
        $default = sub {
            $$opts{default};
        };
    }

    my $attribute = sub {
        state $type = $meta{type}{$package}{$name};
        state $cache = \$_[0]->{$name};
        state $writable = $writable;

        if ($default) {
            $_[0]->{$name} = $default->();
            $default = undef; 
        }

        # Do we set the value
        if (1 == $#_) {
            if ($writable) {
                my $msg = $type->validate($_[1]);
                Carp::croak($msg) if $msg; 

                $$cache = $_[1];
            }
            else {
                Carp::croak("Attempt to modify read-only attribute: $name");
            }
        }

        return("CODE" eq ref($$cache) ? $$cache->() : $$cache);
    };

    return($attribute);
}

sub has {
    my $name = shift;
    my %opts = @_;
    my $package = caller;

    $meta{$package}{$name} = \%opts;
    
    my $isa = $opts{isa} || "Str";
    $meta{$package}{$name}{isa} = $isa;

    my $type = Types::Standard->get_type($isa) || $meta{subtype}{$package}{$isa};
    $meta{type}{$package}{$name} = $type;

    my $attribute = __PACKAGE__->process_has($name, $package);

    { no strict 'refs'; *{"${package}::$name"} = $attribute; };
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
