@isTest
private class TestInterfaceLog {

    @isTest static void instantiateLog()
    {
        String interfaceName = 'Test Interface';
        String someJson = '{ "CompanyName" : "Illumina" }';
        Interface_Log__c log = InterfaceLog.instantiateLog(interfaceName, someJson);

        System.assertEquals(someJson, log.Json_Message__c);
        System.assertEquals(interfaceName, log.Interface_Name__c);
        System.assert(log.Id == null);
    }

    @isTest static void createLog()
    {
        String interfaceName = 'Test Interface';
        String someJson = '{ "CompanyName" : "Illumina" }';
        InterfaceLog.LogDetails logDetails = InterfaceLog.createLog(interfaceName, someJson);

        System.assertEquals(interfaceName, logDetails.interfaceName);
        System.assert(logDetails.logRecordId != null);
    }

    @isTest static void finalizeLog1()
    {
        String interfaceName = 'Test Interface';
        String someJson = '{ "CompanyName" : "Illumina" }';
        String resultDetails = 'Stunning success';
        InterfaceLog.LogDetails logDetails = InterfaceLog.createLog(interfaceName, someJson);

        InterfaceLog.finalizeLog(logDetails, InterfaceLog.RESULT_SUCCESS, resultDetails);

        Interface_Log__c savedLog = [SELECT Result__c, Result_Details__c FROM Interface_Log__c WHERE Id = :logDetails.logRecordId];
        System.assertEquals(InterfaceLog.RESULT_SUCCESS, savedLog.Result__c);
        System.assertEquals(resultDetails, savedLog.Result_Details__c);
    }

    @isTest static void finalizeLog2()
    {
        String interfaceName = 'Test Interface';
        String someJson = '{ "CompanyName" : "Illumina" }';
        String resultDetails = 'Stunning success';
        Interface_Log__c log = InterfaceLog.instantiateLog(interfaceName, someJson);

        InterfaceLog.finalizeLog(log, InterfaceLog.RESULT_SUCCESS, resultDetails);

        Interface_Log__c savedLog = [SELECT Result__c, Result_Details__c FROM Interface_Log__c WHERE Id = :log.Id];
        System.assertEquals(InterfaceLog.RESULT_SUCCESS, savedLog.Result__c);
        System.assertEquals(resultDetails, savedLog.Result_Details__c);
    }

    @isTest static void finalizeLog3()
    {
        String interfaceName = 'Test Interface';
        String someJson = '{ "CompanyName" : "Illumina" }';
        String resultDetails = 'Stunning success';
        Interface_Log__c log = InterfaceLog.instantiateLog(interfaceName, someJson);

        InterfaceLog.finalizeLog(log, InterfaceLog.RESULT_SUCCESS, resultDetails, false);

        System.assertEquals(InterfaceLog.RESULT_SUCCESS, log.Result__c);
        System.assert(log.Id == null);
        System.assertEquals(resultDetails, log.Result_Details__c);
    }

}
