% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mtc_utilities.R
\name{get_stop_frequency}
\alias{get_stop_frequency}
\title{Get stop frequency for buses based on mtc headway calculations}
\usage{
get_stop_frequency(g1, start_time, end_time, service = "weekday")
}
\arguments{
\item{g1}{a gtfsr object}

\item{start_time}{the start of the period of interest}

\item{end_time}{the end of the period of interest}

\item{service}{default to "weekday", can also use "weekend" currently}
}
\value{
stops for routes
}
\description{
Get stop frequency for buses based on mtc headway calculations
}
