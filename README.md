# Gulf of Mexico Infrastructure

This code identifies oil and gas infrastructure in the Gulf of Mexico that is idle and overdue for decommissioning, based on publicly accessible data.
Platforms use idle/overdue definitions from BOEM, BSEE, and GAO Report GAO-24-106229 (OFFSHORE OIL AND GAS). A flowchart accompanying and illustrating the GulfofMexico_Platforms_Final.R code is provided. 
Wells lean on the methodology developed by Agerton et al. (2023), and this script simply joins in additional date information from BOEM data sources to enable animated maps. 

The following files are required inputs for GulfofMexico_Platforms_Final.R:
1) BOEM Platform Structures (mv_platstruc_structures.txt): available at https://www.data.boem.gov/Platform/Files/PlatStrucRawData.zip or https://www.data.boem.gov/Main/RawData.aspx (BOEM Data Center Raw Data).
2) BOEM Lease Area Block (mv_lease_area_block.txt): available at https://www.data.boem.gov/Leasing/Files/LABRawData.zip or https://www.data.boem.gov/Main/RawData.aspx (BOEM Data Center Raw Data).
3) BOEM Production Data (mv_productiondata.txt): available at https://www.data.boem.gov/Production/Files/ProductionRawData.zip or https://www.data.boem.gov/Main/RawData.aspx (BOEM Data Center Raw Data).

The following files are required inputs for GulfofMexico_Wells_Final.R:
  1) Wellbore Cost Data, produced by Ageron et al. (2023) and available at https://dataverse.harvard.edu/file.xhtml?fileId=6961153&version=1.0#. Full citation: Agerton, Mark, 2023, "Replication Data for: Financial Liabilities and Environmental Implications of Unplugged Wells for Gulf of Mexico and Coastal Waters", https://doi.org/10.7910/DVN/EE4SLR.
  2) Borehole (5010.DAT), available at https://www.data.boem.gov/Well/Files/5010.zip or https://www.data.boem.gov/Main/Well.aspx. 
  3) Borehole_fields.csv, provided in Github repo. Exported as .csv from BOEM metadata: https://www.data.boem.gov/Main/HtmlPage.aspx?page=borehole. 
