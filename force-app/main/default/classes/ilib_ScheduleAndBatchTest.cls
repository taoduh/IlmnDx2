@isTest private class ilib_ScheduleAndBatchTest {

    private static String ACCOUNT_INITIAL_NAME = 'Mystery, Inc.';
    private static String ACCOUNT_SCHEDULED_NAME = 'Mystery, Inc - scheduled';
    private static String ACCOUNT_BATCHED_NAME = 'Mystery, Inc - batched';

    @TestSetup
    static void createSampleAccount()
    {
        Account a = new Account();
        a.Name = ACCOUNT_INITIAL_NAME;
        insert a;
    }

    @IsTest
    static void scheduledUpdate()
    {
        SchedulableContext sc = null;
        Database.BatchableContext bc = null;
        JustSchedule scheduleOnlyClass = new JustSchedule();

        Test.startTest();
        scheduleOnlyClass.execute(sc);
        Test.stopTest();

        List<Account> afterJob = [SELECT Id, Name FROM Account];
        System.assertEquals(ACCOUNT_SCHEDULED_NAME, afterJob[0].Name);

        try
        {
            scheduleOnlyClass.start(bc);
            System.assert(false, 'Batchable start should be unsupported');
        }
        catch (Exception e)
        {
            System.assert(true);
        }

        try
        {
            scheduleOnlyClass.execute(bc, null);
            System.assert(false, 'Batchable execute should be unsupported');
        }
        catch (Exception e)
        {
            System.assert(true);
        }

        try
        {
            scheduleOnlyClass.finish(bc);
            System.assert(false, 'Batchable finish should be unsupported');
        }
        catch (Exception e)
        {
            System.assert(true);
        }
    }

    @IsTest
    static void batchedUpdate()
    {
        SchedulableContext sc = null;
        Database.BatchableContext bc = null;
        JustBatch batchOnlyClass = new JustBatch();

        Test.startTest();
        batchOnlyClass.start(bc);
        batchOnlyClass.execute(bc, [SELECT Id, Name FROM Account]);
        batchOnlyClass.finish(bc);
        Test.stopTest();

        List<Account> afterJob = [SELECT Id, Name FROM Account];
        System.assertEquals(ACCOUNT_BATCHED_NAME, afterJob[0].Name);

        try
        {
            batchOnlyClass.execute(sc);
            System.assert(false, 'Schedulable execute should be unsupported');
        }
        catch (Exception e)
        {
            System.assert(true);
        }
    }

    public class JustSchedule extends ilib_ScheduleAndBatch
    {
        public override void execute(SchedulableContext ctx)
        {
            Account a = [SELECT Id, Name FROM Account WHERE Name = :ACCOUNT_INITIAL_NAME];
            a.Name = ACCOUNT_SCHEDULED_NAME;
            update a;
        }
    }

    public class JustBatch extends ilib_ScheduleAndBatch
    {
        // query all objects (accounts) tied to the current territory
        public override Database.QueryLocator start(Database.BatchableContext bc)
        {
            String soql = 'SELECT Id, Name FROM Account WHERE Name = \'' + ACCOUNT_INITIAL_NAME + '\'';
            return Database.getQueryLocator(soql);
        }

        public override void execute(Database.BatchableContext bc, List<sObject> accountList)
        {
            Account a = (Account)accountList[0];
            a.Name = ACCOUNT_BATCHED_NAME;
            update a;
        }

        public override void finish(Database.BatchableContext bc) { }
    }

}