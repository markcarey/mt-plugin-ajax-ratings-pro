package AjaxRating::GetVotes;

use strict;
use warnings;
use AjaxRating::App;
@AjaxRating::GetVotes::ISA = qw( AjaxRating::App );

use constant ENFORCE_POST => 1;

sub default_mode {
    my $app = shift;
    my $q   = $app->{query};

    if (ENFORCE_POST) {
        return "ERR||Invalid request, must use POST."
            if $app->request_method() ne 'POST';
    }

    require AjaxRating::VoteSummary;
    require MT::Plugin::AjaxRating;

    my $plugin = MT::Plugin::AjaxRating->instance;
    my $config = $plugin->get_config_hash('blog:'.$q->param('blog_id'));

    my ( $obj_type, $obj_id, $blog_id )
        = map { $q->param($_) } qw( obj_type obj_id blog_id );

    return "ERR||Invalid object type."
        if ( $config->{ratingl}
        && ( $obj_type ne 'entry')
        && ( $obj_type ne 'blog')  );

    my $votesummary = AjaxRating::VoteSummary->get_by_key({
        obj_type => $obj_type,
        obj_id   => $obj_id,
    });

    unless ( $votesummary->id ) {
        # Set up a dummy object with the appropriate
        # values for ease of use
        $votesummary->set_values({
            blog_id     => $blog_id,
            author_id   => $q->param('a'),
            vote_count  => 0,
            total_score => 0,
        });
        # $votesummary->save;  # No need to save. Just a dummy
    }

    return join( '||', 'OK', map { $votesummary->$_ } 
                                qw( obj_type obj_id total_score vote_count ) );
}

1;
