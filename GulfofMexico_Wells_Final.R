#
# Ben Sullender, Kickstep Approaches
# kickstep.approaches@gmail.com
# Gulf of Mexico Infrastructure 
# Populate Wells with Idle Date
# June 10, 2024
#

library(tidyverse)
library(lubridate)

# read in Agerton et al. 2023 data, and filter out wells in the Pacific.
agertonGulf <- read.table("./Wellbore Cost Data.tab",sep="\t",header=T) %>%
  filter(region_id %in% c(1,4,6,7,9,10)) %>% filter(api10 != "00-000-00000")

# API is well identification number, 2 digit state code, 3 digit county code, five digit well code, then 2 digit sidetrack code
# API 10 has 2 digit state code, 3 digit county code, five digit well code, without the sidetrack - so this refers to all wells.
#       since we're focused on main wells, we'll just use the API10. 
agertonAPI10 <- agertonGulf %>% group_by(api10) %>% filter(row_number()==1) %>% data.frame()

# Agerton et al. 2023 flagged unplugged, non-producing wells (aka inactive or temporarily plugged) using these three categories:
#           risk 1 = temp P&A; risk 2 = inactive wells; risk 3 = inactive lease
unpluggedWells <- agertonAPI10[agertonAPI10$risk1==1 | agertonAPI10$risk2==1 | agertonAPI10$risk3==1,] %>% 
  dplyr::select(api10,spud_dt,last_prod,status,latitude,longitude) %>% mutate(api10nodash = paste0(gsub('-','',api10),"00"))


# Now pull in BOEM data for plugging dates 
wellFields <- read.csv("./Borehole_fields.csv") %>%
  mutate(End.Position = c(Start.Position+Item.Length-1))

wells <- read_fwf("./5010.DAT", 
                  fwf_positions(start = wellFields$Start.Position,
                                end = wellFields$End.Position,
                                col_names = wellFields$Column.Alias),show_col_types=F) %>%
  mutate(api = `API Well Number`,api10 = paste0(substr(`API Well Number`,1,10),"00"),
         spuddate = ymd(`Spud Date`),statdate = ymd(`Status Date`),status = `Status Code`,update=`Update Date`,
         lat = `Surface Latitude`,long = `Surface Longitude`) %>%
  dplyr::select(api10,spuddate,statdate,status,update,lat,long) %>%
  # since there are multiple sidetracks/etc. for each well (API10), we'll need to select just the most recent status and 
  #       assign that to all wellholes within the well ID.
  group_by(api10) %>% dplyr::arrange(desc(statdate), .by_group=TRUE) %>% filter(row_number()==1) %>% data.frame()


unpluggedWellsWithDat <- left_join(unpluggedWells,wells,by=c("api10nodash"="api10")) %>%
  mutate(longitude = ifelse(is.na(longitude),long,longitude)) %>% dplyr::select(-lat,-long,-api10nodash) %>%
  mutate(install.yr = year(ymd(spud_dt)),idle.yr = ifelse(is.na(statdate),
                                                          ifelse(is.na(last_prod),"fail",year(ymd(last_prod))),
                                                          ifelse(is.na(last_prod),year(ymd(statdate)),
                                                                 year(max(ymd(statdate),ymd(last_prod)))))) %>%
  filter(!is.na(install.yr))


write.csv(unpluggedWellsWithDat,"./WellsAgertonBOEM.csv")
