# Ajax Ratings Pro

http://mt-hacks.com/ajaxrating.html

Refer to the above URL for documentation on this plugin. The following documents additions made since version 1.261.

# Upgrading

Version 1.3 is converted to a `config.yaml` style plugin. Be sure to remove the old `AjaxRating.pl` file when upgrading. Also note that plugin data is stored differently, so you will need to re-set Ajax Rating Plugin Settings, at both the System and Blog level.

# Tag Reference

## AjaxRatingVoteDistribution

The tag `AjaxRatingVoteDistribution` is a block tag that will provide insight to the votes received on an object. Within this block tag, access the `score` and `vote` variables to understand the voting distribution, as in the following example:

    <mt:AjaxRatingVoteDistribution>
        <mt:If name="__first__">
        <ul>
        </mt:If>
            <li><mt:Var name="score"> stars received <mt:Var name="vote"> votes.</li>
        <mt:If name="__last__">
        </ul>
        </mt:If>
    </mt:AjaxRatingVoteDistribution>

As you'll notice, the loop meta variables are also supported, including `__first__`, `__last__`, `__odd__`, `__even__`, and `__counter__`.
