package AjaxRating::Vote;
use strict;
use warnings;

use MT::Object;
@AjaxRating::Vote::ISA = qw(MT::Object);
__PACKAGE__->install_properties({
    column_defs => {
        'id'       => 'integer not null auto_increment',
        'blog_id'  => 'integer default 0',
        'voter_id' => 'integer default 0',
        'obj_type' => 'string(50) not null',
        'obj_id'   => 'integer default 0',
        'score'    => 'integer default 0',
        'ip'       => 'string(15)'
    },
    indexes => {
        voter_id => 1,
        blog_id => 1,
        obj_type => 1,
        obj_id => 1,
        ip => 1
    },
    audit => 1,
    datasource => 'ar_vote',
    primary_key => 'id',
});

sub class_label {
    MT->translate("Vote");
}

sub class_label_plural {
    MT->translate("Votes");
}

## subnet will return the first 3 sections of an IP address.  
## If passed 24.123.2.45, it will return 24.123.2

sub subnet {
    my $vote = shift;
    my $ip = $vote->ip;
    my @parts = split(/\./,$ip);
    my $subnet = $parts[0] . "." . $parts[1] . "." . $parts[2];
    return $subnet;
}

1;
