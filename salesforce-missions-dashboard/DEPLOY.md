# Missions Dashboard — Deployment Guide

A Salesforce LWC dashboard that displays your missionary Contact records on a
world map alongside a filterable table with support-giving totals pulled from
linked Opportunities.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Salesforce CLI (`sf`) | ≥ 2.x |
| Salesforce org | API v59+ |

---

## Step 1 — Verify / create the `Missionary_Status__c` field

The Apex controller reads `Contact.Missionary_Status__c` (Text or Picklist).
If your org uses a different field for missionary status, edit line 35 in
`MissionsDashboardController.cls` and the matching CSS class names in the LWC.

Suggested picklist values:
- `Active`
- `Home Assignment`
- `Candidate`
- `On Hold`

---

## Step 2 — Verify the Contact Record Type

The controller filters by `RecordType.DeveloperName = 'Missionary'`.
To find your org's DeveloperName:

```
Setup → Object Manager → Contact → Record Types
```

If it differs from `Missionary`, edit the constant at the top of
`MissionsDashboardController.cls`:

```java
private static final String MISSIONARY_RT = 'YourDeveloperName';
```

---

## Step 3 — Ensure missionaries have Mailing Address coordinates

The map plots missionaries using `MailingLatitude` / `MailingLongitude`.
These are standard fields on Contact. If they are not populated, use
Salesforce's **Data Integration Rules** (Setup → Data Integration Rules →
"Geocodes for Contact Mailing Address") to auto-populate them.

Missionaries are also grouped by **`Department`** (the Region column). Populate
`Contact.Department` with your region names (e.g. "Africa", "Asia Pacific").

---

## Step 4 — Upload the Leaflet.js static resource

1. Download Leaflet v1.9.4: https://leafletjs.com/download.html
2. Unzip it — you need `leaflet.js` and `leaflet.css` in the root of a ZIP.
3. In Salesforce: **Setup → Static Resources → New**
   - Name: `leafletjs`
   - File: upload the ZIP
   - Cache Control: Public
4. Save.

---

## Step 5 — Authenticate and deploy

```bash
# Authenticate (web login)
sf org login web --alias my-org

# Deploy all metadata
sf project deploy start --source-dir force-app --target-org my-org

# Assign the permission set
sf org assign permset --name Missions_Dashboard_User --target-org my-org
```

---

## Step 6 — Add to an App Page

1. **Setup → App Manager** → Edit or create a Lightning App.
2. Open **App Builder** → drag a new **App Page**.
3. Search for **missionsDashboard** in the component panel and drag it onto the canvas.
4. Save and Activate.

---

## Assumptions at a glance

| What the code assumes | Where to change it |
|-----------------------|--------------------|
| `RecordType.DeveloperName = 'Missionary'` | `MISSIONARY_RT` constant in Apex |
| `Contact.Department` = global region | Change SOQL field if you use a different field |
| `Contact.Missionary_Status__c` = status picklist | Change field API name in SOQL and LWC |
| Donations = `Opportunity.IsWon = true` linked via `OpportunityContactRole` | Change the aggregate SOQL if you use a custom lookup instead |
| Coordinates from `MailingLatitude` / `MailingLongitude` | Enable geocode DI rule or populate manually |
