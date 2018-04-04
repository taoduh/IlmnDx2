global with sharing class InterfaceLog {

    public static final String RESULT_SUCCESS = 'Success';
    public static final String RESULT_FAIL = 'Fail';

    global class LogDetails {
        public String interfaceName {get; private set;}
        public Id logRecordId {get; private set;}

        public LogDetails(String interfaceName, Id logRecordId)
        {
            this.interfaceName = interfaceName;
            this.logRecordId = logRecordId;
        }
    }

    private final static Schema.DescribeFieldResult LOG_JSON_MESSAGE_DFR = Schema.SObjectType.Interface_Log__c.fields.Json_Message__c;
    private final static Schema.DescribeFieldResult LOG_RESULT_DETAILS_DFR = Schema.SObjectType.Interface_Log__c.fields.Result_Details__c;


    public static Interface_Log__c instantiateLog(String interfaceName, String message)
    {
        Interface_Log__c logRecord = new Interface_Log__c();
        logRecord.Interface_Name__c = interfaceName;
        logRecord.Json_Message__c = truncateToMaxLength(message, LOG_JSON_MESSAGE_DFR.getLength());

        return logRecord;
    }

    public static LogDetails createLog(String interfaceName, String message)
    {
        Interface_Log__c logRecord = instantiateLog(interfaceName, message);
        insert logRecord;

        return new LogDetails(interfaceName, logRecord.Id);
    }

    public static void finalizeLog(LogDetails l, String result, String resultDetails)
    {
        Interface_Log__c logRecord = new Interface_Log__c(
            Id = l.logRecordId,
            End_Time__c = Datetime.now(),
            Result__c = result,
            Result_Details__c = truncateToMaxLength(resultDetails, LOG_RESULT_DETAILS_DFR.getLength())
        );

        update logRecord;
    }

    public static void finalizeLog(Interface_Log__c logRecord, String result, String resultDetails)
    {
        finalizeLog(logRecord, result, resultDetails, true);
    }

    public static void finalizeLog(Interface_Log__c logRecord, String result, String resultDetails, Boolean insertNow)
    {
        if (logRecord == null) return;

        logRecord.End_Time__c = Datetime.now();
        logRecord.Result__c = result;
        logRecord.Result_Details__c = truncateToMaxLength(resultDetails, LOG_RESULT_DETAILS_DFR.getLength());

        if (insertNow)
            insert logRecord;
    }


    private static String truncateToMaxLength(String s, Integer length)
    {
        return (String.isBlank(s) ? s : s.abbreviate(length));
    }

    public class InterfaceException extends Exception { }

}
