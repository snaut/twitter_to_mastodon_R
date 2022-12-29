# Small R script to remove all your tweets
#
# use at own risk!
# 
# I highly recommend to read the whole script before running it, this deletes
# all your tweets
# 
# This script is supposed to be run interactively and prompts for the location
# of the file "tweets.js". I'm assuming you downloaded and extracted your
# twitter data.
#
# You can also delete tweets you get from the twitter API, this is currently
# commented out, just put it back in.


library(tidyverse)
library(rtweet)
library(jsonlite)
library(progress)

# read tweets from archive ------------------------------------------------

# The idea to read the tweets from the archive instead of getting them via the
# API is taken from this brilliant blog entry by Julia Silge:
# https://juliasilge.com/blog/delete-tweets/

# choose the data/tweets.js file from your extracted twitter archive
tweets_js <- file.choose()

# read file contents
raw_text <- read_file(tweets_js)
# removing everything up to the first "[" to get valid JSON
json_text <- str_remove(raw_text, "^[^\\[]*")

# parse JSON and convert to tibble
all_tweets <- as_tibble(fromJSON(json_text)$tweet)


# parse created at date ---------------------------------------------------

# in case you want to filter the tweets by date and only delete old ones
# I'm deleting everyting here

twitter_locale <- locale(
  date_names = "en",
  date_format = "%AD",
  time_format = "%AT",
  decimal_mark = ".",
  grouping_mark = ",",
  tz = "UTC",
  encoding = "UTF-8",
  asciify = FALSE
)

all_tweets <- all_tweets |>
  mutate(
    created_at = parse_datetime(
      created_at,
      format="%a %b %d %H:%M:%S %z %Y",
      locale = twitter_locale
    )
  )


# deleting tweets ---------------------------------------------------------

# add filter expressions here if you don't want to delete everyting
tweets_to_delete <- all_tweets |>
  select(id)

# get oAuth Token for twitter
auth_setup_default()

  
pg <- progress_bar$new(
  total = nrow(tweets_to_delete),
  format = "deleting tweet :current of :total :bar (:percent :elapsed ETA::eta)"
)

delete_tweet_wrapper <- function(id, pg){
  pg$tick()
  tryCatch({
    as.character(suppressMessages(post_destroy(id)))
  },
  error=function(e){
    e$message
  }
  )
}

# this may take a lot of time, for my 28000 tweets this took about 2h
result <- tweets_to_delete %>%
  mutate(
    success = map_chr(
      id,
      delete_tweet_wrapper,
      pg=pg
    )
  )



# get my timeline to check what was deleted -------------------------------
# (or if you want to get tweets via twitter api rather than from the archive)

# user_id <- auth_setup_default()$credentials$user_id
# my_timeline <- get_timeline(user_id)
# 
# my_timeline <- my_timeline |>
#   mutate(
#     id = formatC(id, format="f", digits=0)
#   )
# 
# pg <- progress_bar$new(
#   total = nrow(my_timeline),
#   format = "deleting tweet :current of :total :bar (:percent :elapsed ETA::eta)"
# )
# 
# result_2 <- my_timeline |>
#   select(id) |>
#   mutate(
#     success = map_chr(
#       id,
#       delete_tweet_wrapper,
#       pg=pg
#     )
#   )

# what was not deleted? ---------------------------------------------------

# what tweets weren't deleted
# 404 not found: I'm assuming that this tweet no longer exists
remaining <- result |> 
  filter(str_detect(success, "Twitter API failed")) |>
  filter(!str_detect(success, fixed("[404]"))) |> 
  pull(id)

# # if you also used get_my_timeline use this instead:
# remaining <- union(
#   result |>
#     filter(str_detect(success, "Twitter API failed")) |>
#     filter(!str_detect(success, fixed("[404]"))) |>
#     pull(id),
#   result_2 |>
#     filter(str_detect(success, "Twitter API failed")) |>
#     filter(!str_detect(success, fixed("[404]"))) |>
#     pull(id)
# )

# saving remaining tweet ids
dput(remaining, file="remaining_ids")

# looking at the remaining tweets
# some tweets remaining, I think those are mostly retweets from suspended accounts
# see for yourself, what remains in your list
all_tweets |> 
  filter(id %in% remaining) |> 
  View()

# everything deleted here
my_timeline |> 
  filter(id %in% remaining) |> 
  View()

