
#' Get stop frequency for buses based on mtc headway calculations
#' 
#' @param x a row from a csv describing mtc 511 data sources
#' @return a spatial dataframe for april amendment 1, or an error message
#' @export
process_april_amendment_1 <- function(x) {
  agency_id1 <- x[['PrivateCode']]
  print(agency_id1)
  zip_request_url = paste0('https://api.511.org/transit/datafeeds?api_key=',
                           api_key,
                           '&operator_id=',
                           agency_id1)
  
  g1 <- zip_request_url %>% import_gtfs
  
  time_start1 <- "6:00:00" 
  time_end1 <- "9:59:00"
  
  am_stops <- get_stop_frequency(g1, 
                                 time_start1, 
                                 time_end1, 
                                 service="weekday")
  
  time_start1 <- "15:00:00" 
  time_end1 <- "18:59:00"
  
  pm_stops <- get_stop_frequency(g1, 
                                 time_start1, 
                                 time_end1, 
                                 service="weekday")
  
  
  
  if (has_service(am_stops) & has_service(pm_stops)) {
    stops_am_pm <- inner_join(am_stops,
                              pm_stops, 
                              suffix = c("_am", "_pm"),
                              by=c("agency_id", 
                                   "route_id", 
                                   "direction_id", 
                                   "trip_headsign", 
                                   "stop_id"))
    
    route_headways <- stops_am_pm %>%
      group_by(route_id) %>%
      summarise(headways_am = as.integer(round(median(headway_am),0)), ### we use median here because it is the most representative, 
                headways_pm = as.integer(round(median(headway_pm),0))) ### and more robust against outliers than mean
    
    route_ids <- unique(route_headways$route_id)
    
    qualifying_stops <- get_stops_for_routes(g1,route_ids,weekday_service_ids(g1))
    
    qualifying_stops_sf <- left_join(qualifying_stops,
                                     route_headways, 
                                     by="route_id")
    
    qualifying_stops_sf <- stops_df_as_sf(qualifying_stops_sf)
    qualifying_stops_sf <- qualifying_stops_sf %>% 
      select(stop_id,route_id,stop_name,headways_am,headways_pm)
    qualifying_stops_sf$agency_id <- agency_id1
  }
  return(qualifying_stops_sf)
}




#' Get stop frequency for buses based on mtc headway calculations
#' 
#' @param x a row from a csv describing mtc 511 data sources
#' @return a spatial dataframe for april amendment 2, or an error message
#' @export
process_april_amendment_3 <- function(x) {
  agency_id1 <- x[['PrivateCode']]
  print(agency_id1)
  zip_request_url = paste0('https://api.511.org/transit/datafeeds?api_key=',
                           api_key,
                           '&operator_id=',
                           agency_id1)
  
  g1 <- zip_request_url %>% import_gtfs
  
  time_start1 <- "08:00:00" 
  time_end1 <- "19:59:00"
  
  sat_stops <- get_stop_frequency(g1, 
                                  time_start1, 
                                  time_end1, 
                                  service="saturday")
  
  sun_stops <- get_stop_frequency(g1, 
                                  time_start1, 
                                  time_end1, 
                                  service="sunday")
  
  if (has_service(sat_stops) & has_service(sun_stops)) {
    stops_sat_sun <- inner_join(sat_stops,
                                sun_stops, 
                                suffix = c("_sat", "_sun"),
                                by=c("agency_id", 
                                     "route_id", 
                                     "direction_id", 
                                     "trip_headsign", 
                                     "stop_id"))
    route_headways <- stops_sat_sun %>%
      group_by(route_id) %>%
      summarise(headways_sat = as.integer(round(median(headway_sat),0)), ### we use median here because it is the most representative, 
                headways_sun = as.integer(round(median(headway_sun),0))) ### and more robust against outliers than mean
    
    route_ids <- unique(route_headways$route_id)
    
    qualifying_stops <- get_stops_for_routes(g1,route_ids,saturday_service_ids(g1))
    
    qualifying_stops_sf <- left_join(qualifying_stops,
                                     route_headways, 
                                     by="route_id")
    
    qualifying_stops_sf <- stops_df_as_sf(qualifying_stops_sf)
    
    qualifying_stops_sf <- qualifying_stops_sf %>% select(stop_id,route_id,stop_name,headways_sat,headways_sun)
    qualifying_stops_sf$agency_id <- agency_id1
  }
  return(qualifying_stops_sf)
}

