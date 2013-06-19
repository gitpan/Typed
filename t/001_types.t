use strict;
use warnings;
 
use Test::More;
use IO::Scalar;
 
{
    package Is::Typed;

    use Test::More;

    BEGIN { use_ok( 'Typed' ); }

    has Bool => (is => 'rw', isa => "Bool");
    has Int => (is => 'rw', isa => "Int");
    has Str => (is => 'rw', isa => "Str");
    has Class => (is => 'ro', isa => "IO::Scalar", default => sub { IO::Scalar->new(\"Works" ) } );
}

my $typed = new_ok("Is::Typed");
foreach my $meth (qw(Bool Int Str Class)) {
    can_ok($typed, $meth);
}

is($typed->Bool(), undef, "Bool is undefined");
is($typed->Bool(1), 1, "Bool is 1");
is($typed->Bool(), 1, "Bool is 1");
is($typed->Bool(0), 0, "Bool is 0");
is($typed->Bool(''), '', "Bool is ''");
eval {
    $typed->Bool(3);
};
like($@, qr/does not match the type constraints/);
eval {
    $typed->Bool("abc");
};
like($@, qr/does not match the type constraints/);
is($typed->Bool(undef), undef, "Bool is undefined");

is($typed->Int(), undef, "Int is undefined");
is($typed->Int(5), 5, "Int is 5");
is($typed->Int(), 5, "Int is 5");

eval {
    $typed->Int(5.5);
};
like($@, qr/does not match the type constraints/);

eval {
    $typed->Int("abc");
};
like($@, qr/does not match the type constraints/);

$typed->Int("0E0");
is($typed->Int(), "0E0", "Int is 0E0");
is($typed->Int(undef), undef, "Int is undefined");

is($typed->Str(), undef, "Str is undefined");
is($typed->Str(5), 5, "Str is 5");
is($typed->Str(), 5, "Str is 5");
is($typed->Str("Weee"), "Weee", "Str is Weee");
is($typed->Str(undef), undef, "Str is undefined");

isa_ok($typed->Class(), "IO::Scalar", "IO::Scalar::getline");
is($typed->Class()->getline(), "Works", "IO::Scalar::getline");
eval {
    $typed->Class(5);
};
like($@, qr/Attempt to modify/);

done_testing;

