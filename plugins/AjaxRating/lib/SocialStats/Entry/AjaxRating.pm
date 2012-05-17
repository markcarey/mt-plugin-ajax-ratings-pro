package SocialStats::Entry::AjaxRating;

use strict;
use AjaxRating::VoteSummary;

sub social_count {
    my $pkg = shift;
    my ($entry) = @_;
    my $vs = AjaxRating::VoteSummary->load({ obj_type => 'entry', obj_id => $entry->id });
    my $count = $vs->total_score if $vs;
    return $count || 0;
}

1;