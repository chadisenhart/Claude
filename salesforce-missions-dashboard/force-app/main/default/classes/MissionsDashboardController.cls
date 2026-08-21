public with sharing class MissionsDashboardController {

    /*
     * Assumptions about your Salesforce org:
     *   - Missionaries are Contact records with RecordType.DeveloperName = 'Missionary'
     *     (change MISSIONARY_RT below if your DeveloperName differs)
     *   - MailingCountry / MailingLatitude / MailingLongitude track the missionary's location
     *   - Department on Contact stores the global region (e.g. "Africa", "Asia Pacific")
     *   - A custom text/picklist field Missionary_Status__c exists on Contact
     *     (values: Active | Home Assignment | Candidate | On Hold)
     *     If the field doesn't exist yet, add it or swap the field reference below.
     *   - Donations are Opportunities (IsWon = true) linked to missionaries via
     *     OpportunityContactRole; the missionary is usually the Primary contact role.
     */

    private static final String MISSIONARY_RT = 'Missionary';

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData(
        String region,
        String statusFilter
    ) {
        String regionVal = (String.isNotBlank(region)       && region       != 'All') ? region       : null;
        String statusVal = (String.isNotBlank(statusFilter) && statusFilter != 'All') ? statusFilter : null;

        // ── 1. Query missionaries ──────────────────────────────────────────────
        String soql =
            'SELECT Id, Name, FirstName, LastName, ' +
            '       MailingCountry, MailingCountryCode, MailingLatitude, MailingLongitude, ' +
            '       MailingCity, Department, Email, MobilePhone, ' +
            '       Missionary_Status__c, Account.Name ' +
            'FROM Contact ' +
            'WHERE RecordType.DeveloperName = :MISSIONARY_RT ' +
            (regionVal != null ? 'AND Department = :regionVal ' : '') +
            (statusVal != null ? 'AND Missionary_Status__c = :statusVal ' : '') +
            'ORDER BY MailingCountry, LastName ' +
            'LIMIT 1000';

        List<Contact> contacts = Database.query(soql);

        // ── 2. Aggregate giving by missionary via OpportunityContactRole ───────
        Set<Id> contactIds = new Map<Id, Contact>(contacts).keySet();
        Map<Id, Decimal> givingByContact = new Map<Id, Decimal>();
        Map<Id, Integer> giftCountByContact = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT ContactId, SUM(Opportunity.Amount) total, COUNT(Id) cnt
            FROM OpportunityContactRole
            WHERE ContactId IN :contactIds
              AND Opportunity.IsWon = true
            GROUP BY ContactId
        ]) {
            Id cid = (Id) ar.get('ContactId');
            givingByContact.put(cid, (Decimal) ar.get('total'));
            giftCountByContact.put(cid, Integer.valueOf(ar.get('cnt')));
        }

        // ── 3. Build wrappers ─────────────────────────────────────────────────
        DashboardData data = new DashboardData();
        Map<String, CountryRollup> countryMap = new Map<String, CountryRollup>();
        Set<String> regions = new Set<String>();
        Map<String, Integer> byStatus = new Map<String, Integer>();
        Decimal totalGiving = 0;

        for (Contact c : contacts) {
            String country = String.isNotBlank(c.MailingCountry) ? c.MailingCountry : 'Unknown';
            String status  = String.isNotBlank(c.Missionary_Status__c) ? c.Missionary_Status__c : 'Active';
            String reg     = String.isNotBlank(c.Department) ? c.Department : 'Unassigned';
            Decimal giving = givingByContact.containsKey(c.Id) ? givingByContact.get(c.Id) : 0;
            Integer gifts  = giftCountByContact.containsKey(c.Id) ? giftCountByContact.get(c.Id) : 0;

            MissionaryRecord mr = new MissionaryRecord();
            mr.id            = c.Id;
            mr.name          = c.Name;
            mr.country       = country;
            mr.countryCode   = c.MailingCountryCode;
            mr.city          = c.MailingCity;
            mr.region        = reg;
            mr.status        = status;
            mr.organization  = c.Account != null ? c.Account.Name : null;
            mr.email         = c.Email;
            mr.phone         = c.MobilePhone;
            mr.totalGiving   = giving;
            mr.giftCount     = gifts;
            mr.latitude      = c.MailingLatitude;
            mr.longitude     = c.MailingLongitude;
            data.missionaries.add(mr);

            totalGiving += giving;
            regions.add(reg);
            byStatus.put(status, (byStatus.containsKey(status) ? byStatus.get(status) : 0) + 1);

            // Country rollup
            if (!countryMap.containsKey(country)) {
                CountryRollup cr = new CountryRollup();
                cr.country     = country;
                cr.countryCode = c.MailingCountryCode;
                cr.latitude    = c.MailingLatitude;
                cr.longitude   = c.MailingLongitude;
                cr.region      = reg;
                countryMap.put(country, cr);
            }
            CountryRollup cr = countryMap.get(country);
            cr.missionaryCount++;
            cr.totalGiving += giving;
            cr.missionaryNames.add(c.Name);
            if (status == 'Active') cr.activeCount++;
            // Use first known coordinates if not yet set
            if (cr.latitude == null && c.MailingLatitude != null) {
                cr.latitude  = c.MailingLatitude;
                cr.longitude = c.MailingLongitude;
            }
        }

        data.countries         = countryMap.values();
        data.totalMissionaries = contacts.size();
        data.totalCountries    = countryMap.size();
        data.totalGiving       = totalGiving;
        data.activeMissionaries = byStatus.containsKey('Active') ? byStatus.get('Active') : 0;
        data.regionOptions     = buildListWithAll(regions);

        List<ChartPoint> statusPoints = new List<ChartPoint>();
        for (String s : byStatus.keySet()) {
            ChartPoint p = new ChartPoint();
            p.label = s;
            p.value = byStatus.get(s);
            statusPoints.add(p);
        }
        data.byStatus = statusPoints;

        return data;
    }

    private static List<String> buildListWithAll(Set<String> vals) {
        List<String> sorted = new List<String>(vals);
        sorted.sort();
        List<String> result = new List<String>{ 'All' };
        result.addAll(sorted);
        return result;
    }

    // ── Inner classes ──────────────────────────────────────────────────────────

    public class DashboardData {
        @AuraEnabled public List<MissionaryRecord> missionaries   = new List<MissionaryRecord>();
        @AuraEnabled public List<CountryRollup>    countries      = new List<CountryRollup>();
        @AuraEnabled public List<ChartPoint>       byStatus       = new List<ChartPoint>();
        @AuraEnabled public List<String>           regionOptions  = new List<String>();
        @AuraEnabled public Integer totalMissionaries  = 0;
        @AuraEnabled public Integer totalCountries     = 0;
        @AuraEnabled public Integer activeMissionaries = 0;
        @AuraEnabled public Decimal totalGiving        = 0;
    }

    public class MissionaryRecord {
        @AuraEnabled public String  id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  country;
        @AuraEnabled public String  countryCode;
        @AuraEnabled public String  city;
        @AuraEnabled public String  region;
        @AuraEnabled public String  status;
        @AuraEnabled public String  organization;
        @AuraEnabled public String  email;
        @AuraEnabled public String  phone;
        @AuraEnabled public Decimal totalGiving = 0;
        @AuraEnabled public Integer giftCount   = 0;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
    }

    public class CountryRollup {
        @AuraEnabled public String        country;
        @AuraEnabled public String        countryCode;
        @AuraEnabled public String        region;
        @AuraEnabled public Decimal       latitude;
        @AuraEnabled public Decimal       longitude;
        @AuraEnabled public List<String>  missionaryNames = new List<String>();
        @AuraEnabled public Integer       missionaryCount = 0;
        @AuraEnabled public Integer       activeCount     = 0;
        @AuraEnabled public Decimal       totalGiving     = 0;
    }

    public class ChartPoint {
        @AuraEnabled public String  label;
        @AuraEnabled public Integer value;
    }
}
