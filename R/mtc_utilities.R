#' Make a dataframe GTFS tables all joined together for route frequency calculations
#' @param a GTFSr object for a given provider with routes, stops, stop_times, etc
#' @export
#' @return a mega-GTFSr data frame with stops, stop_times, trips, calendar, and routes all joined
join_all_gtfs_tables <- function(g) {
  df <- list(g$stops_df,g$stop_times_df,g$trips_df,g$calendar_df,g$routes_df)
  Reduce(inner_join,df) %>%
    select(agency_id, stop_id, trip_id, service_id,
           monday, tuesday, wednesday, thursday, friday,
           saturday,sunday,
           route_id, trip_headsign, direction_id,
           arrival_time, stop_sequence,
           route_type, stop_lat, stop_lon) %>%
    arrange(agency_id, trip_id, service_id,
            monday, tuesday, wednesday, thursday, friday,
            saturday,sunday,
            route_id, trip_headsign, direction_id,
            arrival_time, stop_sequence) -> df_sr
  #clean up source data
  rm(df)
  df_sr$Route_Pattern_ID<-paste0(df_sr$agency_id,
                                 "-",df_sr$route_id,"-",
                                 df_sr$direction_id)
  return(df_sr)
}

#' Get the service id's for weekdays
#' @param a gtfsr object
#' @export
#' @return service_ids for weekday trips
weekday_service_ids <- function(g1) {
  gtfs_df <- g1$calendar_df
  gtfs_df <- subset(gtfs_df, gtfs_df$monday == 1 & 
                      gtfs_df$tuesday == 1 & 
                      gtfs_df$wednesday == 1 & 
                      gtfs_df$thursday == 1 & 
                      gtfs_df$friday == 1)
  return(gtfs_df$service_id)
}

#' Get the service id's for saturday
#' @param a gtfsr object
#' @export
#' @return service_ids character vector
saturday_service_ids <- function(g1) {
  gtfs_df <- g1$calendar_df
  gtfs_df <- subset(gtfs_df, gtfs_df$saturday == 1)
  return(gtfs_df$service_id)
}

#' Get the service id's for sunday
#' @param a gtfsr object
#' @export
#' @return service_ids character vector
sunday_service_ids <- function(g1) {
  gtfs_df <- g1$calendar_df
  gtfs_df <- subset(gtfs_df, gtfs_df$sunday == 1)
  return(gtfs_df$service_id)
}


#' Get all times a bus stops during weekday service for any service id
#' @param a dataframe made by joining all the GTFS tables together
#' @export
#' @return a mega-GTFSr dataframe filtered to weekday services
all_weekday_bus_service <- function(gtfs_df) {
  gtfs_df <- subset(gtfs_df, gtfs_df$monday == 1 & 
                      gtfs_df$tuesday == 1 & 
                      gtfs_df$wednesday == 1 & 
                      gtfs_df$thursday == 1 & 
                      gtfs_df$friday == 1 & 
                      gtfs_df$route_type == 3)
  return(gtfs_df)
}

#' Get all times a bus stops during saturday service for any service id
#' @param a dataframe made by joining all the GTFS tables together
#' @export
#' @return a mega-GTFSr dataframe filtered to saturday services
saturday_bus_service <- function(gtfs_df) {
  gtfs_df <- subset(gtfs_df, gtfs_df$saturday == 1 & 
                      gtfs_df$route_type == 3)
  return(gtfs_df)
}

#' Get all times a bus stops during sunday service for any service id
#' @param a dataframe made by joining all the GTFS tables together
#' @export
#' @return a mega-GTFSr dataframe filtered to sunday services
sunday_bus_service <- function(gtfs_df) {
  gtfs_df <- subset(gtfs_df, gtfs_df$sunday == 1 &
                      gtfs_df$route_type == 3)
  return(gtfs_df)
}

######
##Custom Time Format Functions
######

#' Make a dataframe GTFS arrival_time column into standard time variable
#' @param dataframe containing a GTFS-style "arrival_time" column (time values at +24:00:00)
#' @export
#' @return dataframe containing a GTFS-style "arrival_time" column (no time values at +24:00:00)
make_arrival_hour_less_than_24 <- function(df) {
  t1 <- df$arrival_time
  if (!(typeof(t1) == "character")) {
    stop("column not a character string--may already be fixed")
  }
  df$arrival_time <- sapply(t1,FUN=fix_hour)
  df$arrival_time <- as.POSIXct(df$arrival_time, format= "%H:%M:%S")
  df
}

#' @export
has_service <- function(df_sr) {
  return(!dim(df_sr)[[1]]==0)
}

#' Format a time string in the expected format
#' @param x a GTFS hour string with an hour greater than 24
#' @param hour_replacement the hour to replace the >24 value with
#' @export
#' @return a string formatted hh:mm:ss 
format_new_hour_string <- function(x,hour_replacement) {
  xl <- length(unlist(strsplit(x,":")))
  if (xl > 3){
    stop("unexpected time string")
  }
  minute <- as.integer(unlist(strsplit(x,":"))[[2]])
  second <- as.integer(unlist(strsplit(x,":"))[[3]])
  x <- paste(c(hour_replacement,minute,second),collapse=":")
  return(x)
}

#' Format GTFS Time strings as standard time string
#' @param a GTFS Time string
#' @export
#' @return Time string with no hours greater than 24
fix_hour <- function(x) {
  # use:
  #   t1 <- stop_times$arrival_time
  #   stop_times$arrival_time <- sapply(t1,FUN=fix_hour)
  if(!is.na(x)) {
    hour <- as.integer(unlist(strsplit(x,":"))[[1]])
    if(!is.na(hour) & hour > 23) {
      hour <- hour-24
      x <- format_new_hour_string(x, hour)
      if (hour > 47){
        stop("hour is greater than 47 in stop times")
      }
    }
  }
  x
}

######
##Custom Bus Frequency Functions
######

#' Get trips and headways based on the number of trips a set of buses on a route take in a specified time frame
#' @param a dataframe made by joining all the GTFS tables together
#' @param a start time filter hh:mm:ss
#' @param an end time filter hh:mm:ss
#' @export
#' @return a mega-GTFSr dataframe filtered to rows of interest
filter_by_time <- function(rt_df, 
                           time_start="06:00:00", 
                           time_end="09:59:00") {
  time_start <- paste(c(format(Sys.Date(), "%Y-%m-%d"),
                        time_start),collapse=" ")
  time_end <- paste(c(format(Sys.Date(), "%Y-%m-%d"),
                      time_end),collapse=" ")
  rt_df_out <- subset(rt_df, 
                      rt_df$arrival_time > time_start
                      & rt_df$arrival_time < time_end)
  return(rt_df_out)
}

#' for a mega-GTFSr dataframe, count the number of trips a bus takes through a given stop within a given time period
#' @param a mega-GTFSr dataframe
#' @param wide if true, then return a wide rather than tidy data frame
#' @param service_id (optional) a service id to filter by
#' @export
#' @return a dataframe of stops with a "Trips" variable representing the count trips taken through each stop for a route within a given time frame
count_departures <- function(rt_df, select_service_id, wide=FALSE) {
  rt_df_out <- rt_df %>%
    group_by(agency_id,
             route_id,
             direction_id,
             trip_headsign,
             stop_id,
             service_id) %>%
    summarise(departures = n()) %>% 
    as.data.frame()
  #with this summary, every route has 1 stop with a departure count of 1
  #this isn't right and throws off headway calculations
  #need to describe this better but for now slicing out
  rt_df_out <- rt_df_out %>% 
    group_by(route_id) %>%
      arrange(departures) %>%
        slice(1:n()-1)
  if(!missing(select_service_id)) {
    rt_df_out <- rt_df_out %>% filter(service_id %in% select_service_id)
  }
  if(wide==TRUE){
    rt_df_out <- rt_df_out %>%
      unite(service_and_direction, direction_id,service_id) %>%
      tibble::rowid_to_column() %>%
      spread(service_and_direction, departures, sep="_")
  }

  return(rt_df_out)
}

#' Get a set of stops for a route
#' 
#' @param a gtfsr object
#' @return count of service by id
#' @export
count_trips_for_service <- function(g1) {
  df <- group_by(g1$trips_df,service_id) %>% summarise(n_trips = n())
  return(arrange(df,
                 desc(n_trips)))
}

#' Get a set of stops for a route
#' 
#' @param a dataframe output by join_mega_and_hf_routes()
#' @param route_id the id of the route
#' @param service_id the service for which to get stops 
#' @return stops for a route
#' @export
get_stops_for_route <- function(g1, select_route_id, select_service_id) {
  some_trips <- g1$trips_df %>%
    filter(route_id %in% select_route_id & service_id %in% select_service_id)
  
  some_stop_times <- g1$stop_times_df %>% 
    filter(trip_id %in% some_trips$trip_id) 
  
  some_stops <- g1$stops_df %>%
    filter(stop_id %in% some_stop_times$stop_id)
  
  some_stops$route_id <- select_route_id
  return(some_stops)
}

#' Get a set of stops for a given set of service ids
#' 
#' @param g1 gtfsr object
#' @param service_ids the service for which to get stops 
#' @return stops for a given service
#' @export
get_stops_for_service <- function(g1, select_service_id) {
  some_trips <- g1$trips_df %>%
    filter(service_id %in% select_service_id)
  
  some_stop_times <- g1$stop_times_df %>% 
    filter(trip_id %in% some_trips$trip_id) 
  
  some_stops <- g1$stops_df %>%
    filter(stop_id %in% some_stop_times$stop_id)
  
  return(some_stops)
}

#' Get a set of shapes for a route
#' 
#'
#' @param a dataframe output by join_mega_and_hf_routes()
#' @param route_id the id of the route
#' @param service_id the service for which to get stops 
#' @return shapes for a route
#' @export
get_shape_for_route <- function(g1, select_route_id, select_service_id) {
  some_trips <- g1$trips_df %>%
    filter(route_id %in% select_route_id & service_id %in% select_service_id)
  
  some_shapes <- g1$shapes_df %>% 
    filter(shape_id %in% some_trips$shape_id) 
  
  some_shapes$route_id <- select_route_id
  return(some_shapes)
}


#' Get a set of shapes for a set of routes
#' 
#' @param a dataframe output by join_mega_and_hf_routes()
#' @param route_ids the ids of the routes
#' @param service_id the service for which to get stops 
#' @param directional if the routes should by related to a route direction (e.g. inbound, outbound) - currently not implemented
#' @return shapes for routes
#' @export
get_shapes_for_routes <- function(g1, route_ids, select_service_ids, directional=FALSE) {
  l1 = list()
  i <- 1
  for (route_id in route_ids) {
    l1[[i]] <- get_shape_for_route(g1,route_id, select_service_ids)
    i <- i + 1
  }
  df_routes <- do.call("rbind", l1)
  return(df_routes)
}


#' TODO: this should get routes for stops by direction_id
#' should take list of directions and routes (optionally?)
#` Get a set of stops for a set of routes
#' @param a dataframe output by join_mega_and_hf_routes()
#' @param route_ids the ids of the routes
#' @param service_id the service for which to get stops 
#' @param directional if the stops should by related to a route direction (e.g. inbound, outbound) - currently not implemented
#' @return stops for routes
#' @export
get_stops_for_routes <- function(g1, route_ids, select_service_ids, directional=FALSE) {
  l1 = list()
  i <- 1
  for (route_id in route_ids) {
    l1[[i]] <- get_stops_for_route(g1,route_id, select_service_ids)
    i <- i + 1
  }
  df_stops <- do.call("rbind", l1)
  return(df_stops)
}

get_routes_for_stops <- function(stop_ids) {
  some_stop_times <- g1$stop_times_df %>% 
    filter(stop_id %in% some_stops$stop_id) 
  
  some_trips <- g1$trips_df %>%
    filter(trip_id %in% some_stop_times$trip_id)
  
  some_routes <- g1$routes_df %>%
    filter(route_id %in% some_trips$route_id)
}

#' Get stop frequency for buses based on mtc headway calculations
#' 
#' @param g1 a gtfsr object
#' @param start_time the start of the period of interest
#' @param end_time the end of the period of interest
#' @param service default to "weekday", can also use "weekend" currently
#' @return stops for routes
#' @export
get_stop_frequency <- function(g1, start_time, 
                               end_time, 
                               service="weekday") {
  df_sr <- join_all_gtfs_tables(g1)
  df_sr <- make_arrival_hour_less_than_24(df_sr)
  if (has_service(df_sr)) {
    output_stops <- filter_by_schedule(df_sr,service)
    output_stops <- filter_by_time(output_stops,
                               time_start=start_time, 
                               time_end=end_time)
    
    output_stops <- count_departures(output_stops) 
    
    #departure count to headway
    t1 <- hms(end_time) - hms(start_time)
    minutes1 <- period_to_seconds(t1)/60
    output_stops$headway <- minutes1/output_stops$departures
    return(output_stops)
  }
}

#' Get stop frequency for buses based on mtc headway calculations
#' 
#' @param gtfs_df a mega df object made by join_all_gtfs_tables
#' @param service default to "weekday", can also use "weekend" currently
#' @return a gtfs mega df object filtered
#' @export
filter_by_schedule <- function(gtfs_df, service="weekday") {
  if(service=="weekday"){
    gtfs_df <- all_weekday_bus_service(gtfs_df)
  } else if (service=="saturday") {
    gtfs_df <- saturday_bus_service(gtfs_df) }
  else if (service=="sunday") {
    gtfs_df <- sunday_bus_service(gtfs_df)
  } else {
    print("unknown service-should be weekend or weekday")
  }
  return(gtfs_df)
}

#' Use the gtfsr import_gtfs function to import an MTC 511 api endpoint to a standarf gtfsr object
#' @param privatecode this is the shortcode used by 511 to refer to operators
#' @return a gtfsr object
#' @export
get_mtc_511_gtfs <- function(privatecode,api_key) {
  zip_request_url = paste0('https://api.511.org/transit/datafeeds?api_key=',
                           api_key,
                           '&operator_id=',
                           privatecode)
  g1 <- zip_request_url %>% import_gtfs
  return(g1)
}

#' Get stop frequency for buses aggregated up to routes
#' 
#' should take: 
#' @param gtfs_obj a standard gtfsr object
#' @param start_time, 
#' @param end_time, 
#' @param service e.g. "weekend" or "saturday"
#' @return route_headways a dataframe of route headways
#' @export
get_route_frequency <- function(gtfs_obj,
                                time_start1, 
                                time_end1, 
                                service=service) {
  stop_frequency_df <- get_stop_frequency(gtfs_obj,
                      time_start1, 
                      time_end1, 
                      service=service)  
  
  if (has_service(stop_frequency_df)) {
    route_headways <- stop_frequency_df %>%
      group_by(route_id) %>%
      summarise(median_headways = as.integer(round(median(headway),0)),
                mean_headways = as.integer(round(mean(headway),0)),
                std_dev_headways = round(sd(headway),2),
                observations = n())
  } else
  {
    stop("agency gtfs has no published service for the specified period")
  }
  route_headways$agency_id <- gtfs_obj$agency_df$agency_id
  route_headways$agency_name <- gtfs_obj$agency_df$agency_name
  return(route_headways)
}

#' Get stop frequency for buses based on mtc headway calculations
#' 
#' should take: start_time, end_time, gtfs_object, and some kind of scheduleing (array of days or "weekend")
#' @param gtfs_obj a standard gtfsr object
#' @return gtfs_obj a gtfsr object with route level 
#' frequencies (routes_df_frequency) as a dataframe 
#' and a spatial stops_sf (stops_sf_frequency) with median frequencies
#' @export
assign_frequencies_to_all_stops <- function(gtfs_obj, 
                                      time_start1, 
                                      time_end1,
                                      service) {
  routes_df_frequency <- get_route_frequency(gtfs_obj,
                      time_start1, 
                      time_end1, 
                      service=service)
  
  route_ids <- unique(routes_df_frequency$route_id)
  
  stops_df <- get_stops_for_routes(gtfs_obj,
                                     route_ids,
                                     weekday_service_ids(gtfs_obj))
    
  stops_df_frequency <- left_join(stops_df,
                        routes_df_frequency, 
                        by="route_id")
    
  stops_sf_frequency <- stops_df_as_sf(stops_df_frequency)
  stops_sf_frequency <- stops_sf_frequency %>% select(stop_id,route_id,stop_name,mean_headways,median_headways,std_dev_headways,observations)
  
  gtfs_obj$stops_sf_frequency <- stops_sf_frequency
  gtfs_obj$routes_df_frequency <- routes_df_frequency
  return(gtfs_obj)
}

#' Merge gtfsr data frames across gtfs objects
#' 
#' merges gtfsr objects
#' @param gtfs_obj_list a list of standard gtfsr objects
#' @param dfname dataframe to return
#' @return one gtfsr dataframe object
#' @export
merge_gtfsr_dfs <- function(gtfs_obj_list,dfname) {
  l_dfs <- lapply(gtfs_obj_list, 
                            FUN=function(x) {
                              try(add_agency_columns_to_df(x,dfname))}
  )
  is.df.obj <- function(x) inherits(x, "data.frame")
  processed_success <- vapply(l_dfs, is.df.obj, logical(1))
  df_bound <- do.call("rbind", l_dfs[processed_success])
  return(df_bound)
}

#' Adds columns to a gtfsr data frame with the agency id and name
#' 
#' adds agency details to a gtfsr dataframe
#' @param gtfs_obj a list of standard gtfsr objects
#' @param dfname dataframe to return
#' @return select data frame with the agency id and name
#' @export
add_agency_columns_to_df <- function(gtfs_obj,dfname) {
  agency_id <- gtfs_obj$agency_df$agency_id
  agency_name <- gtfs_obj$agency_df$agency_name
  df1 <- gtfs_obj[[dfname]]
  if(has_service(df1)){
    df1$agency_id <- agency_id
    df1$agency_name <- agency_name
  }
  return(df1)
}

#' Buffer using common urban planner distances
#' 
#' merges gtfsr objects
#' @param df_sf1 a simple features data frame
#' @param dist default "h" - for half mile buffers. can also pass "q".
#' @param crs default epsg 26910. can be any other epsg
#' @return a simple features data frame with planner buffers
#' @export
planner_buffer <- function(df_sf1,dist="h",crs=26910) {
  distance <- 804.672
  if(dist=="q"){distance <- 402.336}
  df2 <- st_transform(df_sf1,crs)
  df3 <- st_buffer(df2,dist=distance)
  return(df3)
}


#' Get common simple features (sf) for a gtfsr object
#' 
#' @param gtfs_obj a standard gtfsr object
#' @return gtfs_obj a gtfsr object with a bunch of simple features tables
#' @export
gtfs_as_sf <- function(gtfs_obj) {
  gtfs_obj$sf_stops <- try(gtfs_as_sf_stops(x))
  gtfs_obj$sf_stops_buffer <- try(gtfs_as_sf_stops_buffer(x))
  gtfs_obj$sf_routes <- try(gtfs_as_sf_routes(x))
  gtfs_obj$sf_routes_buffer <- try(gtfs_as_sf_routes_buffer(x))
  return(gtfs_obj)
}


