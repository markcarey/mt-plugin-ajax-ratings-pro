package AjaxRating::HotObject;
use strict;
use warnings;

use MT::Object;
@AjaxRating::HotObject::ISA = qw(MT::Object);

__PACKAGE__->install_properties({
    column_defs => {
        'id'          => 'integer not null auto_increment',
        'blog_id'     => 'integer default 0',
        'obj_type'    => 'string(50) not null',
        'obj_id'      => 'integer default 0',
        'author_id'   => 'integer default 0',
        'vote_count'  => 'integer default 0',
        'total_score' => 'integer default 0',
        'avg_score'   => 'float default 0'
    },
    indexes => {
        blog_id => 1,
        obj_type => 1,
        obj_id => 1,
        author_id => 1,
        vote_count => 1,
        total_score => 1,
        avg_score => 1
    },
    audit => 1,
    datasource => 'ar_hotobj',
    primary_key => 'id',
});

sub class_label {
    MT->translate("Hot Object");
}

sub class_label_plural {
    MT->translate("Hot Objects");
}

1;
