## Description

This is MTC's fork of the gtfsr package. Here we maintain functions to do things for MTC business that are probably not directly relevant to the gtfsr project.

There are multiple uses of the general functions of the gtfsr package for MTC work. See [here](https://bayareametro.github.io/Data-And-Visualization-Projects/sb827/sb827_amendment_example.html) for a how to and walk through of some of the more basic functions. 

## Installation

You can install this package from GitHub using the devtools package:

    if (!require(devtools)) {
        install.packages('devtools')
    }
    devtools::install_github('BayAreaMetro/gtfsr')

If you have already installed `gtfsr`, you can get the latest version by
running

    remove.packages('gtfsr')
    devtools::install_github('ropensci/gtfsr')

If you’d like to build the accompanying vignette, then run

    devtools::install_github('BayAreaMetro/gtfsr', build_vignettes = TRUE)

## Example Usage

Output bus stops for sb827 april amendments

```
install.packages("lubridate")
devtools::install_github('BayAreaMetro/gtfsr', ref='generic-frequency-calc')

library(gtfsr)
library(sf)
library(dplyr)
library(lubridate)
library(readr)

time_start1 <- "06:00:00" 
time_end1 <- "19:59:00"
threshold <- 24 #minutes

o511 <- read_csv("https://gist.githubusercontent.com/tibbl35/d49fa2c220733b0072fc7c59e0ac412b/raw/cff45d8c8dd2ea951b83c0be729abe72f35b13f7/511_orgs.csv")

o511 <- o511[!o511$PrimaryMode %in% c('rail','ferry'),]

Sys.setenv(APIKEY511 = "YOURKEYHERE")
api_key = Sys.getenv("APIKEY511")

download_results <- apply(o511, 1, function(x) try(get_mtc_511_gtfs(x['PrivateCode'],api_key)))
is.error <- function(x) inherits(x, "try-error")
is.gtfs.obj <- function(x) inherits(x, "gtfs")
imported_success <- !vapply(download_results, is.error, logical(1))
get.error.message <- function(x) {attr(x,"condition")$message}
import_error_message <- vapply(download_results[!imported_success], get.error.message, "")

o511['downloaded'] <- TRUE
o511['imported'] <- imported_success
o511['import_error_message'] <- ""
o511[!imported_success,'error_message1'] <- import_error_message

#save all objects to disk
save(download_results, file = "gtfs511_downloads.RData")
```

### Get MTC/CA Headways for Routes and Stops

```
process_results <- lapply(download_results, 
                          FUN=function(x) {
                            try(assign_frequencies_to_all_stops(x,
                                                                time_start1 = time_start1,
                                                                time_end1 = time_end1,
                                                                service="weekday"))}
)

is.error <- function(x) inherits(x, "try-error")
processed_success <- vapply(process_results, is.gtfs.obj, logical(1))
get.error.message <- function(x) {attr(x,"condition")$message}

get.routes.table <- function(x) {x$routes_df_frequency}
get.stops.table <- function(x) {x$stops_sf_frequency}

l_routes_df <- lapply(process_results[processed_success], FUN=get.routes.table)
bay_area_routes_df <- do.call("rbind", l_routes_df)



write_excel_csv(bay_area_routes_df,"827_april_amendment2_routes.csv")

l_stops_sf <- lapply(process_results[processed_success], FUN=get.stops.table)
bay_area_stops_sf <- do.call("rbind", l_stops_sf)

#st_write(bay_area_stops_sf,"827_april_amendment2.csv", driver="CSV")
st_write(bay_area_stops_sf,"827_april_amendment2.gpkg",driver="GPKG")
st_write(bay_area_stops_sf,"827_april_amendment2.shp", driver="ESRI Shapefile")

```

### Summarize by Route Headway Threshold

Get summaries for different counts of routes and stops with changing thresholds for headway for the given time period as processed:

```

threshold <- 22 #minutes

get.routes.below.threshold <- function(x) {table(x$routes_df_frequency$median_headways>threshold)[['TRUE']]}
get.stops.below.threshold <- function(x) {table(x$stops_sf_frequency$median_headways>threshold)[['TRUE']]}

process_message <- vapply(process_results[!processed_success], get.error.message, "")
unique_stops_processed <- vapply(process_results[processed_success], get.stops.processed, 0)
unique_routes_processed <- vapply(process_results[processed_success], get.routes.processed, 0)

threshold_routes <- vapply(process_results[processed_success], get.routes.below.threshold, 0)
threshold_stops <- vapply(process_results[processed_success], get.stops.below.threshold, 0)

o511['processed'] <- TRUE
o511['imported'] <- processed_success
o511['process_error_message'] <- ""
o511[!processed_success,'error_message1'] <- process_message

o511['threshold_routes'] <- 0
o511['threshold_stops'] <- 0
o511['unique_stops_processed'] <- 0
o511['unique_routes_processed'] <- 0

o511[processed_success,'threshold_routes'] <- threshold_routes
o511[processed_success,'threshold_stops'] <- threshold_stops
o511[processed_success,'unique_stops_processed'] <- unique_stops_processed
o511[processed_success,'unique_routes_processed'] <- unique_routes_processed

write_csv(o511[,c('Name','threshold_routes','threshold_stops','unique_stops_processed','unique_routes_processed')],"processing_notes_22_mins.csv")


threshold <- 21 #minutes

get.routes.below.threshold <- function(x) {table(x$routes_df_frequency$median_headways>threshold)[['TRUE']]}
get.stops.below.threshold <- function(x) {table(x$stops_sf_frequency$median_headways>threshold)[['TRUE']]}

process_message <- vapply(process_results[!processed_success], get.error.message, "")
unique_stops_processed <- vapply(process_results[processed_success], get.stops.processed, 0)
unique_routes_processed <- vapply(process_results[processed_success], get.routes.processed, 0)

threshold_routes <- vapply(process_results[processed_success], get.routes.below.threshold, 0)
threshold_stops <- vapply(process_results[processed_success], get.stops.below.threshold, 0)

o511['processed'] <- TRUE
o511['imported'] <- processed_success
o511['process_error_message'] <- ""
o511[!processed_success,'error_message1'] <- process_message

o511['threshold_routes'] <- 0
o511['threshold_stops'] <- 0
o511['unique_stops_processed'] <- 0
o511['unique_routes_processed'] <- 0

o511[processed_success,'threshold_routes'] <- threshold_routes
o511[processed_success,'threshold_stops'] <- threshold_stops
o511[processed_success,'unique_stops_processed'] <- unique_stops_processed
o511[processed_success,'unique_routes_processed'] <- unique_routes_processed

write_csv(o511[,c('Name','threshold_routes','threshold_stops','unique_stops_processed','unique_routes_processed')],"processing_notes_22_mins.csv")



threshold <- 20 #minutes

get.routes.below.threshold <- function(x) {table(x$routes_df_frequency$median_headways<threshold)[['TRUE']]}
get.stops.below.threshold <- function(x) {table(x$stops_sf_frequency$median_headways<threshold)[['TRUE']]}

process_message <- vapply(process_results[!processed_success], get.error.message, "")
unique_stops_processed <- vapply(process_results[processed_success], get.stops.processed, 0)
unique_routes_processed <- vapply(process_results[processed_success], get.routes.processed, 0)

threshold_routes <- vapply(process_results[processed_success], get.routes.below.threshold, 0)
threshold_stops <- vapply(process_results[processed_success], get.stops.below.threshold, 0)

o511['processed'] <- TRUE
o511['imported'] <- processed_success
o511['process_error_message'] <- ""
o511[!processed_success,'error_message1'] <- process_message

o511['threshold_routes'] <- 0
o511['threshold_stops'] <- 0
o511['unique_stops_processed'] <- 0
o511['unique_routes_processed'] <- 0

o511[processed_success,'threshold_routes'] <- threshold_routes
o511[processed_success,'threshold_stops'] <- threshold_stops
o511[processed_success,'unique_stops_processed'] <- unique_stops_processed
o511[processed_success,'unique_routes_processed'] <- unique_routes_processed

write_csv(o511[,c('Name','threshold_routes','threshold_stops','unique_stops_processed','unique_routes_processed')],"processing_notes_20_mins.csv")

```





