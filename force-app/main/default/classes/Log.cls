/**
 * Simple in memory low cpu logging
 *
 * Useful for things like scheduled apex where System.debug would be lost
 **/
public class Log {

    private static LogScope current;
    private static LogScope root;

    private static final Integer DML_IDX = 0;
    private static final Integer SOQL_IDX = 1;
    private static final Map<Integer, String> limitsByIdx = new Map<Integer, String>
    {
        DML_IDX => 'DML',
        SOQL_IDX => 'SQL'
    };

    static
    {
        reset();
    }

    public static String rootTitle {
        get { return root.scope; }
        set { root.scope = value; }
    }

    // Push this named scope onto the log stack
    public static void push(String scope)
    {
        LogScope newScope = new LogScope();
        newScope.scope = scope;
        newScope.limits = new List<Integer>
        {
            Limits.getDMLStatements(),
            Limits.getQueries()
        };
        newScope.parent = Log.current;
        Log.current.logEntries.add(newScope);
        Log.current = newScope;
    }

    // Add the given message to the scope last pushed
    public static void message(String message)
    {
        Log.current.logEntries.add(message);
    }

    // Pop the current scope
    public static void pop()
    {
        Log.current.limits = new List<Integer>
        {
            Limits.getDMLStatements() - Log.current.limits[DML_IDX],
            Limits.getQueries() - Log.current.limits[SOQL_IDX]
        };
        Log.current = Log.current.parent;
    }

    // Flush the log entries and serialize
    public static String flush()
    {
        List<String> logLines = new List<String>();
        logLines.add(Log.root.scope);
        Log.root.flush(logLines, 1);

        reset();

        return String.join(logLines, '/n');
    }

    // Emits the current log state to the Log__e platform event
    public static void emit()
    {
        // Log title is primarly present to allow filtering
        String title = Log.root.scope;
        Integer dml = -1;
        Integer soql = -1;

        if (Log.root.logEntries.size() > 0)
        {
            Object top = Log.root.logEntries[0];
            if (top instanceof LogScope)
            {
                LogScope logScope = (LogScope)top;
                title = logScope.scope;
                dml = logScope.limits[DML_IDX];
                soql = logScope.limits[SOQL_IDX];
            }
            else if (top instanceof String)
            {
                title = (String)top;
            }
        }

        // read config to determine if we publish or if we just debug
        Boolean publishLogs = true;
        cs_Apex_Settings__c apexSettings = cs_Apex_Settings__c.getInstance();
        if (apexSettings != null) publishLogs = apexSettings.Emit_Event_Logs__c;

        if (publishLogs)
        {
            Log__e l = new Log__e(
                    Title__c = title,
                    User_Email__c = UserInfo.getUserEmail(),
                    User_Id__c = UserInfo.getUserId(),
                    DML__c = dml,
                    SOQL__c = soql,
                    Data__c = flush());

            System.debug(l.Data__c);
            // Emit the log data via Platform Events
            EventBus.publish(l);
        }
        else
        {
            System.debug(flush());
        }
    }

    // Resets the log state
    private static void reset()
    {
        root = current = new LogScope();
        DateTime now = DateTime.now();
        current.scope = String.valueOf(now + '.' + now.millisecond());
    }

    // Nested log scopes
    private class LogScope
    {
        public LogScope parent;
        public String scope;
        public List<Integer> limits;
        public List<Object> logEntries = new List<Object>();

        public void flush(List<String> logLines, Integer indent)
        {
            for (Object logEntry : logEntries)
            {
                String spacePrefix = ''.rightPad((indent - 1) * 2);
                if (logEntry instanceof LogScope)
                {
                    LogScope logScope = (LogScope)logEntry;
                    List<String> limitDiffs = new List<String>();
                    for (Integer limitIdx : limitsByIdx.keySet())
                    {
                        Integer limitVariance = logScope.limits[limitIdx];
                        if (limitVariance > 0)
                        {
                            limitDiffs.add(limitsByIdx.get(limitIdx) + ' ' + limitVariance);
                        }
                    }
                    String limits = (limitDiffs.size() > 0
                         ? '(' + String.join(limitDiffs, ',') + ')'
                         : '');
                    logLines.add(spacePrefix + indent + ':' + logScope.scope + ' ' + limits);
                    logScope.flush(logLines, indent + 1);
                }
                else
                {
                    logLines.add(spacePrefix + indent + ':' + logEntry);
                }
            }
        }
    }

}