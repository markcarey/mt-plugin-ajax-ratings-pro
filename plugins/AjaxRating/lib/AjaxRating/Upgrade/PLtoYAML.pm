package AjaxRating::Upgrade::PLtoYAML;

use strict;
use warnings;

# When installing the new YAML-style plugin, we need to ensure that data and
# plugin settings are migrated. We have to jump through hoops to do this:
# * The plugin ID of the old .pl plugins isn't recreatable in YAML, so we
#   can't just pick it up and go.
# * The YAML plugin can't just run an upgrade because the *new* YAML plugin 
#   hasn't been installed yet and therefore has no need to be upgraded.
#
# The solution then is to install the new YAML plugin, then force the upgrade
# to run. We can do this by checking on the old .pl plugin's existence in the
# mt_config table and using that to know if we need to run an upgrade.
sub run {
    my $app = shift;
    
    use MT::ConfigMgr;
    my $cfg = MT::ConfigMgr->instance;
    
    # Look for the old Ajax Rating plugin ID ("AjaxRating/AjaxRating.pl") in
    # the Plugin Schema Version hash in the mt_config table. If found, we want
    # to force the upgrade to re-run. Also check for the new YAML-style pugin
    # ID ("ajaxrating") exists, which means the plugin has completed
    # installation.
    if ( 
        $cfg->pluginschemaversion->{'AjaxRating/AjaxRating.pl'}
        && $cfg->pluginschemaversion->{'ajaxrating'}
    ) {
        # Reset the new plugin's schema version to force the upgrade to run.
        $cfg->set( 'PluginSchemaVersion', 'ajaxrating=1', 1 );
        
        # Remove the old plugin's schema version from the config object so
        # that we don't try to upgrade again.
        #delete $cfg->pluginschemaversion->{'AjaxRating/AjaxRating.pl'};
    }
}

1;
