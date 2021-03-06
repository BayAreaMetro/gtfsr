#' Get a dataframe with lubridate dates for the gtfs stop_times_df 
#' 
#' @param stop_times_df a gtfsr$stop_times_df dataframe
#' @export
#' @return an dataframe with arrival and departure time set to lubridate types
#' @examples 
#' stop_times_dt <- stop_times_df_as_dt(some_stops)
#' #plot the histogram of departure times by hour
#' hist(hour(stop_times_dt$departure_time))
stop_times_df_as_dt <- function(stop_times_df) {
  stop_times_dt <- stop_times_df %>% 
    dplyr::mutate(
      departure_time = lubridate::hms(departure_time),
      arrival_time = lubridate::hms(arrival_time)
    )
  return(stop_times_dt)
}

#' Get a `sf` dataframe for gtfs routes 
#' 
#' @param gtfs_obj gtfsr object
#' @param service default "all". pass "weekday" to get routes that have a service id for m,t,w,th,f service. 
#' note that for some operators with infrequent or varying weekday service, the service_ids dataframe may to be reviewed. 
#' @export
#' @return an sf dataframe for gtfs routes with a multilinestring column
#' @examples 
#' routes_sf <- routes_df_as_sf(gtfs_obj)
#' plot(routes_sf[1,])
routes_df_as_sf <- function(gtfs_obj, service="all") {
  shape_route_service_df <- shape_route_service(gtfs_obj)
  if(service=="weekday"){
    shape_route_service_df <- shape_route_service_df[shape_route_service_df$service_id %in% 
                                                       weekday_service_ids(gtfs_obj),]
  }
  
  routes_latlong_df <- dplyr::inner_join(gtfs_obj$shapes_df, 
                                        shape_route_service_df, 
                                        by="shape_id")
  
  lines_df <- dplyr::distinct(routes_latlong_df, route_id)
  
  list_of_line_tibbles <- split(routes_latlong_df, routes_latlong_df$route_id)
  list_of_multilinestrings <- lapply(list_of_line_tibbles, shapes_df_as_sfg)
  
  lines_df$geometry <- sf::st_sfc(list_of_multilinestrings, crs = 4326)
  
  lines_sf <- sf::st_as_sf(lines_df)
  lines_sf$geometry <- st_as_sfc(st_as_text(lines_sf$geometry), crs=4326)
  return(lines_sf)
}

#' Get a `sf` dataframe for gtfs stops 
#' 
#' @param stops_df a gtfsr$stops_df dataframe
#' @export
#' @return an sf dataframe for gtfs routes with a point column
#' @examples 
#' some_stops <- gtfs_obj$stops_df[sample(nrow(gtfs_obj$stops_df), 40),]
#' some_stops_sf <- stops_df_as_sf(some_stops)
#' plot(some_stops_sf)
stops_df_as_sf <- function(stops_df) {
  stops_sf <- sf::st_as_sf(stops_df, 
                            coords = c("stop_lon", "stop_lat"), 
                            crs = 4326)
  return(stops_sf)
}

#' return an sf linestring with lat and long from gtfs
#' @param df dataframe from the gtfsr shapes_df split() on shape_id
#' @noRd
#' @return st_linestring (sfr) object
shape_as_sf_linestring <- function(df) {
  # as suggested by www.github.com/mdsumner

  m <- as.matrix(df[order(df$shape_pt_sequence), 
                    c("shape_pt_lon", "shape_pt_lat")])

  return(sf::st_linestring(m))
}


#' return an sf multilinestring with lat and long from gtfs for a route
#' @param df the shapes_df dataframe from a gtfsr object
#' @export
#' @return a multilinestring simple feature geometry (sfg) for the routes
#' @examples
#' shapes_sfg <- shapes_df_as_sfg(gtfs_obj$shapes_df)
#' plot(shapes_sfg[[1]])
shapes_df_as_sfg <- function(df) {
  # as suggested by www.github.com/mdsumner
  l_dfs <- split(df, df$shape_id)

  l_linestrings <- lapply(l_dfs, 
                          shape_as_sf_linestring)

  return(sf::st_multilinestring(l_linestrings))
}

#' Get stop points simple features (sf) for a gtfsr object
#' 
#' @param gtfs_obj a standard gtfsr object
#' @return gtfs_obj a gtfsr object with point shapes 
#' @export
gtfs_as_sf_stops <- function(gtfs_obj) {
  stops_df1 <- get_stops_for_service(gtfs_obj,weekday_service_ids(gtfs_obj))
  gtfs_obj$stops_sf_weekday <- stops_df_as_sf(stops_df1)
  gtfs_obj$stops_sf <- stops_df_as_sf(gtfs_obj$stops_df)
  return(gtfs_obj)
}

#' Get point buffers simple features (sf) for a gtfsr object
#' 
#' @param gtfs_obj a standard gtfsr object
#' @return gtfs_obj a gtfsr object with point buffer shapes 
#' @export
gtfs_as_sf_stops_buffer <- function(gtfs_obj) {
  gtfs_obj$stops_sf_weekday_1_2_buffer <- planner_buffer(gtfs_obj$stops_sf_weekday)
  gtfs_obj$stops_sf_1_2_mile_buffer <- planner_buffer(gtfs_obj$stops_sf)
  return(gtfs_obj)
}

#' Get route features (sf) for a gtfsr object
#' 
#' @param gtfs_obj a standard gtfsr object
#' @return gtfs_obj a gtfsr object with route shapes 
#' @export
gtfs_as_sf_routes <- function(gtfs_obj) {
  gtfs_obj$routes_sf_weekday <- routes_df_as_sf(gtfs_obj,service="weekday")
  gtfs_obj$routes_sf <- routes_df_as_sf(gtfs_obj)
  return(gtfs_obj)
}

#' Get route buffer features (sf) for a gtfsr object
#' 
#' @param gtfs_obj a standard gtfsr object
#' @return gtfs_obj a gtfsr object with route buffer shapes 
#' @export
gtfs_as_sf_routes_buffer <- function(gtfs_obj) {
  gtfs_obj$routes_sf_weekday_1_4_mile_buffer <- planner_buffer(gtfs_obj$routes_sf_weekday, dist="q")
  gtfs_obj$routes_sf_1_4_mile_buffer <- planner_buffer(gtfs_obj$routes_sf, dist="q")
  return(gtfs_obj)
}


#'Join the shapes, trips and routes tables together - also checks on some potential errors in the data and warns accordingly
#' @param gtfs_obj a gtfs object
#' @param route_ids the routes for which to join the tables together - required, but not sure why this can't just be any/all routes in routes_df
#' @param service_ids - an optional filter for a certain service-default NULL
#' @export
#' @return shapes_routes_service_df - a dataframe in which routes, services, and shape_ids are all joined
#' @examples 
#' df <- shape_route_service(gtfs_obj)
#' #get a summary of the number of shapes and services for a route
#' library(magrittr)
#' library(dplyr)
#' routes_shapes_services <- df %>% 
#'           group_by(route_id) %>% 
#'           summarize(shapes = length(unique(shape_id)), 
#'           services= length(unique(service_id)))
#' summary(routes_shapes_services)
shape_route_service <- function(gtfs_obj, route_ids = NULL, service_ids = NULL) {

  stopifnot(class(gtfs_obj) == 'gtfs',
            !is.null(gtfs_obj$shapes_df),
            !is.null(gtfs_obj$trips_df),
            !is.null(gtfs_obj$routes_df))

  # pull all route_ids if the user doesn't provide any
  if(length(route_ids) == 0) {
    route_ids <- unique(gtfs_obj$routes_df$route_id)
  }

  # check for bad route ids
  bad_route_ids <- route_ids[which(!route_ids %in% gtfs_obj$routes_df$route_id)]
  route_ids <- route_ids[which(route_ids %in% gtfs_obj$routes_df$route_id)]

  # error if all route ids are bad
  if(length(route_ids) == 0) {
    s <- "No provided Route ID(s) were found. Please provide valid Route IDs." %>% sprintf(paste(bad_route_ids, collapse = ", "))
    stop(s)
  }

  # warn if some route ids are omitted
  if(length(bad_route_ids) > 0) {
    s <- "Route ID(s) '%s' not found. Omitted." %>% sprintf(paste(bad_route_ids, collapse = ", "))
    warning(s)
  }

  if(!is.null(service_ids)) {

    # check service ids
    bad_service_ids <- service_ids[which(!service_ids %in% gtfs_obj$trips_df$service_id)]
    service_ids <- service_ids[which(service_ids %in% gtfs_obj$trips_df$service_id)]

    if(length(service_ids) == 0) {
      s <- "No provided Service ID(s) --- '%s' --- were found. Please provide valid Service IDs." %>% sprintf(paste(bad_service_ids, collapse = ", "))
      stop(s)
    }

    if(length(bad_service_ids) > 0) {
      s <- "Service ID(s) '%s' not found. Omitted." %>% sprintf(paste(bad_service_ids, collapse = ", "))
      warning(s)
    }

    shapes_routes_df <- gtfs_obj$trips_df %>%
      dplyr::slice(which(service_id %in% service_ids)) %>%
      dplyr::slice(which(route_id %in% route_ids)) %>%
      dplyr::select(shape_id, route_id, service_id) %>%
      dplyr::filter(!is.na(shape_id)) %>%
      dplyr::distinct(., service_id, shape_id, route_id, .keep_all = TRUE) # want only distinct routes

  } else {

    shapes_routes_df <- gtfs_obj$trips_df %>%
      dplyr::slice(which(route_id %in% route_ids)) %>%
      dplyr::select(shape_id, route_id, service_id) %>%
      dplyr::filter(!is.na(shape_id)) %>%
      dplyr::distinct(., service_id, shape_id, route_id, .keep_all = TRUE) # want only distinct routes

  }

  return(shapes_routes_df)

}
