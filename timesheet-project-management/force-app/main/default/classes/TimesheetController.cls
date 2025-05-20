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

    @AuraEnabled
    public static void saveTimesheet(String weekStart, Object entries) {
        try {
            Date weekStartDate = Date.valueOf(weekStart);
            System.debug('Week Start Date: ' + weekStartDate);

            Timesheet__c ts = new Timesheet__c(
                OwnerId = UserInfo.getUserId(),
                Week_Start_Date_d__c = weekStartDate,
                Status_p__c = 'Submitted',
                Approver_lr__c = [SELECT Manager_lr__c FROM Project__c WHERE Owner_lr__c = :UserInfo.getUserId() LIMIT 1].Manager_lr__c
            );
            insert ts;

            Map<String, Object> projectEntries = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(entries));
            System.debug('Project Entries: ' + projectEntries);

            List<Time_Entry__c> timeEntries = new List<Time_Entry__c>();

            for (String projectId : projectEntries.keySet()) {
                Map<String, Object> projectData = (Map<String, Object>) projectEntries.get(projectId);
                String description = (String) projectData.get('description');
                Map<String, Object> dailyHours = (Map<String, Object>) projectData.get('hours');

                System.debug('Project ID: ' + projectId + ', Description: ' + description);
                System.debug('Daily Hours: ' + dailyHours);

                // Process each day's hours
                for (String dateStr : dailyHours.keySet()) {
                    Decimal hours = (Decimal) dailyHours.get(dateStr);
                    if (hours > 0) {
                        timeEntries.add(new Time_Entry__c(
                            Timesheet_md__c = ts.Id,
                            Project_lr__c = projectId,
                            Work_Date_d__c = Date.valueOf(dateStr),
                            Hours_n__c = hours,
                            Description_ta__c = description
                        ));
                    }
                }
            }

            if (!timeEntries.isEmpty()) {
                insert timeEntries;
                System.debug('Successfully inserted ' + timeEntries.size() + ' time entries.');
            }
        } catch (Exception e) {
            System.debug('Error saving timesheet: ' + e.getMessage() + ' at ' + e.getLineNumber());
            throw new AuraHandledException('Error saving timesheet: ' + e.getMessage());
        }
    }

}
