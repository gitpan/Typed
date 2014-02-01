package Person;

use Typed;
use Email::Valid;
 
has 'name' => (is => 'rw');

subtype 'Email',
    as 'Str',
    where { Email::Valid->address($_) },
    message { $_ ? "$_ is not a valid email address" : "No value given for address validation" };

has 'email' => (isa => 'Email', is => 'rw');

subtype 'PositiveInt',
   as 'Int',
   where { $_ > 0 },
   message { "$_ is not a positive integer!" };

has age => (
   is      => "rw",
   isa     => 'PositiveInt',
);

sub birthday {
   my $self = shift;
   my ($years) = @_;

   $self->age($self->age + 1);
}

package main;

use Types::Standard;

my $p = Person->new(age => 4, email => 'joy@joy.com');
print($p->age, "\n");

$p->birthday;
print($p->age, "\n");
print($p->email, "\n");

$p->name("blue");
print($p->name, "\n");

$p->age(-1);
