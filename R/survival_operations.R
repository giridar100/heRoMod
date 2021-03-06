#**************************************************************************
#* 
#* Original work Copyright (C) 2017  Jordan Amdahl
#* Modified work Copyright (C) 2017  Antoine Pierucci
#* Modified work Copyright (C) 2017  Matt Wiener
#*
#* This program is free software: you can redistribute it and/or modify
#* it under the terms of the GNU General Public License as published by
#* the Free Software Foundation, either version 3 of the License, or
#* (at your option) any later version.
#*
#* This program is distributed in the hope that it will be useful,
#* but WITHOUT ANY WARRANTY; without even the implied warranty of
#* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#* GNU General Public License for more details.
#*
#* You should have received a copy of the GNU General Public License
#* along with this program.  If not, see <http://www.gnu.org/licenses/>.
#**************************************************************************


#' Project Beyond a Survival Distribution with Another
#' 
#' Project survival from a survival distribution using one
#' or more survival distributions using the specified cut points.
#' 
#' @param ... Survival distributions and cut points in alternating order
#' @param dots Used to work around non-standard evaluation.
#' @param at A vector of times corresponding to the cut
#'   point(s) to be used.
#'   
#' @return A `surv_projection` object.
#' @export
#' 
#' @examples
#' 
#' dist1 <- define_survival(distribution = "exp", rate = .5)
#' dist2 <- define_survival(distribution = "gompertz", rate = .5, shape = 1)
#' join_dist <- join(dist1, 20, dist2)
join <- function(...) {
  dots <- list(...)
  n_args <- length(dots)
  dist_list <- list()
  cut_list <- list()
  if(n_args >= 1) dist_list <- dots[seq(from=1, to=n_args, by = 2)]
  if(n_args >= 2) cut_list <- dots[seq(from=2, to=n_args, by = 2)]
  
  join_(dist_list, cut_list)
}
#' @export
#' @rdname join
project <- function(...) {
  warning("'project() is deprecated, use 'join()' instead.")
  join(...)
}

#' @export
#' @rdname join
project_ <- function(...) {
  warning("'project_() is deprecated, use 'join_()' instead.")
  join_(...)
}

#' @export
#' @rdname join
join_ <- function(dots, at) {
  
  at <- lapply(at, unique)
  at_len <- as.numeric(lapply(at, length))
  at <- unlist(at)
  
  stopifnot(
    length(dots) > 1,
    length(at) == length(dots) - 1,
    all(at_len == 1),
    all(at >= 0),
    all(is.finite(at)),
    !is.unsorted(at, strictly=T)
  )
  
  # Restructure so that first distribution is "alone"
  # and subsequent distributions are put in a list along
  # with their cut point.
  dist_list <- list()
  for (i in seq_along(dots)) {
    if (i==1) {
      dist_list[[i]] <- dots[[i]]
    } else {
      dist_list[[i]] <- list(
        dist = dots[[i]],
        at = at[i-1]
      )
    }
  }
  
  # Use recursion to deal with distributions in pairs
  Reduce(project_fn, dist_list)
}

#' Project Beyond a Survival Distribution with Another
#' (pairwise)
#' 
#' Project survival from a survival distribution using
#' another survival distribution at the specified cutpoint. 
#' Used by project to reduce the list of distributions.
#' 
#' @param dist1 Survival distribution to project from.
#' @param dist2_list A list containing distribution to
#'   project with and the time at which projection begins.
#' @return A `surv_projection` object.
#' @keywords internal
project_fn <- function(dist1, dist2_list) {
  structure(
    list(
      dist1 = dist1,
      dist2 = dist2_list$dist,
      at = dist2_list$at
    ),
    class = "surv_projection"
  )
}

#' Mix Two or More Survival Distributions
#' 
#' Mix a set of survival distributions using the specified
#' weights.
#' 
#' @param ... Survival distributions to be used in the
#'   projection.
#' @param dots Used to work around non-standard evaluation.
#' @param weights A vector of weights used in pooling.
#'   
#' @return A `surv_pooled` object.
#' @export
#' 
#' @examples
#' 
#' dist1 <- define_survival(distribution = "exp", rate = .5)
#' dist2 <- define_survival(distribution = "gompertz", rate = .5, shape = 1)
#' pooled_dist <- mix(dist1, 0.25, dist2, 0.75)
#' 
mix <- function(...) {
  dots <- list(...)
  n_args <- length(dots)
  dist_list <- list()
  weight_list <- list()
  if(n_args >= 1) dist_list <- dots[seq(from=1, to=n_args, by = 2)]
  if(n_args >= 2) weight_list <- dots[seq(from=2, to=n_args, by = 2)]
  
  mix_(dist_list, weight_list)
}

#' @export
#' @rdname mix
mix_ <- function(dots, weights = 1) {
  
  weights <- lapply(weights, unique)
  weights_len <- as.numeric(lapply(weights, length))
  weights <- unlist(weights)
  
  stopifnot(
    length(dots) > 1,
    length(weights) == length(dots),
    all(weights_len == 1),
    all(weights >= 0),
    all(is.finite(weights))
  )
  
  
  structure(
    list(
      dists = dots,
      weights = weights
    ),
    class = "surv_pooled"
  )
}

#' @export
#' @rdname mix
pool <- function(...) {
  warning("'pool() is deprecated, use 'mix()' instead.")
  mix(...)
}

#' @export
#' @rdname mix
pool_ <- function(...) {
  warning("'pool_() is deprecated, use 'mix_()' instead.")
  mix_(...)
}

#' Apply a Hazard Ratio
#' 
#' Proportional reduce or increase the hazard rate of a
#' distribution.
#' 
#' @param dist A survival distribution.
#' @param hr A hazard ratio to be applied.
#' @param log_hr If `TRUE`, the hazard ratio is exponentiated
#'   before being applied.
#'   
#' @return A `surv_ph` object.
#' @export
#' 
#' @examples
#' 
#' dist1 <- define_survival(distribution = "exp", rate = .25)
#' ph_dist <- apply_hr(dist1, 0.5)
#' 
apply_hr <- function(dist, hr, log_hr = FALSE) {
  
  stopifnot(
    length(unique(hr)) == 1,
    is.finite(hr),
    log_hr | hr > 0
  )
  if(length(hr) > 1) hr <- hr[1]
  if(log_hr) hr <- exp(hr)
  if(hr == 1) return(dist)
  if(inherits(dist, "surv_ph")){
    dist$hr <- dist$hr * hr
    if(dist$hr == 1) return(dist$dist)
    return(dist)
  }
  
  structure(
    list(
      dist = dist,
      hr = hr
    ),
    class = "surv_ph"
  )
}

#' Apply an Acceleration Factor
#' 
#' Proportionally increase or reduce the time to event of a
#' survival distribution.
#' 
#' @param dist A survival distribution.
#' @param af An acceleration factor to be applied.
#' @param log_af If `TRUE`, the accleration factor is
#'   exponentiated before being applied.
#'   
#' @return A `surv_aft` object.
#' @export
#' 
#' @examples
#' 
#' dist1 <- define_survival(distribution = "exp", rate = .25)
#' aft_dist <- apply_af(dist1, 1.5)
apply_af <- function(dist, af, log_af = FALSE) {
  
  stopifnot(
    length(unique(af)) == 1,
    is.finite(af),
    log_af | af > 0
  )
  if(length(af) > 1) af <- af[1]
  if(log_af) af <- exp(af)
  if(af == 1) return(dist)
  if(inherits(dist, "surv_aft")){
    dist$af <- dist$af * af
    if(dist$af == 1) return(dist$dist)
    return(dist)
  }
  
  structure(
    list(
      dist = dist,
      af = af
    ),
    class = "surv_aft"
  )
}

#' Apply an Odds Ratio
#' 
#' Proportionally increase or reduce the odds of an event of
#' a survival distribution.
#' 
#' @param dist A survival distribution.
#' @param or An odds ratio to be applied.
#' @param log_or If `TRUE`, the odds ratio is exponentiated
#'   before being applied.
#'   
#' @return A `surv_po` object.
#' @export
#' 
#' @examples
#' 
#' dist1 <- define_survival(distribution = "exp", rate = .25)
#' po_dist <- apply_or(dist1, 1.2)
apply_or = function(dist, or, log_or = FALSE) {
  
  stopifnot(
    length(unique(or)) == 1,
    is.finite(or),
    log_or | or > 0
  )
  
  if(length(or) > 1) or <- or[1]
  if(log_or) or <- exp(or)
  if(or == 1) return(dist)
  if(inherits(dist, "surv_po")){
    dist$or <- dist$or * or
    if(dist$or == 1) return(dist$dist)
    return(dist)
  }
  
  structure(
    list(
      dist = dist,
      or = or
    ),
    class = "surv_po"
  )
}

#' Apply a time shift to a survival distribution
#' 
#' 
#' @param dist A survival distribution.
#' @param shift A time shift to be applied.
#'   
#' @return A `surv_shift` object.
#' 
#' @details A positive shift moves the fit backwards in time.   That is,
#'   a shift of 4 will cause time 5 to be evaluated as time 1, and so on.
#'   If `shift == 0`, `dist` is returned unchanged.
#' @export
#' 
#' @examples
#' 
#' dist1 <- define_survival(distribution = "gamma", rate = 0.25, shape = 3)
#' shift_dist <- apply_shift(dist1, 4)
#' compute_surv(dist1, 1:10)
#' compute_surv(shift_dist, 1:10)
apply_shift = function(dist, shift) {
  stopifnot(
    length(unique(shift)) == 1,
    is.finite(shift)
  )
  if(length(shift) > 1) shift <- shift[1]
  if(shift == 0) return(dist)
  if(inherits(dist, "surv_shift")){
      dist$shift <- dist$shift + shift
      if(dist$shift == 0) return(dist$dist)
      else return(dist)
  }  
  structure(
      list(
        dist = dist,
        shift = shift
      ),
      class = "surv_shift"
    )
}

#' Add Hazards
#' 
#' Get a survival distribution reflecting the independent
#' hazards from two or more survival distributions.
#' 
#' @param ... Survival distributions to be used in the
#'   projection.
#' @param dots Used to work around non-standard evaluation.
#'   
#' @return A `surv_add_haz` object.
#' @export
#' 
#' @examples
#' 
#' dist1 <- define_survival(distribution = "exp", rate = .125)
#' dist2 <- define_survival(distribution = "weibull", shape = 1.2, scale = 50)
#' combined_dist <- add_hazards(dist1, dist2)
#' 
add_hazards <- function(...) {
  
  dots <- list(...)
  
  add_hazards_(dots)
}

#' @export
#' @rdname add_hazards
add_hazards_ <- function(dots) {
  
  structure(
    list(
      dists = dots
    ),
    class = "surv_add_haz"
  )
}

#' Set Covariates of a Survival Distribution
#' 
#' Set the covariate levels of a survival model to be 
#' represented in survival projections.
#' 
#' @param dist a survfit or flexsurvreg object
#' @param ... Covariate values representing the group for 
#'   which survival probabilities will be generated when 
#'   evaluated.
#' @param covariates Used to work around non-standard
#'   evaluation.
#' @param data A an optional data frame representing 
#'   multiple sets of covariate values for which survival 
#'   probabilities will be generated. Can be used to 
#'   generate aggregate survival for a heterogenous set of 
#'   subjects.
#'   
#' @return A `surv_model` object.
#' @export
#' 
#' @examples
#' 
#' fs1 <- flexsurv::flexsurvreg(
#'   survival::Surv(rectime, censrec)~group,
#'   data=flexsurv::bc,
#'   dist = "llogis"
#' )
#' good_model <- set_covariates(fs1, group = "Good")
#' cohort <- data.frame(group=c("Good", "Good", "Medium", "Poor"))
#' mixed_model <- set_covariates(fs1, data = cohort)
#' 
set_covariates <- function(dist, ..., data = NULL) {
  covariates <- data.frame(...)
  
  set_covariates_(dist, covariates, data)
}

#' @export
#' @rdname set_covariates
set_covariates_ <- function(dist, covariates, data = NULL) {
  
  data <- rbind(
    covariates,
    data
  )
  
  structure(
    list(
      dist = dist,
      covar = data
    ),
    class = "surv_model"
  )
}


#' Plot general survival models
#'
#' @param x a survival object of class `surv_aft`, `surv_add_haz`,
#'   `surv_ph`, `surv_po`, `surv_model`, `surv_pooled`, or `surv_projection`.
#' @param times Times at which to evaluate and plot the survival object.
#' @param type either `surv` (the default) or `prob`, depending on whether
#'   you want to plot survival from the start or conditional probabilities.
#' @param join_col,join_pch,join_size graphical parameters for points
#'   marking points at which different survival functions are joined.
#' @param ... additional arguments to pass to `ggplot2` functions.
#'   
#' @details The function currently only highlights join points that are at
#'   the top level; that is, for objects with class `surv_projection`.
#'   
#'   To avoid plotting the join points, set join_size to a negative number.  
#'
#' @return a [ggplot2::ggplot()] object.
#' @export
#'
plot.surv_obj <- function(x, times, type = c("surv", "prob"), 
                          join_col = "red", join_pch = 20,
                          join_size = 3, ...){
  type <- match.arg(type)
  y_ax_label <- c(surv = "survival", prob = "probability")[type]
  res1 <- data.frame(times = times,
                     res = compute_surv(x, times, ..., type = type))
  
  this_plot <- 
    ggplot2::ggplot(res1, ggplot2::aes_string(x = "times", y = "res")) + 
    ggplot2::geom_line() + 
    ggplot2::scale_x_continuous(name = "time") + 
    ggplot2::scale_y_continuous(name = y_ax_label)
  
  if("at" %in% names(x))
    this_plot <- this_plot +
    ggplot2::geom_point(data = filter(res1, times == x$at),
                        ggplot2::aes_string(x = "times", y = "res"),
                        pch = "join_pch", size = "join_size", 
                        col = "join_col")
  
  this_plot
  
}

plot.surv_projection <- plot.surv_obj
plot.surv_ph <- plot.surv_obj
plot.surv_add_haz <- plot.surv_obj
plot.surv_model <- plot.surv_obj
plot.surv_po <- plot.surv_obj
plot.surv_aft <- plot.surv_obj
plot.surv_pooled <- plot.surv_obj
plot.surv_shift <- plot.surv_obj


#' Summarize surv_shift objects
#'
#' @param object a `surv_shift` object 
#' @param summary_type "standard" or "plot" - "standard"
#'   for the usual summary of a `survfit` object,
#'   "plot" for a fuller version
#' @param ... other arguments
#' 
#' @return A summary.
#' @export
#'
summary.surv_shift <- 
  function(object, summary_type = c("plot", "standard"), ...){
    summary_type <- match.arg(summary_type)
    res <- summary(object$dist, ...)
    if(inherits(res, "summary.survfit")){
      if(summary_type == "plot"){
        res <- data.frame(res[c("time", "surv", "upper", "lower")])
        names(res) <- c("time", "est", "lcl", "ucl")
      }
    }
    if(length(res) == 1) res <- res[[1]]
    res$time <- res$time + object$shift
    res
    }
