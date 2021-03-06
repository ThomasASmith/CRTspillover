% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/Analyse_CRT.R
\name{Analyse_baseline}
\alias{Analyse_baseline}
\title{Simple description and estimation of intra-cluster correction (ICC) from baseline data}
\usage{
Analyse_baseline(
  trial,
  baselineNumerator = "base_num",
  baselineDenominator = "base_denom",
  method = "aovs",
  ci.type = "aov"
)
}
\arguments{
\item{trial}{trial dataframe containing cluster assignments (variable cluster), numerators (num), and denominators (denom)}

\item{baselineNumerator}{name of numerator variable for baseline data (if present)}

\item{baselineDenominator}{name of denominator variable for baseline data (if present)}

\item{method}{method for estimating ICC (uses package 'ICCbin')}

\item{ci.type}{method for estimating confidence intervals for ICC (uses package 'ICCbin')}
}
\value{
list containing calculation of average proportion and output from package 'ICCbin'
}
\description{
Simple description and estimation of intra-cluster correction (ICC) from baseline data
}
