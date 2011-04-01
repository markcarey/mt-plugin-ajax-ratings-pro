# EntryPost http://mt-hacks.com

package AjaxRating::AddVote;

use strict;
use MT::App;
use AjaxRating::Vote;
use AjaxRating::VoteSummary;

@AjaxRating::AddVote::ISA = qw( MT::App );

my $enable_ip_checking = 1;

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        vote => \&vote,
    );
    $app->{default_mode} = 'vote';
    $app->{charset} = $app->{cfg}->PublishCharset;
    $app;
}

sub vote {
	my $app = shift;
    my $q = $app->{query};
    return "ERR||Invalid request, must use POST."
        if $app->request_method() ne 'POST';
	use MT::Plugin;
	my $plugin = MT::Plugin::AjaxRating->instance;
	my $config = $plugin->get_config_hash('blog:'.$q->param('blog_id'));
	my $obj_type = $q->param('obj_type');
	return "ERR||Invalid object type."
		if ($config->{ratingl} && ($obj_type ne 'entry') && ($obj_type ne 'blog'));
	my $max_points_setting = $q->param('obj_type') . "_max_points";
	my $max_points = $config->{$max_points_setting} || 10;
	if ($q->param('r') > $max_points) {
		return "ERR||That vote exceeds the maximum for this item.";
	}
	my $vote;
	if ($enable_ip_checking) {
		$vote = AjaxRating::Vote->load({ ip => $app->remote_ip, obj_type => $q->param('obj_type'), obj_id => $q->param('obj_id') });
	}

	if ($vote) {
		return "ERR||You have already voted on this item.";
	} else {
		my ($session, $voter) = $app->get_commenter_session;
		$vote = AjaxRating::Vote->new;
		$vote->ip($app->remote_ip);
		$vote->blog_id($q->param('blog_id'));
		$vote->voter_id($voter->id) if $voter;
		$vote->obj_type($q->param('obj_type'));
		$vote->obj_id($q->param('obj_id'));
		$vote->score($q->param('r'));
		$vote->save;

		my $votesummary = AjaxRating::VoteSummary->load({ obj_type => $vote->obj_type, obj_id => $vote->obj_id });
		if (!$votesummary) {
			$votesummary = AjaxRating::VoteSummary->new;
			$votesummary->obj_type($vote->obj_type);
			$votesummary->obj_id($vote->obj_id);
			$votesummary->blog_id($vote->blog_id);
			$votesummary->author_id($q->param('a'));
			$votesummary->vote_count(0);
			$votesummary->total_score(0);
		}
		$votesummary->vote_count($votesummary->vote_count + 1);
		$votesummary->total_score($votesummary->total_score + $vote->score);
		$votesummary->avg_score(sprintf("%.1f",$votesummary->total_score / $votesummary->vote_count));	
		$votesummary->save;	
		if ($config->{rebuild}) {
	  		MT::Util::start_background_task(sub {
				my $entry;
				use MT::Entry;
				if (($obj_type eq 'entry') || ($obj_type eq 'page') || ($obj_type eq 'topic')) {
					$entry = MT::Entry->load($vote->obj_id);
				} elsif ($obj_type eq 'comment') {
					use MT::Comment;
					my $comment = MT::Comment->load($vote->obj_id);
					$entry = $comment->entry;
				} elsif ($obj_type eq 'ping') {
					use MT::TBPing;
					my $ping = MT::TBPing->load($vote->obj_id);
					$entry = $ping->entry;
				}
				if ($entry && $config->{rebuild} eq "1") {
					$app->publisher->_rebuild_entry_archive_type( Entry => $entry, ArchiveType => 'Individual');
				} elsif (($obj_type eq "category") && $config->{rebuild} eq "1") {
					use MT::Category;
					my $category = MT::Category->load($vote->obj_id);
					$app->publisher->_rebuild_entry_archive_type( Category => $category, ArchiveType => 'Category');
				} elsif ($entry && $config->{rebuild} eq "2") {
					$app->rebuild_entry( Entry => $entry);
					$app->rebuild_indexes( BlogID => $q->param('blog_id'));
				} elsif ($config->{rebuild} eq "3") {
					$app->rebuild_indexes( BlogID => $q->param('blog_id'));
				}
  			});  ### end of background task
		}
		return "OK||".$votesummary->obj_type."||".$votesummary->obj_id."||".$q->param('r')."||".$votesummary->total_score."||".$votesummary->vote_count;
	
	} 

}

1;