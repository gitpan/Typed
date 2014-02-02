use strict;
use warnings;
 
use Test::More;
use IO::Handle;
 
{
    package Is::Typed;

    use Test::More;

    BEGIN { use_ok( 'Typed' ); }

    has NoIsa => (is => 'rw');
    has Bool => (is => 'rw', isa => "Bool");
    has Int => (is => 'rw', isa => "Int");
    has Str => (is => 'rw', isa => "Str");
    has 'Class' => (class => 'IO::Handle', is => 'ro', default => sub { IO::Handle->new() });
}

my $typed = new_ok("Is::Typed");
foreach my $meth (qw(NoIsa Bool Int Str Class)) {
    can_ok($typed, $meth);
}

is($typed->NoIsa(), undef, "NoIsa is undefined");
is($typed->NoIsa("123"), "123", "NoIsa is 123");

is($typed->Bool(), undef, "Bool is undefined");
is($typed->Bool(1), 1, "Bool is 1");
is($typed->Bool(), 1, "Bool is 1");
is($typed->Bool(0), 0, "Bool is 0");
is($typed->Bool(''), '', "Bool is ''");
eval {
    $typed->Bool(3);
};
like($@, qr/did not pass type constraint/);
eval {
    $typed->Bool("abc");
};
like($@, qr/did not pass type constraint/);
is($typed->Bool(undef), undef, "Bool is undefined");

is($typed->Int(), undef, "Int is undefined");
is($typed->Int(5), 5, "Int is 5");
is($typed->Int(), 5, "Int is 5");

eval {
    $typed->Int(5.5);
};
like($@, qr/did not pass type constraint/);

eval {
    $typed->Int("abc");
};
like($@, qr/did not pass type constraint/);

# Hrmm.  Should this work?
# $typed->Int("0E0");
# is($typed->Int(), "0E0", "Int is 0E0");
is($typed->Int(1), 1, "Int is 1");

is($typed->Str(), undef, "Str is undefined");
is($typed->Str("abc"), "abc", "Str is abc");
is($typed->Str(5), 5, "Str is 5");
is($typed->Str(), 5, "Str is 5");
is($typed->Str("Weee"), "Weee", "Str is Weee");
eval {
    $typed->Str(undef);
};
like($@, qr/did not pass type constraint/);

isa_ok($typed->Class(), "IO::Handle", "IO::Handle::getline");
eval {
    $typed->Class(5);
};
like($@, qr/Attempt to modify/);

done_testing;

