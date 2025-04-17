# Global Fishing Watch Drifting Longline Data Extraction

This R script extracts and processes drifting longline fishing effort data from the Global Fishing Watch API for a specific region in the Pacific Ocean (175°E to 130°W, 10°N to 35°N) that spans the international date line.

## Features

- Extracts high-resolution monthly fishing data for drifting longlines
- Handles the international date line by using two polygons in the bounding box
- Processes data year by year (from 2012 to 2023)
- Includes functionality for both generating a complete dataset and appending new yearly data
- Standardizes longitude values to 0-360° format
- Filters for specific gear type (drifting longlines)

## Requirements

The script requires these R packages:
- gfwr (Global Fishing Watch R API client)
- lubridate (for date handling)
- sf (for spatial data)
- sfheaders (for spatial data headers)

## Authentication

Requires a Global Fishing Watch API token, which can be obtained from [Global Fishing Watch API Documentation](https://globalfishingwatch.org/our-apis/documentation#introduction).

## Usage

The script offers two main workflows:
1. Generate a complete dataset for a range of years (2012-2023)
2. Append data for a new year to an existing dataset

Data is saved in R data format (.Rdata) with naming convention: `gfw_ll_hi_[start_year]_[end_year].Rdata`

# False Killer Whale Non-US Fishing Effort Assessment

## Overview

This R script estimates interactions between non-U.S. longline fishing vessels and false killer whales (FKW) within the Hawaii pelagic false killer whale assessment area. The analysis combines multiple data sources to quantify fishing effort and estimate potential protected species interactions.

## Data Sources

The script utilizes three primary data sources:
1. **Global Fishing Watch (GFW)** data - High-resolution fishing effort data
2. **Western and Central Pacific Fisheries Commission (WCPFC)** public domain 5°×5° longline data. The _WCPFC_L_PUBLIC_BY_FLAG_MON.CSV_ can be accessed from [WCPFC public domain data](https://www.wcpfc.int/public-domain) 
3. **Inter-American Tropical Tuna Commission (IATTC)** public domain 5°×5° longline data. The _PublicLLTunaBillfishNum.csv_ can be accessed form the [IATTC public domain data](https://www.iattc.org/en-us/Data/Public-domain)

## Methodology

The analysis follows these key steps:

1. **Define Assessment Region**:
   - Creates a bounding box spanning the international date line (175°E to 130°W, 10°N to 35°N)
   - Divides the region into 5°×5° grid cells

2. **Process GFW Data**:
   - Filters data for specific flag states (China, Japan, Korea, Taiwan, USA, Vanuatu)
   - Identifies fishing effort within the FKW management area
   - Calculates the proportion of effort within vs. outside the FKW boundary for each grid cell

3. **Process Regional Fisheries Management Organizations (RFMO) Data**:
   - Standardizes and aligns WCPFC and IATTC data with the assessment grid
   - Aggregates fishing effort (hooks) by flag, year, and area

4. **Combine Data Sources**:
   - Creates a matchup file to relate GFW fishing hours to RFMO reported hooks
   - Calculates the proportion of effort within the FKW area for each flag/year/area combination

5. **Estimate FKW Interactions**:
   - Applies interaction rates derived from:
     - Deep-set longline (DSLL) observer data
     - Shallow-set longline (SSLL) observer data
     - Regional Observer Program (ROP) data
   - Calculates mean, lower 95%, and upper 95% confidence intervals for estimated interactions

## Outputs

The script generates several output files:
- `non_us_fkw_interactions.csv`: Estimated FKW interactions by year and fishing type
- `effort_match.Rdata`: Matchup file of GFW and RFMO effort data
- `agg_data.Rdata`: Aggregated fishing effort data
- `prop_data.Rdata`: Proportion of effort within FKW boundary

The script also creates visualization plots:
- `fkw_inter.png`: Estimated FKW interactions over time
- `us_vs_nonus_effort.png`: Comparison of US vs. non-US fishing effort

## Requirements

This script requires the following R packages:
- `lubridate`: For date handling
- `sf`: For spatial data operations
- `ggplot2`: For generating plots
- `viridis`: For color palettes

## Directory Structure

The script assumes the following directory structure:
```
main_directory/
├── data/
│   ├── gfw_ll_hi_2012_2023.Rdata
│   ├── WCPFC_L_PUBLIC_BY_FLAG_MON_8/...
│   └── PublicLLTunaBillfish/...
├── fkw_boundary/
│   └── pFKW_MgmtArea_line.shp
├── output/
└── plots/
```

## Usage

1. Ensure all required data files are in place
2. Set the `main_dir` variable to point to your repository root
3. Run the script to generate estimates and visualizations

If the GFW data file doesn't exist, the script references a separate `get_gfw.R` script that can be run to generate it.
