# FDR Operations Dashboard — Deployment Guide

Recreates the Foursquare Disaster Relief Power BI dashboard inside Salesforce
Unlimited Edition using a Lightning Web Component, Chart.js, and Leaflet.js.

---

## Prerequisites

| Tool | Install |
|------|---------|
| Salesforce CLI (sf) | https://developer.salesforce.com/tools/salesforcecli |
| Node.js ≥ 18 | https://nodejs.org |
| Git | https://git-scm.com |

---

## Step 1 — Upload Static Resources (Chart.js + Leaflet.js)

These two JavaScript libraries must be uploaded **manually** because they are
binary files that cannot be committed to this repo.

### 1a — Chart.js

1. Download **chart.umd.min.js** from:
   `https://cdn.jsdelivr.net/npm/chart.js/dist/chart.umd.min.js`
2. In Salesforce: **Setup → Static Resources → New**
3. Name: `chartjs`
4. File: upload `chart.umd.min.js`
5. Cache Control: **Public**
6. Save.

### 1b — Leaflet.js

1. Download the Leaflet release zip from https://leafletjs.com/download.html
   (e.g. `leaflet-1.9.4.zip`)
2. Unzip it. You need **leaflet.js** and **leaflet.css** from inside.
3. Create a new zip file containing only those two files at the root:
   ```
   leafletjs.zip
   ├── leaflet.js
   └── leaflet.css
   ```
4. In Salesforce: **Setup → Static Resources → New**
5. Name: `leafletjs`
6. File: upload `leafletjs.zip`
7. Cache Control: **Public**
8. Save.

---

## Step 2 — Authorize Your Org

```bash
sf org login web --alias fdr-prod --instance-url https://thefoursquarechurch2.lightning.force.com
```

---

## Step 3 — Deploy the Metadata

From the root of this repository:

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org fdr-prod \
  --wait 10
```

This deploys:
- `FDR_Response__c` custom object + 12 fields
- `FDRDashboardController` Apex class
- `fdrOperationsDashboard` Lightning Web Component
- `FDR_Operations_Dashboard` Lightning App Page
- `FDR_Dashboard_User` Permission Set

---

## Step 4 — Assign the Permission Set

```bash
sf org assign permset \
  --name FDR_Dashboard_User \
  --target-org fdr-prod
```

Repeat for each user who needs dashboard access, or assign via Setup → Users.

---

## Step 5 — Add the App Page to Navigation

1. Go to **Setup → Lightning App Builder**.
2. Open **FDR Operations Dashboard**.
3. Click **Activate** → choose which apps and profiles can see it.
4. **Save & Activate**.
5. The dashboard now appears as a tab in the Lightning app you selected.

---

## Step 6 — Import Your Data

Enter your disaster response records into the new `FDR Response` object:

**Option A — Manual entry**
Setup → Object Manager → FDR Response → New Record (or use the standard SF UI)

**Option B — Data Import Wizard**
Setup → Data Import Wizard → select `FDR_Response__c` → upload a CSV.

Required CSV columns:

| Column | Example |
|--------|---------|
| Response_Name__c | 202604 Honduras |
| Response_Date__c | 2026-04-15 |
| Country__c | Honduras |
| Country_Code__c | HN |
| FMI_Global_Area__c | Latin America & Caribbean |
| FMI_Region__c | Central America |
| Disaster_Type__c | Flood |
| Level__c | Orange |
| Response_Status__c | Active |
| Is_US_Domestic__c | false |
| Grants_Dispersed__c | 3 |
| Grant_Funds_Provided__c | 18500 |

**Country_Code__c** is the ISO 3166-1 alpha-2 code (US, HN, EG, …).
It is used by the map but is optional — the map falls back to the country name.

---

## Adding Countries to the Map

The LWC includes coordinates for ~35 common countries. To add more, edit
`fdrOperationsDashboard.js` and add entries to the `COUNTRY_COORDS` object:

```js
'Country Name As Stored in SF': [latitude, longitude],
```

Look up coordinates at https://www.latlong.net.

---

## Dashboard Layout (what each section shows)

| Section | Source |
|---------|--------|
| World map | Leaflet.js — one circle marker per unique country, colored by response Level |
| Data table | All FDR_Response__c records matching current filters, newest first |
| Response Summary | Count of Active / Planning records |
| Responses by Disaster Type | Pie chart — count per Disaster_Type__c value |
| KPI cards | Totals: responses, countries, US domestic, grants, funds |
| Responses by Month | Bar chart — count of responses per calendar month |

---

## Filters

| Filter | Controls |
|--------|----------|
| FMI Global Area | Drops down picklist values from the object |
| FMI Region | Drops down picklist values from the object |
| Date From / To | Filters on Response_Date__c |

All filters combine with AND logic. Change any filter and the dashboard
re-queries immediately.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Map doesn't appear | Confirm `leafletjs` Static Resource exists with leaflet.js and leaflet.css at root of zip |
| Charts don't appear | Confirm `chartjs` Static Resource exists and is named exactly `chartjs` |
| "Error loading data" | Check FLS — assign `FDR_Dashboard_User` permission set to the user |
| Deployment fails on object | The custom object may already exist; use `--ignore-conflicts` flag |
| Country not on map | Add the country to `COUNTRY_COORDS` in fdrOperationsDashboard.js |
