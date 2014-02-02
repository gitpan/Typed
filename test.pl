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
