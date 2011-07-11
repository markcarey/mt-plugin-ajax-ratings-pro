# Ajax Ratings Pro

http://mt-hacks.com/ajaxrating.html

Refer to the above URL for documentation on this plugin. The following
documents additions made since version 1.261.

# Upgrading

Version 1.3 is converted to a `config.yaml` style plugin. Be sure to remove
the old `AjaxRating.pl` file when upgrading. Also note that plugin data is
stored differently, so you will need to re-set Ajax Rating Plugin Settings, at
both the System and Blog level.

Version 1.3 also changes its table names, shortening them for compatibility
with Oracle. The upgrade routine should handle this without any special
intervention from an administrator, nor does it require any changes to your
templates -- it's mentioned here simply because it is a significant change to
the plugin.

# Configuration

In System Overview > Plugins > Ajax Rating Pro > Settings, you'll find an
option to Enable IP Checking. This checkbox provides an easy way to restrict
votes by IP address. Disable during development for easy testing.

# Tag Reference

## AjaxRatingVoteDistribution

The tag `AjaxRatingVoteDistribution` is a block tag that will provide insight
to the votes received on an object. Within this block tag, access the `score`
and `vote` variables to understand the voting distribution, as in the
following example:

    <mt:AjaxRatingVoteDistribution>
        <mt:If name="__first__">
        <ul>
        </mt:If>
            <li><mt:Var name="score"> stars received <mt:Var name="vote"> votes.</li>
        <mt:If name="__last__">
        </ul>
        </mt:If>
    </mt:AjaxRatingVoteDistribution>

As you'll notice, the loop meta variables are also supported, including
`__first__`, `__last__`, `__odd__`, `__even__`, and `__counter__`.
