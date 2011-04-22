package AjaxRating::VoteSummary;
use strict;

use MT::Object;
@AjaxRating::VoteSummary::ISA = qw(MT::Object);
__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
        'blog_id' => 'integer default 0',
        'obj_type' =>   'string(50) not null',
        'obj_id' =>     'integer default 0',
        'author_id' =>  'integer default 0',
        'vote_count' => 'integer default 0',
        'total_score' => 'integer default 0',
        'avg_score' => 'float default 0'
    },
    indexes => {
        id => 1,
        blog_id => 1,
        obj_type => 1,
        obj_id => 1,
        author_id => 1,
        vote_count => 1,
        total_score => 1,
        avg_score => 1
    },
    audit => 1,
    datasource => 'ajaxrating_votesummary',
    primary_key => 'id',
});

# Remove this entry and all of its votes from the DB
# Depends on MySQL.
sub purge {
    my ($self) = @_;
    # Clean up the votes. Not fully portable but much faster.
    # Note that any delete object callbacks on an EP::Vote object ARE NOT INVOKED.
    # Let me repeat that:
    # !! DELETE OBJECT CALLBACKS ARE NOT INVOKED WHEN THE VOTE OBJECTS ARE REMOVED !!
    # This presumably why there is no direct support for this kind of thing (although
    # one wonders why it couldn't be done in a bulkier fashion internally, e.g.
    # load up 1000 objects or so at a time, invoke the callbacks, then delete them
    # in bulk, yielding a 500:1 reduction in DB calls)
    my $db = MT::Object->driver();
    $db->sql('DELETE FROM mt_' . AjaxRating::Vote->datasource()  . ' WHERE ' . AjaxRating::Vote->datasource()  . '_EntryID=' . $self->id() . ';');
    $self->remove(); # remove this object from the DB
}

1;
