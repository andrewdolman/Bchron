#' Plot output from Bchronology
#' 
#' Plots output from a run of \code{\link{Bchronology}}
#'
#' @param x The object created by \code{\link{Bchronology}}
#' @param dateHeight The height of the dates in the plot. Values in the range 0 to 1 tend to work best.
#' @param chronCol The colour of the chronology uncertainty ribbon to be plotted
#' @param chronBorder The colour of the border of the chronology uncertainty ribbon to be plotted
#' @param alpha The credible interval of the chronology run to be plotted. Defaults to 95 percent
#' @param expandX The amount to expand the horizontal axis in case part are missed off the plot. See \code{\link[ggplot2]{expand_limits}} for details
#' @param expandY The amount to expand the vertical axis in case part are missed off the plot. See \code{\link[ggplot2]{expand_limits}} for details
#' @param nudgeX The amount to move the date labels in the x direction. Can be negative. See \code{\link[ggplot2]{geom_text}} for details
#' @param nudgeY The amount to move the date labels in the y direction. Can be negative. See \code{\link[ggplot2]{geom_text}} for details
#'
#' @details Creates a simple plot of the chronology output. The height of the date densities in the plots can be manipulated via the \code{dateHeight} argument which is represented in the same units as the positions/depths provided. More detailed plots can be created by manipulating the Bchronology object as required.
#' 
#' @seealso For examples see \code{\link{Bchronology}}. Also \code{\link{BchronCalibrate}}, \code{\link{BchronRSL}}, \code{\link{BchronDensity}}, \code{\link{BchronDensityFast}}
#'
#' @export
plot.BchronologyRun <-
function(x,
         dateHeight = 100,
         dateLabels = TRUE,
         dateCol = "darkslategray",
         chronCol = "deepskyblue4",
         chronTransparency = 0.75,
         alpha = 0.95,
         nudgeX = 0,
         nudgeY = 0,
         expandX = if(dateLabels) { c(0.1,0) } else { c(0, 0) },
         expandY = c(0.05, 0)) {

  # x contains the output from a run of the Bchronology function

  # Get chronology ranges
  chronRange = data.frame(
    chronLow = apply(x$thetaPredict,2,'quantile',probs=(1-alpha)/2),
    chronMed = apply(x$thetaPredict,2,'quantile',probs=0.5),
    chronHigh = apply(x$thetaPredict,2,'quantile',probs=1-(1-alpha)/2),
    positions = x$predictPositions
  )
  
  # Swap round so we can use geom_ribbon
  ageGrid = with(chronRange, seq(min(chronLow), max(chronHigh),
                                 length = nrow(chronRange)))
  chronRangeSwap = data.frame(
    Age = ageGrid,
    positionLow = with(chronRange, approx(chronLow, positions, 
                                          xout = ageGrid,
                                          rule = 2)$y),
    Position = with(chronRange, approx(chronMed, positions, 
                                       xout = ageGrid,
                                       rule = 2)$y),
    positionHigh = with(chronRange, approx(chronHigh, positions, 
                                           xout = ageGrid,
                                           rule = 2)$y),
    Date = 'Bchron',
    densities = NA
  )  
  
  # Start extracting ages for plots
  allAges = map_dfr(x$calAges, 
                    `[`, c("ageGrid", "densities"), 
                    .id = c('Date')) %>% 
    rename(Age = ageGrid)
  # scale all the densities to have max value 1
  scaleMax = function(x) return(x/max(x))
  allAges2 = allAges %>% group_by(Date) %>% 
    mutate(densities = scaleMax(densities)) %>% 
    filter(densities > 0.01) %>% 
    ungroup()
  positionLookUp = tibble(Date = names(x$calAges),
                          Position = map_dbl(x$calAges, 'positions'))
  allAges3 = left_join(allAges2, positionLookUp, by = 'Date')
  
  p = allAges3 %>% 
    ggplot(aes(x = Age, 
               y = Position,
               height = densities*dateHeight,
               group = Date)) +
    geom_ridgeline(fill = dateCol, colour = dateCol) +
    scale_y_reverse(breaks = scales::pretty_breaks(n = 10),
                    expand = expandY) +
    theme_bw() +
    scale_x_reverse(breaks = scales::pretty_breaks(n = 10),
                    expand = expandX) + 
    geom_ribbon(data = chronRangeSwap,
                aes(x = Age,
                    ymin = positionLow,
                    ymax = positionHigh),
                colour = chronCol,
                fill = chronCol,
                alpha = chronTransparency) +
    geom_line(data = chronRangeSwap,
              aes(x = Age, y = Position),
              linetype=1)
    
  if(dateLabels) {
    newData = allAges3 %>% 
      group_by(Date) %>% 
      summarise_all('mean') %>% 
      mutate(Position = Position - 0.5*dateHeight,
             Date = str_pad(Date, 
                            width = max(nchar(Date)),
                            side = 'right'))
    p = p + geom_text(data = newData,
                      aes(label=Date),
                      check_overlap = TRUE,
                      vjust = 0.5, 
                      hjust = 'right',
                      nudge_x = nudgeX,
                      nudge_y = nudgeY,
                      size = 2)
  }
  p
}
