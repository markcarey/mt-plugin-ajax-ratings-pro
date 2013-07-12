# EntryPost http://mt-hacks.com

package AjaxRating::AddVote;

use strict;
use warnings;
use YAML::Tiny;

use AjaxRating::App;
@AjaxRating::AddVote::ISA = qw( AjaxRating::App );

use AjaxRating::Vote;
use AjaxRating::VoteSummary;

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        default => \&vote,
        vote    => \&vote,         # alias for backcompat
        unvote  => \&unvote
    );
    $app;
}

# A vote has been submitted!
sub vote {
    my $app = shift;
    my $q = $app->{query};
    my $format = $q->param('format') || 'text';
    return _send_error( $app, $format, "Invalid request, must use POST.")
        if ($app->request_method() ne 'POST');

    # Check that the submitted vote has been set up for this object type on 
    # this blog.
    my $plugin = MT->component('ajaxrating');
    my $config = $plugin->get_config_hash('blog:'.$q->param('blog_id'));
    my $obj_type = $q->param('obj_type');
    return _send_error( $app, $format, "Invalid object type.")
        if ($config->{ratingl} && ($obj_type ne 'entry') && ($obj_type ne 'blog'));

    # Refuse any vote that has somehow exceeded the maximum number of scoring 
    # points.
    my $max_points_setting = $q->param('obj_type') . "_max_points";
    my $max_points = $config->{$max_points_setting} || 10;
    if ($q->param('r') > $max_points) {
        return _send_error( $app, $format, "That vote exceeds the maximum for this item.");
    }

    # Start the real work: check if the user has already voted on this object. 
    # If they have, give up. If they have *not*, save their vote (to the 
    # 'vote' datasource) and update the voting summary (in the 'votesummary' 
    # datasource). Lastly, republish, if required.
    my $vote;
    if ( $plugin->get_config_value('enable_ip_checking', 'system') ) {
        # IP checking is enabled
        $vote = AjaxRating::Vote->load({
            ip       => $app->remote_ip,
            obj_type => $q->param('obj_type'),
            obj_id   => $q->param('obj_id'),
        });
    }
    if ($vote) {
        return _send_error( $app, $format, "You have already voted on this item.");
    } else {

        my ($session, $voter) = $app->get_commenter_session;
        my $sid = $q->param('sid');
        if (!$voter && $sid) {
            my $cfg = $app->config;
            my $sess_obj = MT->model('session')->load({ id => $sid });
            my $timeout  = $cfg->CommentSessionTimeout;
            my $user_id  = $sess_obj->get('author_id') if $sess_obj;
            my $user     = MT->model('author')->load($user_id) if $user_id;
            $session = $sess_obj if $sess_obj;
            $voter = $user if $user;
        }
        if ($voter) {
            # check if logged in user already voted via a different IP address
            $vote = AjaxRating::Vote->load({
                voter_id       => $voter->id,
                obj_type => $q->param('obj_type'),
                obj_id   => $q->param('obj_id'),
            });
            return _send_error( $app, $format, "You have already voted on this item.") if $vote;
        }
        # This user has not previously voted on this object. Record their vote
        # and the score they gave.
        $vote = AjaxRating::Vote->new;
        $vote->ip($app->remote_ip);
        $vote->blog_id($q->param('blog_id'));
        $vote->voter_id($voter->id) if $voter;
        $vote->obj_type($q->param('obj_type'));
        $vote->obj_id($q->param('obj_id'));
        $vote->score($q->param('r'));
        $vote->save or die $vote->errstr;

        # Update the Vote Summary. The summary is used because it will let 
        # publishing happen faster (loading one summary row to publish results
        # is faster than loading many AjaxRating::Vote records).
        my $votesummary = AjaxRating::VoteSummary->load({
            obj_type => $vote->obj_type,
            obj_id   => $vote->obj_id,
        });

        # If no VoteSummary was found for this object, create one and populate 
        # it with "getting started" values.
        if (!$votesummary) {
            $votesummary = AjaxRating::VoteSummary->new;
            $votesummary->obj_type($vote->obj_type);
            $votesummary->obj_id($vote->obj_id);
            $votesummary->blog_id($vote->blog_id);
            $votesummary->author_id($q->param('a'));
            $votesummary->vote_count(0);
            $votesummary->total_score(0);
        }

        # Update the VoteSummary with details of this vote.
        $votesummary->vote_count($votesummary->vote_count + 1);
        $votesummary->total_score($votesummary->total_score + $vote->score);
        $votesummary->avg_score(
            sprintf("%.1f",$votesummary->total_score / $votesummary->vote_count)
        );

        # Update the voting distribution, which makes it easy to output 
        # "X Stars has received Y votes"
        my $yaml = YAML::Tiny->read_string( $votesummary->vote_dist );
        $yaml = YAML::Tiny->new if !$yaml; # No previously-saved data.

        # Increase the vote tally for this score by 1.
        $yaml->[0]->{$vote->score} += 1;

        $votesummary->vote_dist( $yaml->write_string() );
        $votesummary->save or die $votesummary->errstr;

        # Now that the vote has been recorded, rebuild the required pages.
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

        if ($format eq 'json') {
            return _send_json_response( $app,
                { status => "OK", 
                  message => "Vote Successful",
                  obj_type => $votesummary->obj_type,
                  obj_id => $votesummary->obj_id,
                  score => $q->param('r'),
                  total_score => $votesummary->total_score,
                  vote_count => $votesummary->vote_count } );
        } else {
            # Return a string, which uses "||" as separators. The returned string 
            # is parsed by javascript -- splitting the "||" to create an array of 
            # values.
            return "OK||" . $votesummary->obj_type . "||" . $votesummary->obj_id 
                . "||" . $q->param('r') . "||" . $votesummary->total_score . "||" 
                . $votesummary->vote_count;
        }
    }
}

# remove rating/vote
sub unvote {
	my $app = shift;
    my $q = $app->{query};
    my $format = $q->param('format') || 'text';
    return _send_error( $app, $format, "Invalid request, must use POST.")
        if ($app->request_method() ne 'POST');
    my $plugin = MT->component('ajaxrating');
	my $config = $plugin->get_config_hash('blog:'.$q->param('blog_id'));
	my $obj_type = $q->param('obj_type');
	return _send_error( $app, $format, "Invalid object type.")
		if ($config->{ratingl} && ($obj_type ne 'entry') && ($obj_type ne 'blog'));

    my ($session, $voter) = $app->get_commenter_session;
    return _send_error( $app, $format, "Not logged in.")
		if (!$voter);
		
	my $vote = AjaxRating::Vote->load({ voter_id => $voter->id, obj_type => $q->param('obj_type'), obj_id => $q->param('obj_id') });

	if (!$vote) {
	    return _send_error( $app, $format, "Not found");
	} else {
		$vote->remove;

		my $votesummary = AjaxRating::VoteSummary->load({ obj_type => $vote->obj_type, obj_id => $vote->obj_id });
		if ($votesummary) {
    		$votesummary->vote_count($votesummary->vote_count - 1);
    		if ($votesummary->vote_count == 0) {
    		    $votesummary->total_score(0);
    		    $votesummary->avg_score(0);
    		    $votesummary->remove;
    		} else {
        		$votesummary->total_score($votesummary->total_score - $vote->score);
        		$votesummary->avg_score(sprintf("%.1f",$votesummary->total_score / $votesummary->vote_count));	
        		$votesummary->save;	
        	}	
    	}
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
		if ($format eq 'json') {
            return _send_json_response( $app,
                { status => "OK", 
                  message => "Vote Successful",
                  obj_type => $votesummary->obj_type,
                  obj_id => $votesummary->obj_id,
                  score => $q->param('r'),
                  total_score => $votesummary->total_score,
                  vote_count => $votesummary->vote_count } );
        } else {
            # Return a string, which uses "||" as separators. The returned string 
            # is parsed by javascript -- splitting the "||" to create an array of 
            # values.
            return "OK||" . $votesummary->obj_type . "||" . $votesummary->obj_id 
                . "||" . $q->param('r') . "||" . $votesummary->total_score . "||" 
                . $votesummary->vote_count;
        }
	
	} 

}

1;
