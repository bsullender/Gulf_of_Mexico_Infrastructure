#
# Ben Sullender
# kickstep.approaches@gmail.com
# Gulf of Mexico Infrastructure 
# Identify Platforms Overdue for Decommissioning
# June 10, 2024
#

library(tidyverse)
library(lubridate)
library(sf)

# Read in BOEM data.
platforms <- read.csv("./mv_platstruc_structures.txt") %>%
  mutate(inst.date = mdy(INSTALL_DATE),rem.date = mdy(REMOVAL_DATE),clear.date = mdy(STE_CLRNCE_DATE),area.block = paste0(AREA_CODE,BLOCK_NUMBER) %>% gsub(" ","",.,fixed=T))

#platforms %>% group_by(STRUC_TYPE_CODE) %>% summarize(nobs = n()) %>% dplyr::arrange(desc(nobs),.by_group=TRUE)
#print(paste0(sum(is.na(platforms$inst.date)), " platforms have no install date and will be omitted."))

platforms <- platforms[!is.na(platforms$inst.date),]

not.cleared.platforms <- platforms[is.na(platforms$clear.date),] %>%
  # If a platform was reported removed >1 year ago, but not yet reported cleared, I'm assuming
  #       that the removal wasn't actually complete. If the platform was reported removed within a year, I'm giving benefit of the doubt.
  mutate(rem.gtr.1.yr = ifelse(is.na(rem.date),"Standing",ifelse(c(today()-rem.date)>365,"Standing","Not yet inspected")))
#print(paste0("There are ",nrow(not.cleared.platforms)," platforms not yet reported cleared."))

existingPlatforms <- not.cleared.platforms[not.cleared.platforms$rem.gtr.1.yr == "Standing",]  %>%
  # fix 1 problematic platform
    mutate(area.block = ifelse(area.block=="MP296C","MP296",area.block)) %>%
  # simplify field names
  dplyr::select(area.block,LEASE_NUMBER,LATITUDE,LONGITUDE,inst.date,rem.date,clear.date,
                STRUCTURE_NAME,STRUC_TYPE_CODE,LEASE_NUMBER) %>%
  mutate(area.block.lease = paste0(area.block,"-",LEASE_NUMBER))

nrow(platforms)
remPlat <- platforms[!is.na(platforms$rem.date),]
clrPlat <- platforms[is.na(platforms$clear.date),]
remClrPlat <- remPlat[is.na(remPlat$clear.date),]
range(remClrPlat$rem.date)
head(remClrPlat)
head(remClrPlat)
nrow(remPlat)
nrow(clrPlat)
not.cleared.platforms <- platforms[is.na(platforms$clear.date),]


# now join to lease
lease <- read.csv("./mv_lease_area_block.txt") %>%
  # Create new field in leases that matches id from blocks as well as a unique ID that allows for multi-to-multi join
  mutate(area.block = paste0(AREA_CODE,BLOCK_NUM) %>% gsub(" ","",.,fixed=T), lease.block.ID = paste0(LEASE_NUMBER,"-",area.block),
         eff.date = mdy(LEASE_EFF_DATE), exp.date = mdy(LEASE_EXPIR_DATE)) %>%
  mutate(area.block.lease = paste0(area.block,"-",LEASE_NUMBER))

# Join platforms to leases based on lease number + block number (to clean up many-to-many).
platLeaseJoin <- left_join(existingPlatforms,lease,by=c("area.block.lease"="area.block.lease"))  

platWLeases <- platLeaseJoin[!is.na(platLeaseJoin$LEASE_NUMBER.y),] 
#print(paste0(nrow(platLeaseJoin[is.na(platLeaseJoin$LEASE_NUMBER.y),])," platforms do not have matching leases in the database."))
# This leaves out 173 platforms that refer to a lease that is not in the BOEM database.
#     For these, we'll pull the most recent lease for the block that the platform is in.
platNoLease <- platLeaseJoin[is.na(platLeaseJoin$LEASE_NUMBER.y),c(1:10)] %>% rename(area.block = area.block.x, LEASE_NUMBER = LEASE_NUMBER.x)


# select only most recent leases
# let's filter out the leases that didn't actually go through (cancelled, not issued, and rejected all -> "unused")
validLease <- lease[!lease$LEASE_STATUS_CD %in% c("CANCEL","NO-ISS","REJECT"),]
#print(paste0(c(nrow(lease)-nrow(validLease))," leases not used, ",nrow(validLease)," leases used."))
# however, a descending sort puts NAs at the top, so we'll need to filter those out first.
#       This filtering drops six blocks: MI690, MI695, MI719, MU724, MU793, MU816, all of which have no dates populated and are status = PRIMRY
most.recent.lease <- validLease %>% filter(!is.na(eff.date)) %>% group_by(area.block) %>% 
  dplyr::arrange(desc(eff.date), .by_group=TRUE) %>% 
  filter(row_number()==1) %>% data.frame() %>% 
  mutate(area.block.lease = paste0(area.block,"-",LEASE_NUMBER))

# Now we'll join lease info from blocks to platforms that we can't find a matching lease for.
platNoLeaseJoin <- left_join(platNoLease,most.recent.lease,by=c("area.block"="area.block")) %>% 
  rename(area.block.x = area.block,area.block.lease = area.block.lease.x) %>% dplyr::select(-area.block.lease.y) %>% filter(!is.na(LEASE_EFF_DATE))
# drop extra column so names match
platWLeases <- platWLeases %>% dplyr::select(-area.block.y)

existingPlatWLeaseData <- rbind(platWLeases,platNoLeaseJoin)

# Change field names for easier reference
platWLeasesSimple <- existingPlatWLeaseData %>% mutate(area.block = area.block.x, lease.number = LEASE_NUMBER.x,lease.status = LEASE_STATUS_CD) %>% 
  dplyr::select(area.block,lease.number,LATITUDE,LONGITUDE,inst.date,rem.date,clear.date,STRUCTURE_NAME,STRUC_TYPE_CODE,area.block.lease,lease.status,eff.date,exp.date)

nrow(platWLeasesSimple)

prod.date <- read.csv("./mv_productiondata.txt") %>%
  mutate(prodDate = mdy(paste0(PROD_MONTH,"/01/",PROD_YEAR)),total.prod = sum(LEASE_OIL_PROD,LEASE_GWG_PROD,LEASE_CONDN_PROD,LEASE_OWG_PROD,LEASE_WTR_PROD,LEASE_PROD_COMP))

prod.most.recent <- prod.date %>% group_by(LEASE_NUMBER) %>% dplyr::arrange(desc(prodDate), .by_group=TRUE) %>% filter(row_number()==1) %>% data.frame()


plats.leases.prod <- left_join(platWLeasesSimple,prod.most.recent,by=c("lease.number"="LEASE_NUMBER"))

# now we've got a total of 1551 platforms, with lat/long, with lease data, and with an installation date. Now we can see which of these might be overdue.
final.platforms <- plats.leases.prod %>% mutate(platform.status = ifelse(lease.status %in% c("RELINQ","EXPIR","TERMIN"), 
                                                                         # for inactive leases, if it's been expired over a year, must be decommissioned.
                                                                         ifelse(c(today()-exp.date)>365,"Overdue - lease inactive for >1 year","OK-have more time"),
                                                                         # for active leases, if platform has never produced (ie not in production reports)
                                                                         #          and if it is older than 10 years, it is overdue
                                                                         ifelse(is.na(prodDate),
                                                                                ifelse(c((today()-inst.date)>(365*10)),"Overdue - no production for >10 years","OK - not yet producing"),
                                                                                       # for active leases, if it hasn't produced in over 5 years, it's now idle.
                                                                                       #      An idle platform must be decommissioned within 5 years, so 10 years total. 
                                                                                       ifelse(c((today()-prodDate)>(365*10)),"Overdue - no production for >10 years","OK-producing"))))

                                                                 
                                                                                # or if the platform has never produced, but is active, we'll use the construction date as
                                                                                #     last production date.
                                                                         
final.platforms %>% group_by(platform.status) %>% summarize(nobs = n())
#nas <- final.platforms[is.na(final.platforms$platform.status),]


greenPlat <- final.platforms[final.platforms$platform.status=="OK-have more time",] %>% 
  dplyr::select(-PROD_MONTH,-PROD_YEAR,-LEASE_OIL_PROD,-LEASE_GWG_PROD,-LEASE_CONDN_PROD,-LEASE_OWG_PROD,-LEASE_WTR_PROD,-LEASE_PROD_COMP,-prodDate,-total.prod)

write.csv(greenPlat,"./greenPlat.csv")

overdue.platforms <- final.platforms[final.platforms$platform.status %in% c("Overdue - lease inactive for >1 year","Overdue - no production for >10 years"),] %>% 
  dplyr::select(-PROD_MONTH,-PROD_YEAR,-LEASE_OIL_PROD,-LEASE_GWG_PROD,-LEASE_CONDN_PROD,-LEASE_OWG_PROD,-LEASE_WTR_PROD,-LEASE_PROD_COMP,-prodDate,-total.prod)
op.sf <- overdue.platforms %>% st_as_sf(coords = c("LONGITUDE","LATITUDE"),crs=4326)

write.csv(overdue.platforms,"./overdue.platforms.v1.csv")
