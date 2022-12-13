# Small R script to extract mastodon usernames from twitter bios
#
# use at own risk!
# 
# I highly recommend to read the whole script before running it, and check
# output before editing your following list on mastodon. 
# 
# This script is supposed to be run interactively and prompts for file
# locations, logins, etc.

library(tidyverse)
library(rtweet)
library(rtoot)
library(curl)
library(jsonlite)
library(magrittr)
library(progress)

twitter_username <- readline("enter your twitter username: ") %>%
  str_trim()

# get a list of all mastodon instances ------------------------------------

# you can skip this part and leave out the parameter instances_list_cleaned 
# later
# I however recommend this step, found a lot more contacts with this list, than
# by just searching for @something@domain.tld

# # Get an API Token for instances.social
browseURL("https://instances.social/api/token")

instances_social_app_id <- readline("enter the app id you just got from instances.social: ") %>%
  str_trim()

instances_social_bearer_token <- readline("enter the bearer token you just got from instances.social: ") %>%
  str_trim()


message("downloading instances List")
h <- new_handle()
handle_setheaders(h, Authorization=paste0("Bearer ", instances_social_bearer_token))
conn <- curl("https://instances.social/api/1.0/instances/list?count=0", handle=h)
res <- readLines(conn)
res <- paste0(res, "\n")
close(conn)

instances_list <- fromJSON(res)[[1]]$name

instances_list_clean <- instances_list %>% 
  str_subset("\\w+\\.\\w+") %>% # should contain at least word characters a dot and some more word characters
  keep(~nchar(.x) > 5) # keeping only domains with more than 5 characters to avoid false positives in matches, feel free to tune this parameter

# get all people you follow on twitter ------------------------------------

# get oAuth Token for twitter
auth_setup_default()

message("getting user descriptions from twitter API")
all_friends <- get_friends(twitter_username, n = Inf, retryonratelimit = TRUE)
all_descriptions <- lookup_users(users=all_friends$to_id, retryonratelimit = TRUE)

# extract mastodon usernames ----------------------------------------------

# This function does the actual work
#   texts: character vector of the texts you want to extract the mastodon 
#     handles from (e.g. twitter bios)
#   instance_list (optional) list of urls of known mastodon instances
extract_masto_usernames <- function(texts, instances_list=NULL){
  
  res <- character(0)
  failed_extract <- character(0)
  
  # extract all mastodon handles in the default format @username@server.tld
  message("searching for all @username@domain.tld")
  
  all_masto_handles1 <- texts %>% 
    str_subset("(?<=\\s@)\\w*@\\w+\\.\\w+") %>%
    str_extract_all("(?<=\\s@)\\w*@\\w+\\.\\w+")
  
  indices_masto_handles1 <- texts %>% 
    str_detect("(?<=\\s)@\\w*@\\w+\\.\\w+")
  
  res <- union(res, flatten_chr(all_masto_handles1))
  
  if(!is.null(instances_list)){
    # extract all descriptions containing known instances
    message("searching for all known instances in all texts (might take some time)")
    
    pb <- progress_bar$new(total=length(texts))
    message("detecting instance names")
    indices_masto_handles_and_instances <- texts %>% 
      map(\(x){
        pb$tick()
        str_detect(x, fixed(instances_list))
      }) %>% 
      do.call(what=cbind)
    
    indices_instances <- apply(indices_masto_handles_and_instances, 1, any, na.rm=TRUE)
    indices_masto_handles2 <- apply(indices_masto_handles_and_instances, 2, any, na.rm=TRUE)
    
    instances_found <- instances_list[indices_instances]
    
    message("extracting usernames in @asdf@asdf format")
    all_masto_handles2 <- texts[indices_masto_handles2] %>% 
      map(\(x){
        x %>% 
          str_extract_all(str_c("[0-9A-Za-z_\\.]+@", instances_found)) %>% 
          compact() %>% 
          flatten_chr()
      })
    
    
    
    message("extracting usernames in asdf.social/@asdf format")
    all_masto_handles3_url <- texts[indices_masto_handles2] %>% 
      map(\(x){
        x %>% 
          str_extract_all(str_c(instances_found, "/@.*")) %>% 
          compact() %>% 
          flatten_chr()
      })
    
    all_masto_handles3 <- all_masto_handles3_url  %>% 
      flatten_chr() %>%
      str_replace_all("([^/]*)/(.*)", "\\2@\\1")
    
    all_masto_handles4 <- c(all_masto_handles2, all_masto_handles3)
    
    no_match2_1 <- texts %>% 
      extract(indices_masto_handles2) %>% 
      extract(map_lgl(c(all_masto_handles2), \(x) length(x)==0))
    
    no_match2_2 <- texts %>% 
      extract(indices_masto_handles2) %>% 
      extract(map_lgl(c(all_masto_handles3_url), \(x) length(x)==0))
    
    no_match2 <- intersect(no_match2_1, no_match2_2)
    
    failed_extract <- union(failed_extract, no_match2) %>% 
      sort()
    
    all_masto_handles4 <- flatten_chr(all_masto_handles4)
    
    res <- union(res, all_masto_handles4)
  } else {
    message("no instance list given, skipping extraction of known instances")
  }
  
  if(length(failed_extract) > 0){
    warning("There are texts that contain domains but no username could be extracted, inspect failed_extract attribute of output.")
  }
  
  res <- sort(res)
  attr(res, "failed_extract") <- failed_extract
  res
}

message("searching in bios")
mastodon_usernames1 <- extract_masto_usernames(all_descriptions$description, instances_list_clean)

message("searching in screen names")
mastodon_usernames2 <- extract_masto_usernames(all_descriptions$screen_name, instances_list_clean)

message("searching in description entities")
all_entry_urls <- all_descriptions$entities %>% 
  map(\(x) flatten_chr(map(x, \(y) y$expanded_url))) %>% 
  flatten_chr()
mastodon_usernames3 <- extract_masto_usernames(all_entry_urls, instances_list_clean)

account_names <- c(
  mastodon_usernames1,
  mastodon_usernames2,
  mastodon_usernames3
) |>
  unique() |> 
  sort()

# add manuall changes here
account_names <- account_names %>% 
  setdiff(c()) %>%   # comma seperated list of usernames you want to delete
  union(c()) %>%     # comma seperated list of usernames you want to add
  str_remove("^@")

# export in a suitable format ---------------------------------------------

export_csv <- data.frame(
  `Account address` = account_names, 
  `Show boosts` = "true",
  `Notify on new posts` = "false",
  `Languages` = "",
  check.names = FALSE
)

# # optional, remove account you already follow
# # download the csv from your mastodon instance and choose it when prompted.
# import_csv <- read_csv(file.choose(), name_repair = "minimal")
# export_csv <- anti_join(export_csv, import_csv, by="Account address")

# save the csv file an upload it to your instance
# be careful to select "merge" not "override" as not to delete people you follow
write_csv(export_csv, file.choose(new=TRUE), quote = "none", escape = "none")

