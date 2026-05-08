public with sharing class FDRDashboardController {

    @AuraEnabled
    public static DashboardData getDashboardData(
        String startDate,
        String endDate,
        String globalArea,
        String region,
        String country
    ) {
        Date startDateVal = String.isNotBlank(startDate)
            ? Date.valueOf(startDate)
            : Date.newInstance(Date.today().year(), 1, 1);
        Date endDateVal = String.isNotBlank(endDate)
            ? Date.valueOf(endDate)
            : Date.newInstance(Date.today().year(), 12, 31);

        String globalAreaFilter = (String.isNotBlank(globalArea) && globalArea != 'All') ? globalArea : null;
        String regionFilter     = (String.isNotBlank(region)     && region     != 'All') ? region     : null;
        String countryFilter    = (String.isNotBlank(country)    && country    != 'All') ? country    : null;

        String soql =
            'SELECT Id, Name, Response_Name__c, Response_Date__c, Country__c, Country_Code__c, ' +
            'FMI_Global_Area__c, FMI_Region__c, Disaster_Type__c, Level__c, ' +
            'Response_Status__c, Is_US_Domestic__c, Grants_Dispersed__c, Grant_Funds_Provided__c ' +
            'FROM FDR_Response__c ' +
            'WHERE Response_Date__c >= :startDateVal ' +
            'AND Response_Date__c <= :endDateVal ' +
            (globalAreaFilter != null ? 'AND FMI_Global_Area__c = :globalAreaFilter ' : '') +
            (regionFilter     != null ? 'AND FMI_Region__c = :regionFilter '          : '') +
            (countryFilter    != null ? 'AND Country__c = :countryFilter '            : '') +
            'ORDER BY Response_Date__c DESC ' +
            'LIMIT 500';

        List<FDR_Response__c> responses = Database.query(soql);

        DashboardData data = new DashboardData();
        data.responses = responses;
        data.totalResponses = responses.size();

        Set<String> countriesSet = new Set<String>();
        Integer activeCount  = 0;
        Integer planningCount = 0;
        Integer usDomesticCount = 0;
        Integer grantsDispersed = 0;
        Decimal grantFunds = 0;

        Map<String, Integer> byDisasterType = new Map<String, Integer>();
        Map<Integer, Integer> byMonthMap    = new Map<Integer, Integer>();

        for (FDR_Response__c r : responses) {
            if (String.isNotBlank(r.Country__c)) countriesSet.add(r.Country__c);
            if (r.Response_Status__c == 'Active')   activeCount++;
            if (r.Response_Status__c == 'Planning') planningCount++;
            if (r.Is_US_Domestic__c)                usDomesticCount++;
            if (r.Grants_Dispersed__c     != null)  grantsDispersed += Integer.valueOf(r.Grants_Dispersed__c);
            if (r.Grant_Funds_Provided__c != null)  grantFunds      += r.Grant_Funds_Provided__c;

            String dt = String.isNotBlank(r.Disaster_Type__c) ? r.Disaster_Type__c : 'Unknown';
            byDisasterType.put(dt, (byDisasterType.containsKey(dt) ? byDisasterType.get(dt) : 0) + 1);

            if (r.Response_Date__c != null) {
                Integer m = r.Response_Date__c.month();
                byMonthMap.put(m, (byMonthMap.containsKey(m) ? byMonthMap.get(m) : 0) + 1);
            }
        }

        data.countriesServed     = countriesSet.size();
        data.activeResponses     = activeCount;
        data.planningResponses   = planningCount;
        data.usDomesticResponses = usDomesticCount;
        data.grantsDispersed     = grantsDispersed;
        data.grantFundsProvided  = grantFunds;

        List<ChartPoint> disasterPoints = new List<ChartPoint>();
        for (String key : byDisasterType.keySet()) {
            ChartPoint p = new ChartPoint();
            p.label = key;
            p.value = byDisasterType.get(key);
            disasterPoints.add(p);
        }
        data.byDisasterType = disasterPoints;

        List<String> monthNames = new List<String>{
            'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
        };
        List<ChartPoint> monthPoints = new List<ChartPoint>();
        for (Integer i = 1; i <= 12; i++) {
            if (byMonthMap.containsKey(i)) {
                ChartPoint p = new ChartPoint();
                p.label = monthNames[i - 1];
                p.value = byMonthMap.get(i);
                monthPoints.add(p);
            }
        }
        data.byMonth = monthPoints;

        data.globalAreaOptions = buildPicklistOptions('FDR_Response__c', 'FMI_Global_Area__c');
        data.regionOptions     = buildPicklistOptions('FDR_Response__c', 'FMI_Region__c');

        return data;
    }

    private static List<String> buildPicklistOptions(String objectName, String fieldName) {
        List<String> values = new List<String>{ 'All' };
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType == null) return values;
        Schema.SObjectField field = objType.getDescribe().fields.getMap().get(fieldName);
        if (field == null) return values;
        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
            if (entry.isActive()) values.add(entry.getValue());
        }
        return values;
    }

    public class DashboardData {
        @AuraEnabled public List<FDR_Response__c> responses;
        @AuraEnabled public Integer totalResponses;
        @AuraEnabled public Integer activeResponses;
        @AuraEnabled public Integer planningResponses;
        @AuraEnabled public Integer countriesServed;
        @AuraEnabled public Integer usDomesticResponses;
        @AuraEnabled public Integer grantsDispersed;
        @AuraEnabled public Decimal grantFundsProvided;
        @AuraEnabled public List<ChartPoint> byDisasterType;
        @AuraEnabled public List<ChartPoint> byMonth;
        @AuraEnabled public List<String> globalAreaOptions;
        @AuraEnabled public List<String> regionOptions;
    }

    public class ChartPoint {
        @AuraEnabled public String  label;
        @AuraEnabled public Integer value;
    }
}
