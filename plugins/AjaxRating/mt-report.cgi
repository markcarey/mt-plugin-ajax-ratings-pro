#!/usr/bin/perl -w
#
#  Movable Type Plugin
# http://mt-hacks.com/ajaxrating.html
#

use strict;
use lib "lib", ($ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : "../../lib");
use MT::Bootstrap App => 'AjaxRating::ReportComment';

__END__