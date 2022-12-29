# Move from twitter to mastodon

This repository includes some R scripts to help with the migration from twitter to mastodon. I mainly wrote them for my own use, but feel free to use them.

Please be considerate with the ammount of requests you make to APIs.

The scripts are somewhat limited because `rtweet` currently does not support the latest twitter API, so for example, searching for mastodon usernames in pinned tweets does not work.

Everything provided as is without any warranty, etc.

## Usage

Download the scripts and source them in your favourite R console. The scripts are meant to be run interactively and will prompt for input, they should however be easy to modify to run wihtout (or with less) user interaction.

## Scripts

* `find_mastodon_users_on_twitter.R` searches for mastodon usernames formatted as `@user@instance` or strings containing known mastodon instances in twitter usernames, twitter bios and twitter description entities and outputs a csv that can be imported in mastodon.
* `delete_all_tweets.R` deletes all tweets from your downloaded twitter archive. Includes code to get tweets from twitter API instead of archive. Can also be used to delete only tweets matching criteria, just add your criteria.
