library(gfwr)
library(lubridate)
library(sf)
library(sfheaders)


#Set up bounding box for extraction
#need to use two polygons becasue of the dateline spaning
dat <- data.frame(lon = c(175, 180, 180, 175, 175, -179.999, -130, -130, -179.999, -179.999),
  lat = c(35, 35, 10, 10, 35, 35, 35, 10, 10, 35),
  id = c(1, 1, 1, 1, 1, 2, 2, 2, 2, 2))
bb_poly <- sfheaders::sf_multipolygon(obj = dat, polygon_id = "id", x = "lon", y = "lat")
st_crs(bb_poly) <- 4326

#Get global fishing watch token for API
#https://globalfishingwatch.org/our-apis/documentation#introduction
key <- gfw_auth()
key <- Sys.getenv("GFW_TOKEN")

#set up vectors for start and end dates
#can only extract 1 year at a time
syear <- 2012
eyear <- 2023
years <- syear:eyear
sdate <- paste0(years,"-01-01")
edate <- paste0(years,"-12-31")

#run this loop if generating complete data set
##########################################################################
#save each year in a list object to combine later
gfw <- list()
for(i in 1:length(years)){
  tmp <- get_raster(
    spatial_resolution = 'HIGH',
    temporal_resolution = 'MONTHLY',
    group_by = 'FLAGANDGEARTYPE',
    start_date = sdate[i],
    end_date = edate[i],
    region_source = 'USER_SHAPEFILE',
    region = bb_poly,
    key = key
    )
  tmp <- as.data.frame(tmp[which(tmp$Geartype == "drifting_longlines"),
      c("Time Range", "Lon", "Lat", "Flag", "Apparent Fishing Hours")])
  colnames(tmp) <- c("date", "lon", "lat", "flag", "fishing_hours")
  tmp$date <- ym(tmp$"date")
  #put longitude on 0-360
  ii <- which(gfw$lon < 0)
  tmp$lon[ii] <- 360 + gfw$lon[ii]
  gfw[[i]] <- tmp
}
gfw_ll_hi <- do.call("rbind", gfw)
file_name <- paste0("gfw_ll_hi_", min(year(gfw_ll_hi$date)),"_",max(year(gfw_ll_hi$date)),".Rdata")
dir_path <- "/Users/robert.ahrens/Documents/data/gfw/"
save(gfw_ll_hi, file = paste0(dir_path, file_name))

#########################################################################

#run this if appending file
year <- 2024
sdate <- paste0(year,"-01-01")
edate <- paste0(year,"-12-31")
# get gfw data from the year
tmp <- get_raster(
  spatial_resolution = 'HIGH',
  temporal_resolution = 'MONTHLY',
  group_by = 'FLAGANDGEARTYPE',
  start_date = sdate,
  end_date = edate,
  region_source = 'USER_SHAPEFILE',
  region = bb_poly,
  key = key
  )
#tidy up data  
tmp <- as.data.frame(tmp[which(tmp$Geartype == "drifting_longlines"),
    c("Time Range", "Lon", "Lat", "Flag", "Apparent Fishing Hours")])
colnames(tmp) <- c("date", "lon", "lat", "flag", "fishing_hours")
tmp$date <- ym(tmp$"date")
#put longitude on 0-360
ii <- which(gfw$cell_ll_lon < 0)
tmp$ll_lon[ii] <- 360 + gfw$lon[ii]
#merge with previous file
load("/Users/robert.ahrens/Documents/data/gfw/gfw_dll_hi_2012_2023.Rdata")
gfw_ll_hi <- rbind(gfw_ll_hi, tmp)
#save new file
file_name <- paste0("gfw_ll_hi_", min(year(gfw_dll_hi$date)),"_",max(year(gfw_dll_hi$date)),".Rdata")
dir_path <- "/Users/robert.ahrens/Documents/data/gfw/"
save(gfw_ll_hi, file = paste0(dir_path, file_name))
