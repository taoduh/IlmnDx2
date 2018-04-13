@IsTest
private class TestLog {

    @IsTest public static void basicDebugging()
    {
        Log.rootTitle = 'LogUnitTest';

        // simulate entering methodA
        Log.push('MyClass.methodA');

        // simulate entering methodB
        Log.push('MyClass.methodB');
        Log.message('Doing something');
        // do a little DML for the counts
        //TestData.getNewLead();
        insert new Lead(LastName = 'Doo', Company = 'Mystery, Inc', Email = 'scooby@doo.com');
        Log.pop();

        // back to methodA
        Log.message('Doing something more');
        // do a little SOQL for the counts
        List<Lead> leads = [SELECT Id FROM Lead];
        Log.pop();

        String expectedLog = 'LogUnitTest/n1:MyClass.methodA (DML 1,SQL 1)/n  2:MyClass.methodB (DML 1)/n    3:Doing something/n  2:Doing something more';
        System.assertEquals(expectedLog, Log.flush());
    }

    @IsTest public static void interfaceTrigger()
    {
        Log.rootTitle = 'InterfaceTest';

        // simulate entering methodA
        Log.push('MyClass.methodA');

        // simulate entering methodB
        Log.push('MyClass.methodB');
        Log.message('Doing something');
        Log.pop();

        // back to methodA
        Log.message('Doing something more');
        Log.pop();

        System.assert(Log.rootTitle != null);

        Test.startTest();
        Log.emit();
        Test.stopTest();

        // TODO assert (after trigger written)
    }

}