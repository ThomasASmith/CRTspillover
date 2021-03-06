#' Map of CRT trial area
#'
#' \code{Plot_CRTmap} returns a graphics object created using ggplot2.
#' Cartesian (x,y) coordinates are used. Units are expected to be km.
#'
#' @param trial standard deviation of random displacement from each settlement cluster center
#' @param showLocations logical: determining whether household locations are shown
#' @param showClusterBoundaries logical: determining whether clusters are shown
#' @param showClusterLabels logical: determining whether clusters are numbered
#' @param colourClusters logical: determining whether clusters are coloured
#' @param showArms logical: determining whether the areas assigned to each trial arm are shown
#' @param cpalette colour palette (to use different colours for clusters must be at least as long as the number of clusters, defaults to rainbow())
#' @param maskbuffer radius of buffer drawn around inhabited areas
#' @param labelsize size of labels giving cluster numbers
#' @return graphics object produced by the ggplot2 package
#' @importFrom magrittr %>%
#' @importFrom dplyr distinct group_by summarize
#' @importFrom ggplot2 geom_polygon aes
#' @export
#'
#' @examples
#' #Plot locations only
#' Plot_CRTmap(trial=testArms,showArms=FALSE,showClusterBoundaries=FALSE,
#'            colourClusters=FALSE, maskbuffer=0.5)
#'
#' #Plot clusters in colour
#' Plot_CRTmap(trial=testArms, showArms=FALSE, colourClusters=TRUE, labelsize=2, maskbuffer=0.5)
#'
#' #Plot arms
#' Plot_CRTmap(trial=testArms, maskbuffer=0.5)

Plot_CRTmap = function(
  trial=trial,
  showLocations = TRUE,
  showClusterBoundaries = TRUE,
  showClusterLabels = TRUE,
  colourClusters = TRUE,
  showArms = TRUE,
  cpalette = NULL,
  maskbuffer=1,
  labelsize=2){

# The voronoi functions requires input as a data.frame not a tibble
  trial = as.data.frame(trial)

  # The plotting routines require unique locations
  trial = Aggregate_CRT(trial=trial)

# The plotting routines use (x,y) coordinates
  if(is.null(trial$x)) {
    trial = Convert_LatLong(trial)
  }

# remove any buffer zones
  if(!is.null(trial$buffer)){
    trial = trial[!trial$buffer,]
  }

# Adjust the required plots to exclude those for which there is no data or
# combinations that are too cluttered

  if(is.null(trial$cluster)) {
    trial$cluster=1
    showClusterBoundaries = FALSE
    showClusterLabels = FALSE
  }
  if(is.null(trial$arm)) {
    trial$arm=0
    showArms = FALSE
  }
  if(!showClusterBoundaries){showClusterLabels=FALSE}
  if(showArms){
    showClusterBoundaries = FALSE
    showClusterLabels=FALSE
    # palette defaults to a standard
    if(is.null(cpalette)) {cpalette = c("#F8766D","#00BFC4","#C77CFF","#7CAE00")}
  }
  if(showClusterLabels){showLocations=FALSE}

# the coordinates should all be Cartesian at this point but long and lat appear later (??)
  trial$long = trial$x
  trial$lat = trial$y

  trial1=trial #a copy is required because trial is converted to a SpatialPointsDataFrame
  sp::coordinates(trial) <- c('x', 'y')
  totalClusters <- length(unique(trial$cluster))

  #can give negative values
  sp_dat<-data.frame(trial$cluster,trial$arm)

  vor_desc <- deldir::tile.list(deldir::deldir(trial$x,trial$y))
  # tile.list extracts the polygon data from the deldir computation
  lapply(1:(length(vor_desc)), function(i) {

    # tile.list gets us the points for the polygons but we
    # still have to close them, hence the need for the rbind
    tmp <- cbind(vor_desc[[i]]$x, vor_desc[[i]]$y)
    tmp <- rbind(tmp, tmp[1,]) #add first point to the end of the list
    # now we can make the Polygon(s)
    sp::Polygons(list(sp::Polygon(tmp)), ID=i)

  }) -> vor_polygons

  # match the data & voronoi polys
  rownames(sp_dat) <- sapply(slot(sp::SpatialPolygons(vor_polygons),'polygons'),slot, 'ID')

  vor <- sp::SpatialPolygonsDataFrame(sp::SpatialPolygons(vor_polygons),data=sp_dat)
  vor_df1 <- rgeos::gUnaryUnion(vor, id = vor@data$trial.cluster)

  # Positions of centroids of clusters for locating the labels
  #centroids <-coordinates(vor_df1)
  cc <- data.frame(trial1 %>% group_by(cluster) %>% dplyr::summarize(x = mean(x),y = mean(y),.groups = 'drop'))
  #cc <- data.frame(x = centroids[,1],y = centroids[,2], cluster = c(1:length(centroids[,1])))
  d <-ggplot2::fortify(vor_df1)


  # mask to shade out cluster boundaries in uninhabited areas
  buf1 <- rgeos::gBuffer(trial, width=maskbuffer, byid=TRUE)
  buf2 <- rgeos::gUnaryUnion(buf1)
  buf3 = ggplot2::fortify(buf2)
  vertices = data.frame(long = c(min(d$long),min(d$long),max(d$long),max(d$long)),
                        lat = c(min(d$lat),max(d$lat),max(d$lat),min(d$lat)),
                        id= rep(1,4))
  common_cols <- intersect(colnames(buf3), colnames(vertices))
  gp2 = vertices
  #"make sure that after each hole your x,y coordinates return to the same place.
  #This stops the line buzzing all around and crossing other polygons..."
  for(i in unique(buf3$piece)){
    start=min(which(buf3$piece == i))
    end=max(which(buf3$piece == i))
    gp2=rbind(gp2,buf3[start:end,common_cols])
    gp2=rbind(gp2,vertices[4,common_cols])
  }

  # create a layer for the arms:each cluster separately to avoid overlays with an unwanted polygon due to non-congruent arms
  d2 <- mgcv::uniquecombs(sp_dat)
  d$arm <- d2$trial.arm[as.numeric(d$id)]

  if(is.null(cpalette)) cpalette = sample(rainbow(totalClusters))
  if(totalClusters == 1) cpalette = c('white')

  #  Plotting

  g <- ggplot2::ggplot() + ggplot2::theme_bw()

  # ggplot2 plot each cluster separately to avoid overlays with an unwanted polygon

  for(i in 1:totalClusters){
    # include an invisible graphic of cluster boundaries to constrain the shape/size
    g = g + get_Polygon(polygon_type='limits',i=i,totalClusters=totalClusters,d=d,x=long,y=lat,cpalette=cpalette)
    if(showClusterBoundaries){
      g = g + get_Polygon(polygon_type='clusterboundaries',i=i,totalClusters=totalClusters,d=d,x=long,y=lat,cpalette=cpalette)
    }
    if(colourClusters){
      g = g + get_Polygon(polygon_type='colouredclusters',i=i,totalClusters=totalClusters,d=d,x=long,y=lat,cpalette=cpalette)
    }
    if(showArms){
      g = g + get_Polygon(polygon_type='arms',i=i,totalClusters=totalClusters,d=d,x=long,y=lat,cpalette=cpalette)
    }
  }
  if(showArms){g = g + ggplot2::scale_fill_manual("",values=cpalette,labels=c("Control", "Intervention"))}
  g= g + ggplot2::coord_equal()
  # mask for remote areas
  g= g + ggplot2::geom_polygon(data=gp2,aes(x=long, y=lat), colour=NA, fill="grey")
  if(showClusterLabels){
    g = g + ggplot2::geom_text(data=cc, aes(x= x, y= y,label=cluster),hjust=0.5, vjust=0.5,size=labelsize)
  }
  if(showLocations){
    g = g + ggplot2::geom_point(data=trial1, aes(x=x, y=y),size=0.5)
  }
  g = g + ggplot2::theme(axis.title = ggplot2::element_blank())

return(g)}

##############################################################################
# Create different layers for plotting
get_Polygon = function(polygon_type,i, totalClusters=totalClusters, d=d,x=long,y=lat,cpalette=cpalette){
  if(polygon_type == 'limits'){
    # invisible cluster boundaries to constrain shape
    polygon <- ggplot2::geom_polygon(data=d[as.numeric(d$id)==i,],
                                     aes(x=long, y=lat), colour="white", fill="white")
  } else if(polygon_type == 'clusterboundaries') {
    polygon <- ggplot2::geom_polygon(data=d[as.numeric(d$id)==i,],
                                     aes(x=long, y=lat), colour="gray", fill="white")
  } else if(polygon_type == 'colouredclusters') {
    if(is.null(cpalette)) cpalette = sample(rainbow(totalClusters))
    polygon <- ggplot2::geom_polygon(data=d[as.numeric(d$id)==i,],
                                     aes(x=long, y=lat), colour="gray", fill=cpalette[i])
  } else if(polygon_type == 'arms') {
    polygon <- ggplot2::geom_polygon(data=d[as.numeric(d$id)==i,],
                                     aes(x=long, y=lat, fill=arm), colour="black")
  }
return(polygon)
}
