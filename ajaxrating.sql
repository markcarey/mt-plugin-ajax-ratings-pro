# If you are running MT 3.2 you will need to create tables manually

#
# Table structure for table mt_ajaxrating_votesummary
#


DROP TABLE IF EXISTS `mt_ajaxrating_votesummary`;
CREATE TABLE `mt_ajaxrating_votesummary` (
  `ajaxrating_votesummary_id` int(11) NOT NULL auto_increment,
  `ajaxrating_votesummary_author_id` int(11) default NULL,
  `ajaxrating_votesummary_avg_score` float default NULL,
  `ajaxrating_votesummary_blog_id` int(11) default NULL,
  `ajaxrating_votesummary_obj_id` int(11) default NULL,
  `ajaxrating_votesummary_obj_type` varchar(50) NOT NULL default '',
  `ajaxrating_votesummary_total_score` int(11) default NULL,
  `ajaxrating_votesummary_vote_count` int(11) default NULL,
  `ajaxrating_votesummary_created_on` datetime default NULL,
  `ajaxrating_votesummary_created_by` int(11) default NULL,
  `ajaxrating_votesummary_modified_on` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `ajaxrating_votesummary_modified_by` int(11) default NULL,
  PRIMARY KEY  (`ajaxrating_votesummary_id`),
  KEY `mt_ajaxrating_votesummary_author_id` (`ajaxrating_votesummary_author_id`),
  KEY `mt_ajaxrating_votesummary_obj_id` (`ajaxrating_votesummary_obj_id`),
  KEY `mt_ajaxrating_votesummary_vote_count` (`ajaxrating_votesummary_vote_count`),
  KEY `mt_ajaxrating_votesummary_total_score` (`ajaxrating_votesummary_total_score`),
  KEY `mt_ajaxrating_votesummary_avg_score` (`ajaxrating_votesummary_avg_score`),
  KEY `mt_ajaxrating_votesummary_blog_id` (`ajaxrating_votesummary_blog_id`),
  KEY `mt_ajaxrating_votesummary_obj_type` (`ajaxrating_votesummary_obj_type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;


#
# Table structure for table mt_ajaxrating_vote
#


DROP TABLE IF EXISTS `mt_ajaxrating_vote`;
CREATE TABLE `mt_ajaxrating_vote` (
  `ajaxrating_vote_id` int(11) NOT NULL auto_increment,
  `ajaxrating_vote_blog_id` int(11) default NULL,
  `ajaxrating_vote_ip` varchar(15) default NULL,
  `ajaxrating_vote_obj_id` int(11) default NULL,
  `ajaxrating_vote_obj_type` varchar(50) NOT NULL default '',
  `ajaxrating_vote_score` int(11) default NULL,
  `ajaxrating_vote_created_on` datetime default NULL,
  `ajaxrating_vote_created_by` int(11) default NULL,
  `ajaxrating_vote_modified_on` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `ajaxrating_vote_modified_by` int(11) default NULL,
  PRIMARY KEY  (`ajaxrating_vote_id`),
  KEY `mt_ajaxrating_vote_obj_id` (`ajaxrating_vote_obj_id`),
  KEY `mt_ajaxrating_vote_ip` (`ajaxrating_vote_ip`),
  KEY `mt_ajaxrating_vote_blog_id` (`ajaxrating_vote_blog_id`),
  KEY `mt_ajaxrating_vote_obj_type` (`ajaxrating_vote_obj_type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;


#
# Table structure for table mt_ajaxrating_hotobject
#



DROP TABLE IF EXISTS `mt_ajaxrating_hotobject`;
CREATE TABLE `mt_ajaxrating_hotobject` (
  `ajaxrating_hotobject_id` int(11) NOT NULL auto_increment,
  `ajaxrating_hotobject_author_id` int(11) default NULL,
  `ajaxrating_hotobject_avg_score` float default NULL,
  `ajaxrating_hotobject_blog_id` int(11) default NULL,
  `ajaxrating_hotobject_obj_id` int(11) default NULL,
  `ajaxrating_hotobject_obj_type` varchar(50) NOT NULL default '',
  `ajaxrating_hotobject_total_score` int(11) default NULL,
  `ajaxrating_hotobject_vote_count` int(11) default NULL,
  `ajaxrating_hotobject_created_on` datetime default NULL,
  `ajaxrating_hotobject_created_by` int(11) default NULL,
  `ajaxrating_hotobject_modified_on` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `ajaxrating_hotobject_modified_by` int(11) default NULL,
  PRIMARY KEY  (`ajaxrating_hotobject_id`),
  KEY `mt_ajaxrating_hotobject_author_id` (`ajaxrating_hotobject_author_id`),
  KEY `mt_ajaxrating_hotobject_obj_id` (`ajaxrating_hotobject_obj_id`),
  KEY `mt_ajaxrating_hotobject_vote_count` (`ajaxrating_hotobject_vote_count`),
  KEY `mt_ajaxrating_hotobject_total_score` (`ajaxrating_hotobject_total_score`),
  KEY `mt_ajaxrating_hotobject_avg_score` (`ajaxrating_hotobject_avg_score`),
  KEY `mt_ajaxrating_hotobject_blog_id` (`ajaxrating_hotobject_blog_id`),
  KEY `mt_ajaxrating_hotobject_obj_type` (`ajaxrating_hotobject_obj_type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

