####################################################
#
#   This script along with the associated data files 
#   Generates estimates of non-U.S. interactions with
#   false killer whale within the Hawai'i pleagic
#   false killer whale assessment area.
#
#####################################################

library(lubridate)
library(sf)
#If gfw_ll_hi_2012_2023.Rdata does not exist the get_gfw.R script can be run to generate it
#read in global fishing watch data and determine which point asare in the fkw managment area
main_dir <- "/Users/robert.ahrens/Documents/GitHub/fkw_non_us_effort/"
#assumes data is in a sub directory data
#assumes shape file is in sub directory fkw_boundary 
#create sub directories for saving output and plots
ifelse(!dir.exists(file.path(main_dir, "plots")), dir.create(file.path(main_dir, "plots")))
ifelse(!dir.exists(file.path(main_dir, "output")), dir.create(file.path(main_dir, "output")))

load(file.path(main_dir, "data", "gfw_ll_hi_2012_2023.Rdata"))

flag_use <- c("CHN", "JPN", "KOR", "TWN", "USA", "VUT")
nflags <- length(flag_use)
syear <- as.numeric(min(year(gfw_ll_hi$date)))
eyear <- as.numeric(max(year(gfw_ll_hi$date)))
nyears <- eyear - syear + 1
xmin <- 175
xmax <- 360 - 130
ymin <- 10
ymax <- 35
ncol <- (xmax - xmin) / 5
nrow <- (ymax - ymin) / 5
nareas <- ncol * nrow
#filet to only flags of interest
gfw_ll_hi <- gfw_ll_hi[which(gfw_ll_hi$flag %in% flag_use),]
#add a 5x5 grid reference starting with 175, 10 as 1 and increasing eastward and northward sequentially with 11 cell per row
#for a 10 column by 5 row matrix for a total of 55 cell 1-55
ccol <- floor((gfw_ll_hi$lon - xmin) / 5) + 1
ccol[which(ccol > ncol)] <- ncol 
#there are some points at 35 that need to be adjusted from row 6 to row 5
crow <- floor((gfw_ll_hi$lat - ymin) / 5) + 1
crow[which(crow > 5)] <- nrow
gfw_ll_hi$ref55 <- (crow - 1) * ncol + ccol
# create a sf point object and see if they are in the fkw boundary
fkw_bdry <- st_read(file.path(main_dir, "fkw_boundary", "pFKW_MgmtArea_line.shp"))
#transform fkw_bdry to lon and lat
fkw_bdry <- st_transform(fkw_bdry, 4326)
#These are polylines not polygons so convert to polygon and shift to 0-360
fkw_bdry_poly <- st_polygonize(st_shift_longitude(fkw_bdry))
pts <- st_as_sf(gfw_ll_hi, coords = c("lon", "lat"), crs = 4326)
tmp <- st_within(pts, fkw_bdry_poly)
#boolean variable for in or out
gfw_ll_hi$in_fkw <- 0
pts$in_fwk <- 0 
ii <- which(lengths(tmp) > 0)
gfw_ll_hi$in_fkw[ii] <- 1
pts$in_fkw[ii] <- 1
gfw_ll_hi$year <- year(gfw_ll_hi$date)
gfw_ll_hi$month <- month(gfw_ll_hi$date)

#save(pts, file = file.path(main_dir, "output", "gfw_sf_pts_fkw.Rdata"))
#save(gfw_ll_hi, file = file.path(main_dir, "output", "gfw_all_fkw.Rdata"))

#aggregate for for total effort in FKW area at different levels
gfw_prop_flag <- aggregate(fishing_hours ~ flag + in_fkw, data = gfw_ll_hi, sum)
gfw_prop_year <- aggregate(fishing_hours ~ flag + year + in_fkw, data = gfw_ll_hi, sum)
gfw_prop_area <- aggregate(fishing_hours ~ flag + year + ref55 + in_fkw, data = gfw_ll_hi, sum)
gfw_prop_area2 <- aggregate(fishing_hours ~ flag + ref55 + in_fkw, data = gfw_ll_hi, sum) #not needed to get estimtes just for plotting 

#get total effort
gfw_area_eff <- aggregate(fishing_hours ~ flag + year + ref55, data = gfw_ll_hi, sum) #not needed to get estimtes just for plotting 
#get numeric values to make pointing in arrays easier
gfw_prop_flag$flag_ind <- match(gfw_prop_flag$flag, flag_use)
gfw_prop_year$flag_ind <- match(gfw_prop_year$flag, flag_use)
gfw_prop_area$flag_ind <- match(gfw_prop_area$flag, flag_use)
gfw_prop_area2$flag_ind <- match(gfw_prop_area2$flag, flag_use) #not needed to get estimtes just for plotting 
gfw_area_eff$flag_ind <- match(gfw_area_eff$flag, flag_use) #not needed to get estimtes just for plotting 

##########################################################################
#put effort into matrix to calculate area proportion for plotting
#not needed to get estimtes just for plotting 
prop_data <- array(dim = c(nareas, nflags, 3))
for(i in seq_along(gfw_prop_area2$flag_ind)){
   cc <- gfw_prop_area2$ref55[i] #area
   flg <- gfw_prop_area2$flag_ind[i] #flag
   fkw <- gfw_prop_area2$in_fkw[i] + 1 #in or out of fkw
   eff <- gfw_prop_area2$fishing_hours[i] #effort
   if(is.na(prop_data[cc, flg, fkw])) prop_data[cc, flg, fkw] <- 0
   prop_data[cc, flg, fkw] <- prop_data[cc, flg, fkw] + eff
}
# proportion of effort in the fkw 
prop_data[, , 3] <- prop_data[, , 2] / (prop_data[, , 2] + prop_data[, , 1])
#deal with NA and NaN 
for (i in 1:nflags){
    for(j in 1:nareas){
        if(is.na(prop_data[j, i, 1]) == FALSE) if (is.na(prop_data[j, i, 2]) == TRUE) prop_data[j, i, 3] <- 0
        if(is.na(prop_data[j, i, 1]) == TRUE) if(is.na(prop_data[j, i, 2]) == FALSE) prop_data[j, i, 3] <- 1
    }
}
save(prop_data, file = file.path(main_dir, "output", "prop_data.Rdata"))
##########################################################################

# this is the finer resolution matrix that will be used to convert the RFMO effort to inside or outside
#array of for storage 1) gfw out_fkw 2) gfw in_fkw 3) gfw prop in 4) gfw total hours fished 5) rfmo total hooks 
agg_data <- array(dim = c(nyrs, nareas, nflags, 5))

for(i in seq_along(gfw_prop_area$flag_ind)){
   yr <- gfw_prop_area$year[i] - (syear - 1)
   cc <- gfw_prop_area$ref55[i]
   flg <- gfw_prop_area$flag_ind[i]
   fkw <- gfw_prop_area$in_fkw[i] + 1
   eff <- gfw_prop_area$fishing_hours[i]
   if(is.na(agg_data[yr, cc, flg, fkw])) agg_data[yr, cc, flg, fkw] <- 0
   if(is.na(agg_data[yr, cc, flg, 4])) agg_data[yr, cc, flg, 4] <- 0
   agg_data[yr, cc, flg, fkw] <- agg_data[yr, cc, flg, fkw] + eff
   agg_data[yr, cc, flg, 4] <- agg_data[yr, cc, flg, 4] + eff
}

# read in WCPFC 5x5 longline data from https://www.wcpfc.int/public-domain
wcpfc_ll <- read.csv(file.path(main_dir, "data", "WCPFC_L_PUBLIC_BY_FLAG_MON_8/WCPFC_L_PUBLIC_BY_FLAG_MON.CSV"))
wcpfc_ll <- wcpfc_ll[, c("yy", "mm", "flag_id", "lat_short", "lon_short", "cwp_grid", "hhooks")]
wcpfc_ll <- wcpfc_ll[which(wcpfc_ll$flag_id %in% c("CN", "JP", "KR", "TW", "US", "VU")),]
wcpfc_ll <- wcpfc_ll[which(wcpfc_ll$yy >= syr & wcpfc_ll$yy <= eyr),]
wcpfc_ll <- wcpfc_ll[which(substr(wcpfc_ll$lat_short, 3, 3) == "N"),]

wcpfc_ll$lat <- as.numeric(substr(wcpfc_ll$lat_short, 1, 2)) + 2.5
wcpfc_ll$lon <- as.numeric(substr(wcpfc_ll$lon_short, 1, 3))
ii <- which(substr(wcpfc_ll$lon_short, 4, 4) == "W")
wcpfc_ll$lon[ii] <- 360 - wcpfc_ll$lon[ii]
wcpfc_ll$lon <- wcpfc_ll$lon + 2.5
# filter to area of interest
wcpfc_ll <- with(wcpfc_ll,wcpfc_ll[which(lat >= ymin & lat < ymax & lon >= xmin & lon < 360 - 150 ),])
ccol <- floor((wcpfc_ll$lon - 2.5 - xmin) / 5) + 1
crow <- floor((wcpfc_ll$lat - 2.5 - ymin) / 5) + 1
wcpfc_ll$ref55 <- (crow - 1) * ncol + ccol
wcpfc_ll$hooks <- wcpfc_ll$hhooks * 100
#aggregate flag year and 5x5 area 
wcpo_area_eff <- aggregate(hooks ~ flag_id + yy + ref55, data = wcpfc_ll, sum)
wcpo_area_eff$flag_ind <- match(wcpo_area_eff$flag_id, c("CN", "JP", "KR", "TW", "US", "VU"))

for(i in seq_along(wcpo_area_eff$flag_ind)){
   yr <- wcpo_area_eff$yy[i] - (syear - 1)
   cc <- wcpo_area_eff$ref55[i]
   flg <- wcpo_area_eff$flag_ind[i]
   eff <- wcpo_area_eff$hooks[i]
   if(is.na(agg_data[yr, cc, flg, 5])) agg_data[yr, cc, flg, 5] <- 0   
   agg_data[yr, cc, flg, 5] <- agg_data[yr, cc, flg, 5] + eff
}

# read in IATTC 5x5 longline data from https://www.iattc.org/en-us/Data/Public-domain
iattc_ll <- read.csv(file.path(main_dir, "data", "PublicLLTunaBillfish/PublicLLTunaBillfishNum.csv"))
iattc_ll <- iattc_ll[, c("Year", "Flag", "LatC5", "LonC5", "Hooks", "ALBn", "BETn", "YFTn", "SWOn")]
iattc_ll <- iattc_ll[which(iattc_ll$Year >= syear & iattc_ll$Year <= eyear), ]
iattc_ll <- iattc_ll[which(iattc_ll$Flag %in% c("CHN", "JPN", "KOR", "TWN", "USA", "VUT")), ]
iattc_ll$lat <- iattc_ll$LatC5
iattc_ll$lon <- 360 + iattc_ll$LonC5
iattc_ll <- iattc_ll[which(iattc_ll$LatC5 >= 10 & iattc_ll$LatC5 <= 35), ]
iattc_ll <- iattc_ll[which(iattc_ll$LonC5 > -150 & iattc_ll$LonC5 < -130), ]
ccol <- floor((iattc_ll$lon - 2.5  - 175) / 5) + 1
crow <- floor((iattc_ll$lat - 2.5 - 10) / 5) + 1
iattc_ll$ref55 <- (crow - 1) * ncol + ccol

#aggregate gfw to flag year and 5x5 area 
epo_area_eff <- aggregate(Hooks ~ Flag + Year + ref55, data = iattc_ll, sum)
epo_area_eff$flag_ind <- match(epo_area_eff$Flag, c("CHN", "JPN", "KOR", "TWN", "USA", "VUT"))

for(i in seq_along(epo_area_eff$flag_ind)){
   yr <- epo_area_eff$Year[i] - (syear - 1)
   cc <- epo_area_eff$ref55[i]
   flg <- epo_area_eff$flag_ind[i]
   eff <- epo_area_eff$Hooks[i]
   if(is.na(agg_data[yr, cc, flg, 5])) agg_data[yr, cc, flg, 5] <- 0  
   agg_data[yr, cc, flg, 5] <- agg_data[yr, cc, flg, 5] + eff
}

save(agg_data, file = file.path(main_dir, "output", "agg_data.Rdata"))

#create matchup file
effort_match <- expand.grid(area = 1:nareas, year = 1:nyrs, flag = 1:nflags)
effort_match$gfw <- NA
effort_match$rfmo <- NA
effort_match$ratio <- NA
effort_match$use <- 1
#ensure that a proportion in the fkw area for each flag and area is used
#there are a few instances given spatial missmatch in gfw and rfmo
#where flag, time, area was not available so flag, year or flag is used. 
for(i in seq_along(effort_match$ratio)){
    fl <- effort_match$flag[i]
    yr <- effort_match$year[i]
    cc <- effort_match$area[i]
    #fill in using flag average 
    ii <- which(gfw_prop_flag$flag_ind == fl & gfw_prop_flag$in_fkw == 0)
    iii <- which(gfw_prop_flag$flag_ind == fl & gfw_prop_flag$in_fkw == 1)
    res <- gfw_prop_flag$fishing_hours[iii]/(gfw_prop_flag$fishing_hours[ii] + gfw_prop_flag$fishing_hours[iii])
    if (res > 0) effort_match$ratio[i] <- res
    #fill in using flag and year 
    ii <- which(gfw_prop_year$flag_ind == fl & gfw_prop_year$year == (yr + (syear - 1)) & gfw_prop_year$in_fkw == 0)
    iii <- which(gfw_prop_year$flag_ind == fl & gfw_prop_year$year == (yr + (syear - 1)) & gfw_prop_year$in_fkw == 1)
    res <- gfw_prop_year$fishing_hours[iii]/(gfw_prop_year$fishing_hours[ii] + gfw_prop_year$fishing_hours[iii])
    if (length(res)>0) if(!is.na(res)) if(res > 0) effort_match$ratio[i]<- res
    #fill in using flag and year and area 
    ii <- which(gfw_prop_area$flag_ind == fl & gfw_prop_area$year == (yr + (syear - 1)) & gfw_prop_area$ref55 == cc & gfw_prop_area$in_fkw == 0)
    iii <- which(gfw_prop_area$flag_ind == fl & gfw_prop_area$year == (yr + (syear - 1)) & gfw_prop_area$ref55 == cc & gfw_prop_area$in_fkw == 1)
    res <- gfw_prop_area$fishing_hours[iii]/(gfw_prop_area$fishing_hours[ii] + gfw_prop_area$fishing_hours[iii])
    if (length(res)>0) if(!is.na(res)) if(res > 0) effort_match$ratio[i]<- res

}

for(i in seq_along(effort_match$flag)){
    fg <- effort_match$flag[i]
    yy <- effort_match$year[i]
    cc <- effort_match$area[i]
    effort_match$gfw[i] <- agg_data[yy, cc, fg, 4]
    effort_match$rfmo[i] <- agg_data[yy, cc, fg, 5]
    #put a zero in if one is positive and the other is NA
    if (is.na(effort_match$gfw[i]) & !is.na(effort_match$rfmo[i]))effort_match$gfw[i] <- 0 
    if (!is.na(effort_match$gfw[i]) & is.na(effort_match$rfmo[i])) effort_match$rfmo[i] <- 0 
    if (is.na(effort_match$gfw[i]) & is.na(effort_match$rfmo[i])) effort_match$use[i] <- 0 

}
effort_match$effort_in <- effort_match$rfmo * effort_match$ratio
effort_match$lat_band <- floor((effort_match$area - 1) / 11) + 1
effort_match$lon_band <- effort_match$area%%11
effort_match$lon_band[which(effort_match$lon_band == 0)] <- 11

save(effort_match, file = file.path(main_dir, "output", "effort_match.Rdata"))

#given the non_us effort caclulate possible interactions. 
effort_yr_fl <- ftable(xtabs(effort_in ~ flag + year, data = effort_match[which(effort_match$flag != 5 & effort_match$use == 1),]))
nonus_effort <- colSums(ftable(xtabs(effort_in ~ flag + year, data = effort_match[which(effort_match$flag != 5 & effort_match$use == 1),])))
us_effort <- colSums(ftable(xtabs(effort_in ~ flag + year, data = effort_match[which(effort_match$flag == 5 & effort_match$use == 1),])))

hps <- read.csv(file = file.path(main_dir, "output", "hooksperset.csv"))
sets <- colSums(effort_yr_fl[,1:12]/unname(as.matrix(hps[,2:13])))

#interactions rates calcuated from SAR data and logbook effort data
ds_int_rate <- c(1.204905e-06, 5.695116e-07, 7.644784e-07, 8.428246e-07, 8.933553e-07, 1.280582e-06, 3.771457e-07, 1.262213e-06, 8.182621e-07, 5.357205e-07)
ds_int_rate_mean <- mean(ds_int_rate)
ds_int_rate_se <- sd(ds_int_rate)
ds_int_rate_high <- ds_int_rate_mean + ds_int_rate_se * qt(0.975,(length(ds_int_rate)-1))
ds_int_rate_low <- ds_int_rate_mean - ds_int_rate_se * qt(0.975,(length(ds_int_rate)-1))

ss_int_rate <-  c(6.739412e-07, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 0.000000e+00, 1.682077e-06, 0.000000e+00, 0.000000e+00, 0.000000e+00)
ss_int_rate_mean <- mean(ss_int_rate)
ss_int_rate_se <- sd(ss_int_rate)
ss_int_rate_high <- ss_int_rate_mean + ss_int_rate_se * qt(0.975,(length(ss_int_rate)-1))
ss_int_rate_low <- ss_int_rate_mean - ss_int_rate_se * qt(0.975,(length(ss_int_rate)-1))

wcp_int_rate_mean <- 0.00070821
wcp_int_rate_high <- 0.0008759439
wcp_int_rate_low <- 0.0005497946
#calcuate interactions
ds_m <-round(nonus_effort * ds_int_rate_mean, 1)
ds_l95 <- round(nonus_effort * ds_int_rate_low, 1)
ds_u95 <- round(nonus_effort * ds_int_rate_high, 1)

ss_m <-round(nonus_effort * ss_int_rate_mean, 1)
ss_l95 <- round(nonus_effort * ss_int_rate_low, 1)
ss_u95 <- round(nonus_effort * ss_int_rate_high, 1)

rop_m <-round(sets * wcp_int_rate_mean, 1)
rop_l95 <- round(sets * wcp_int_rate_low, 1)
rop_u95 <- round(sets * wcp_int_rate_high, 1)
#datafrme of interactions
df <- data.frame("Type" = rep(c("DSLL", "SSLL", "ROP"),each = length(2012:2023)),
  "Year" = rep(2012:2023, 3),
  "Mean" = c(ds_m, ss_m, rop_m),
  "L95" = c(ds_l95, ss_l95, rop_l95),
  "U95" = c(ds_u95, ss_u95, rop_u95))
df$L95[which(df$L95 < 0)] <- 0

write.csv(df, file = file.path(main_dir, "output", "non_us_fkw_interactions.csv") , row.names = FALSE)
#plot of interactions
clrs <- viridis::viridis(3)
png(file = file.path(main_dir, "plots", "fkw_inter.png"), width = 8, height = 5, units = "in", res = 300)
  ggplot(df, aes(x = Year, y = Mean, colour = Type, fill = Type)) +
    geom_point() +
    geom_line() +
    geom_ribbon(aes(ymin = L95, ymax = U95, color = Type), linetype = 1, alpha = 0.1) +
    labs(x = "Year", y = "Estimated FKW interactions", colour = "") +
    scale_colour_manual(values = c("DSLL" = clrs[1], "SSLL"= clrs[2], "ROP" = clrs[3])) +
    scale_fill_manual(values = c("DSLL" = clrs[1], "SSLL"= clrs[2], "ROP" = clrs[3])) +
    theme_light() +
    guides(fill="none")
dev.off()

#plot of effort
tmp <- data.frame("Year" = as.numeric(rep(2012:2023,2)),
  "Type" = rep(c("Non-US","US"), each = 2023 - 2012 + 1),
  "Effort" = as.numeric(c(nonus_effort,us_effort)/1e6))
tmp2 <- data.frame("Year" = 2012:2023,
  "Percent" = nonus_effort/(nonus_effort + us_effort)*100)

png(file = file.path(main_dir, "plots", "us_vs_nonus_effort.png"), width = 8, height = 5, units = "in", res = 300)
  ggplot() + 
      geom_area(aes(x = Year, y = Effort, fill = Type), data = tmp) +
      scale_fill_manual(values = alpha(c("steelblue4","steelblue2"),0.4)) +
      geom_line(aes(x = Year, y = Percent*3), linewidth = 1, data = tmp2) +
      geom_point(aes(x = Year, y = Percent*3), pch = 19, size = 2, color = "black", data = tmp2) +
      scale_y_continuous(sec.axis = sec_axis(~ ./3, name = "% non-US")) +
      labs(x = "Year", y = "Millions of hooks", colour = "") + 
      theme_light()
dev.off()

