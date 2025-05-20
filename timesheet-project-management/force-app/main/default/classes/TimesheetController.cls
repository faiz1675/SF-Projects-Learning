public with sharing class TimesheetController {
    @AuraEnabled(cacheable=true)
    public static List<Project__c> getUserProjects() {
        return [SELECT Id, Name FROM Project__c WHERE Owner_lr__c = :UserInfo.getUserId()];
    }

    @AuraEnabled(cacheable=true)
    public static Timesheet__c getSubmittedTimesheet(Date weekStart) {
        List<Timesheet__c> tsList = [
            SELECT Id, Week_Start_Date_d__c, Status_p__c, Approver_lr__c FROM Timesheet__c
            WHERE OwnerId = :UserInfo.getUserId()
            AND Week_Start_Date_d__c = :weekStart
            LIMIT 1
        ];
        return tsList.isEmpty() ? null : tsList[0];
    }

    // @AuraEnabled
    // public static void saveTimesheet(Map<String, Object> payload) {
    //     System.debug('payload:20=>'+payload);
    //     Date weekStart = Date.valueOf((String)payload.get('weekStart'));
    //     System.debug('weekStart:21=>'+weekStart);
    //     Timesheet__c ts = new Timesheet__c(
    //         OwnerId = UserInfo.getUserId(),
    //         Week_Start_Date_d__c = weekStart,
    //         Status_p__c = 'Submitted',
    //         Approver_lr__c = [SELECT Manager_lr__c FROM Project__c WHERE Owner_lr__c = :UserInfo.getUserId() LIMIT 1].Manager_lr__c
    //     );
    //     insert ts;

    //     List<Time_Entry__c> entries = new List<Time_Entry__c>();
    //     Map<String, Object> timeEntries = (Map<String, Object>)payload.get('entries');
    //     System.debug('timeEntries:=31>'+timeEntries);
    //     for (String projectId : timeEntries.keySet()) {
    //         Map<String, Object> entryData = (Map<String, Object>)timeEntries.get(projectId);
    //         System.debug('entryData:=32>'+entryData);
    //         Map<String, Object> dailyHours = (Map<String, Object>)entryData.get('hours');
    //         System.debug('dailyHours:=33>'+dailyHours);
    //         String description = (String)entryData.get('description');
    //         System.debug('description:40=>'+description);
    //         System.debug('daily keyset:'+dailyHours.keySet());
    //         for (String dateStr : dailyHours.keySet()) {
    //             Decimal hrs = Decimal.valueOf(String.valueOf(dailyHours.get(dateStr)));
    //             System.debug('hrs:44=>'+hrs);
    //             if (hrs > 0) {
    //                 entries.add(new Time_Entry__c(
    //                     Timesheet_md__c = ts.Id,
    //                     Project_lr__c = projectId,
    //                     Work_Date_d__c = Date.valueOf(dateStr),
    //                     Hours_n__c = hrs,
    //                     Description_ta__c = description
    //                 ));
    //             }
    //         }
    //     }
    //     System.debug('entries:56=>'+entries);
    //     insert entries;
    // }

    // @AuraEnabled
    // public static void saveTimesheet(String weekStart, Object entries) {
    //     Date newWeekStart = Date.valueOf(weekStart);
    //     System.debug('weekStart:21=>'+newWeekStart);
    //     Timesheet__c ts = new Timesheet__c(
    //         OwnerId = UserInfo.getUserId(),
    //         Week_Start_Date_d__c = newWeekStart,
    //         Status_p__c = 'Submitted',
    //         Approver_lr__c = [SELECT Manager_lr__c FROM Project__c WHERE Owner_lr__c = :UserInfo.getUserId() LIMIT 1].Manager_lr__c
    //     );
    //     insert ts;

    //     List<Time_Entry__c> newEntries = new List<Time_Entry__c>();
    //     Map<String, Object> timeEntries = (Map<String, Object>)entries;
    //     System.debug('timeEntries:=31>'+timeEntries);
    //     for (String projectId : timeEntries.keySet()) {
    //         Map<String, Object> entryData = (Map<String, Object>)timeEntries.get(projectId);
    //         System.debug('entryData:=32>'+entryData);
    //         Map<String, Object> dailyHours = (Map<String, Object>)entryData.get('hours');
    //         System.debug('dailyHours:=33>'+dailyHours);
    //         String description = (String)entryData.get('description');
    //         System.debug('description:40=>'+description);
    //         System.debug('daily keyset:'+dailyHours.keySet());
    //         for (String dateStr : dailyHours.keySet()) {
    //             Decimal hrs = Decimal.valueOf(String.valueOf(dailyHours.get(dateStr)));
    //             System.debug('hrs:44=>'+hrs);
    //             if (hrs > 0) {
    //                 newEntries.add(new Time_Entry__c(
    //                     Timesheet_md__c = ts.Id,
    //                     Project_lr__c = projectId,
    //                     Work_Date_d__c = Date.valueOf(dateStr),
    //                     Hours_n__c = hrs,
    //                     Description_ta__c = description
    //                 ));
    //             }
    //         }
    //     }
    //     System.debug('entries:56=>'+newEntries);
    //     insert newEntries;
    // }

    @AuraEnabled
public static void saveTimesheet(String weekStart, Object entries) {
    Date newWeekStart = Date.valueOf(weekStart);
    System.debug('weekStart:21=>'+newWeekStart);
    Timesheet__c ts = new Timesheet__c(
        OwnerId = UserInfo.getUserId(),
        Week_Start_Date_d__c = newWeekStart,
        Status_p__c = 'Submitted',
        Approver_lr__c = [SELECT Manager_lr__c FROM Project__c WHERE Owner_lr__c = :UserInfo.getUserId() LIMIT 1].Manager_lr__c
    );
    insert ts;

    List<Time_Entry__c> newEntries = new List<Time_Entry__c>();
    
    // First cast to Map<String, Object>
    Map<String, Object> timeEntriesByProject = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(entries));
    System.debug('timeEntriesByProject:=31>'+timeEntriesByProject);
    
    for (String projectId : timeEntriesByProject.keySet()) {
        // Get the project entry which contains description and dates
        Map<String, Object> projectEntry = (Map<String, Object>)timeEntriesByProject.get(projectId);
        System.debug('projectEntry:=32>'+projectEntry);
        
        String description = (String)projectEntry.get('description');
        System.debug('description:40=>'+description);
        
        // Iterate through all fields in projectEntry to find date fields
        for (String fieldName : projectEntry.keySet()) {
            // Skip the description field
            if (fieldName == 'description') continue;
            
            // Check if the field is a date (you might want additional validation here)
            try {
                Date workDate = Date.valueOf(fieldName);
                Decimal hrs = (Decimal)projectEntry.get(fieldName);
                
                System.debug('hrs:44=>'+hrs);
                if (hrs > 0) {
                    newEntries.add(new Time_Entry__c(
                        Timesheet_md__c = ts.Id,
                        Project_lr__c = projectId,
                        Work_Date_d__c = workDate,
                        Hours_n__c = hrs,
                        Description_ta__c = description
                    ));
                }
            } catch (Exception e) {
                // Skip fields that aren't dates
                System.debug('Skipping field '+fieldName+' as it is not a date: '+e.getMessage());
            }
        }
    }
    System.debug('entries:56=>'+newEntries);
    insert newEntries;
}

}
