/**
 * Copyright (c) 2012, FinancialForce.com, inc
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 *   are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * - Neither the name of the FinancialForce.com, inc nor the names of its contributors
 *    may be used to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 *  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 *  OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/

/**
 * Base class aiding in the implemetnation of a Domain Model around SObject collections
 *
 * Domain (software engineering). “a set of common requirements, terminology, and functionality
 * for any software program constructed to solve a problem in that field”,
 * http://en.wikipedia.org/wiki/Domain_(software_engineering)
 *
 * Domain Model, “An object model of the domain that incorporates both behavior and data.”,
 * “At its worst business logic can be very complex. Rules and logic describe many different "
 * "cases and slants of behavior, and it's this complexity that objects were designed to work with...”
 * Martin Fowler, EAA Patterns
 * http://martinfowler.com/eaaCatalog/domainModel.html
 *
 **/
public virtual with sharing class ilib_SObjectDomain implements ilib_ISObjectDomain
{
    /**
     * Provides access to the data represented by this domain class
     **/
    public List<SObject> records { get; private set; }

    /**
     * Derived from the records provided during construction, provides the native describe for the standard or custom object
     **/
    public Schema.DescribeSObjectResult sObjectDescribe { get; private set; }

    /**
     * Exposes the configuration for this domain class instance
     **/
    public Configuration configuration { get; private set; }

    /**
     * Useful during unit testign to assert at a more granular and robust level for errors raised during the various trigger events
     **/
    public static ErrorFactory errors { get; private set; }

    /**
     * Useful during unit testing to access mock support for database inserts and udpates (testing without DML)
     **/
    public static TestFactory test { get; private set; }

    /**
     * Retains instances of domain classes implementing trigger stateful
     **/
    private static Map<Type, List<ilib_SObjectDomain>> triggerStateByClass;

    /**
     * Retains the trigger tracking configuraiton used for each domain
     **/
    private static Map<Type, TriggerEvent> triggerEventByClass;

    static
    {
        errors = new ErrorFactory();
        test = new TestFactory();
        triggerStateByClass = new Map<Type, List<ilib_SObjectDomain>>();
        triggerEventByClass = new Map<Type, TriggerEvent>();
    }

    /**
     * Constructs the domain class with the data on which to apply the behaviour implemented within
     *
     * @param sObjectList A concreate list (e.g. List<Account> vs List<SObject>) of records
     **/
    public ilib_SObjectDomain(List<SObject> sObjectList)
    {
        this(sObjectList, sObjectList.getSObjectType());
    }

    /**
     * Constructs the domain class with the data and type on which to apply the behaviour implemented within
     *
     * @param sObjectList A list (e.g. List<Opportunity>, List<Account>, etc.) of records
     * @param sObjectType The Schema.SObjectType of the records contained in the list
     *
     * @remark Will support List<SObject> but all records in the list will be assumed to be of
     *       the type specified in sObjectType
     **/
    public ilib_SObjectDomain(List<SObject> sObjectList, SObjectType sObjectType)
    {
        // Ensure the domain class has its own copy of the data
        records = sObjectList.clone();
        // Capture SObjectType describe for this domain class
        sObjectDescribe = sObjectType.getDescribe();
        // Configure the Domain object instance
        configuration = new Configuration();
    }

    /**
     * Override this to apply defaults to the records, this is called by the handleBeforeInsert method
     **/
    public virtual void onApplyDefaults() { }

    /**
     * Override this to apply general validation to be performed during insert or update, called by the handleAfterInsert and handleAfterUpdate methods
     **/
    public virtual void onValidate() {  }

    /**
     * Override this to apply validation to be performed during insert, called by the handleAfterUpdate method
     **/
    public virtual void onValidate(Map<Id, SObject> existingRecords) { }

    /**
     * Override this to perform processing during the before insert phase, this is called by the handleBeforeInsert method
     **/
    public virtual void onBeforeInsert() { }

    /**
     * Override this to perform processing during the before update phase, this is called by the handleBeforeUpdate method
     **/
    public virtual void onBeforeUpdate(Map<Id, SObject> existingRecords) { }

    /**
     * Override this to perform processing during the before delete phase, this is called by the handleBeforeDelete method
     **/
    public virtual void onBeforeDelete() { }

    /**
     * Override this to perform processing during the after insert phase, this is called by the handleAfterInsert method
     **/
    public virtual void onAfterInsert() { }

    /**
     * Override this to perform processing during the after update phase, this is called by the handleAfterUpdate method
     **/
    public virtual void onAfterUpdate(Map<Id, SObject> existingRecords) { }

    /**
     * Override this to perform processing during the after delete phase, this is called by the handleAfterDelete method
     **/
    public virtual void onAfterDelete() { }

    /**
     * Override this to perform processing during the after undelete phase, this is called by the handleAfterDelete method
     **/
    public virtual void onAfterUndelete() { }

    /**
     * Base handler for the Apex Trigger event Before Insert, calls the onApplyDefaults method, followed by onBeforeInsert
     **/
    public virtual void handleBeforeInsert()
    {
        onApplyDefaults();
        onBeforeInsert();
    }

    /**
     * Base handler for the Apex Trigger event Before Update, calls the onBeforeUpdate method
     **/
    public virtual void handleBeforeUpdate(Map<Id, SObject> existingRecords)
    {
        onBeforeUpdate(existingRecords);
    }

    /**
     * Base handler for the Apex Trigger event Before Delete, calls the onBeforeDelete method
     **/
    public virtual void handleBeforeDelete()
    {
        onBeforeDelete();
    }

    /**
     * Base handler for the Apex Trigger event After Insert, checks object security and calls the onValidate and onAfterInsert methods
     *
     * @throws DomainException if the current user context is not able to create records
     **/
    public virtual void handleAfterInsert()
    {
        if (configuration.enforcingTriggerCRUDSecurity && !sObjectDescribe.isCreateable())
            throw new DomainException('Permission to create an ' + sObjectDescribe.getName() + ' denied.');

        onValidate();
        onAfterInsert();
    }

    /**
     * Base handler for the Apex Trigger event After Update, checks object security and calls the onValidate, onValidate(Map<Id, SObject>) and onAfterUpdate methods
     *
     * @throws DomainException if the current user context is not able to update records
     **/
    public virtual void handleAfterUpdate(Map<Id, SObject> existingRecords)
    {
        if (configuration.enforcingTriggerCRUDSecurity && !sObjectDescribe.isUpdateable())
            throw new DomainException('Permission to udpate an ' + sObjectDescribe.getName() + ' denied.');

        if (configuration.oldOnUpdateValidateBehaviour)
            onValidate();
        onValidate(existingRecords);
        onAfterUpdate(existingRecords);
    }

    /**
     * Base handler for the Apex Trigger event After Delete, checks object security and calls the onAfterDelete method
     *
     * @throws DomainException if the current user context is not able to delete records
     **/
    public virtual void handleAfterDelete()
    {
        if (configuration.enforcingTriggerCRUDSecurity && !sObjectDescribe.isDeletable())
            throw new DomainException('Permission to delete an ' + sObjectDescribe.getName() + ' denied.');

        onAfterDelete();
    }

    /**
     * Base handler for the Apex Trigger event After Undelete, checks object security and calls the onAfterUndelete method
     *
     * @throws DomainException if the current user context is not able to delete records
     **/
    public virtual void handleAfterUndelete()
    {
        if (configuration.enforcingTriggerCRUDSecurity && !sObjectDescribe.isCreateable())
            throw new DomainException('Permission to create an ' + sObjectDescribe.getName() + ' denied.');

        onAfterUndelete();
    }

    /**
     * Returns the SObjectType this Domain class represents
     **/
    public SObjectType getSObjectType()
    {
        return sObjectDescribe.getSObjectType();
    }

    /**
     * Returns the SObjectType this Domain class represents
     **/
    public SObjectType sObjectType()
    {
        return getSObjectType();
    }

    /**
     * Alternative to the Records property, provided to support mocking of Domain classes
     **/
    public List<SObject> getRecords()
    {
        return records;
    }

    /**
     * Interface used to aid the triggerHandler in constructing instances of Domain classes
     **/
    public interface IConstructable
    {
        ilib_SObjectDomain construct(List<SObject> sObjectList);
    }

    /**
     * Interface used to aid the triggerHandler in constructing instances of Domain classes
     **/
    public interface IConstructable2 extends IConstructable
    {
        ilib_SObjectDomain construct(List<SObject> sObjectList, SObjectType sObjectType);
    }

    /**
     * For Domain classes implementing the ITriggerStateful interface returns the instance
     *   of the domain class being shared between trigger invocations, returns null if
     *   the Domain class trigger has not yet fired or the given domain class does not implement
     *   the ITriggerStateful interface. Note this method is sensitive to recursion, meaning
     *   it will return the applicable domain instance for the level of recursion
     **/
    public static ilib_SObjectDomain getTriggerInstance(Type domainClass)
    {
        List<ilib_SObjectDomain> domains = triggerStateByClass.get(domainClass);
        if (domains == null || domains.size() == 0)
            return null;
        return domains[domains.size() - 1];
    }

    /**
     * Method constructs the given Domain class with the current Trigger context
     * before calling the applicable override methods such as beforeInsert, beforeUpdate etc.
     **/
    public static void triggerHandler(Type domainClass)
    {
        // Process the trigger context
        if (System.Test.isRunningTest() && test.database.hasRecords())
        {
            // If in test context and records in the mock database delegate initially to the mock database trigger handler
            test.database.testTriggerHandler(domainClass);
        }
        else
        {
            // Process the runtime Apex Trigger context
            triggerHandler(domainClass,
                Trigger.isBefore,
                Trigger.isAfter,
                Trigger.isInsert,
                Trigger.isUpdate,
                Trigger.isDelete,
                Trigger.isUnDelete,
                Trigger.new,
                Trigger.oldMap);
        }
    }

    /**
     * Calls the applicable override methods such as beforeInsert, beforeUpdate etc. based on a Trigger context
     **/
    private static void triggerHandler(Type domainClass, Boolean isBefore, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete, List<SObject> newRecords, Map<Id, SObject> oldRecordsMap)
    {
        // After phase of trigger will reuse prior instance of domain class if ITriggerStateful implemented
        ilib_SObjectDomain domainObject = isBefore ? null : popTriggerInstance(domainClass, isDelete ? oldRecordsMap.values() : newRecords);
        if (domainObject == null)
        {
            // Construct the domain class constructor class
            String domainClassName = domainClass.getName();

             // if the table ends in 2 (e.g. Product2), hold on to that for later
            String lastChar = domainClassName.substring(domainClassName.length() - 1);
            String numericTail = '';
            if (lastChar.isNumeric())
            {
                numericTail = lastChar;
                domainClassName = domainClassName.substring(0, domainClassName.length() - 1);
            }

            if (domainClassName != 'ilib_SObjectDomain') // exception for this class
            {
                // remove underscores and custom object endings
                domainClassName = domainClassName.replace('__c',''); // custom table
                domainClassName = domainClassName.replace('__e',''); // custom event
                domainClassName = domainClassName.replace('_','');

                // make class name plural
                if (domainClassName.substring(domainClassName.length() - 1) == 'y')
                    domainClassName = domainClassName.substring(0, domainClassName.length() - 1) + 'ies';
                else if (domainClassName.substring(domainClassName.length() - 1) == 's')
                {
                    // assuming already plural, leave it
                    // a standard object that ends in 's' would break this
                }
                else
                    domainClassName = domainClassName + 's';

                // drop the numeric tail back on
                domainClassName = domainClassName + numericTail;
            }

            // finally, for test methods - put the _ back in ilib_SObjectDomain for subclasses
            if (domainClassName.startsWith('ilibSObjectDomain'))
                domainClassName = 'ilib_SObjectDomain' + domainClassName.substring(17);

            System.debug('ILMN: will create a trigger handler named ' + domainClassName + ' for the object named ' + domainClass.getName());           

            Type constructableClass = domainClassName.endsWith('Constructors') ? Type.forName(domainClassName) : Type.forName(domainClassName+'.Constructor');
            IConstructable domainConstructor = (IConstructable) constructableClass.newInstance();

            // Construct the domain class with the approprite record set
            if (isInsert) domainObject = domainConstructor.construct(newRecords);
            else if (isUpdate) domainObject = domainConstructor.construct(newRecords);
            else if (isDelete) domainObject = domainConstructor.construct(oldRecordsMap.values());
            else if (isUndelete) domainObject = domainConstructor.construct(newRecords);

            // Should this instance be reused on the next trigger invocation?
            if (domainObject.configuration.triggerStateEnabled)
                // Push this instance onto the stack to be popped during the after phase
                pushTriggerInstance(domainClass, domainObject);
        }

        // has this event been disabled?
        if (!getTriggerEvent(domainClass).isEnabled(isBefore, isAfter, isInsert, isUpdate, isDelete, isUndelete))
            return;

        // Invoke the applicable handler
        if (isBefore)
        {
            if (isInsert) domainObject.handleBeforeInsert();
            else if (isUpdate) domainObject.handleBeforeUpdate(oldRecordsMap);
            else if (isDelete) domainObject.handleBeforeDelete();
        }
        else
        {
            if (isInsert) domainObject.handleAfterInsert();
            else if (isUpdate) domainObject.handleAfterUpdate(oldRecordsMap);
            else if (isDelete) domainObject.handleAfterDelete();
            else if (isUndelete) domainObject.handleAfterUndelete();
        }
    }

    /**
     * Pushes to the stack of domain classes per type a domain object instance
     **/
    private static void pushTriggerInstance(Type domainClass, ilib_SObjectDomain domain)
    {
        List<ilib_SObjectDomain> domains = triggerStateByClass.get(domainClass);
        if (domains == null)
            triggerStateByClass.put(domainClass, domains = new List<ilib_SObjectDomain>());
        domains.add(domain);
    }

    /**
     * Pops from the stack of domain classes per type a domain object instance and updates the record set
     **/
    private static ilib_SObjectDomain popTriggerInstance(Type domainClass, List<SObject> records)
    {
        List<ilib_SObjectDomain> domains = triggerStateByClass.get(domainClass);
        if (domains == null || domains.size() == 0)
            return null;
        ilib_SObjectDomain domain = domains.remove(domains.size()-1);
        domain.records = records;
        return domain;
    }

    public static TriggerEvent getTriggerEvent(Type domainClass)
    {
        if (!triggerEventByClass.containsKey(domainClass))
            triggerEventByClass.put(domainClass, new TriggerEvent());

        return triggerEventByClass.get(domainClass);
    }

    public class TriggerEvent
    {
        public boolean beforeInsertEnabled { get; private set; }
        public boolean beforeUpdateEnabled { get; private set; }
        public boolean beforeDeleteEnabled { get; private set; }

        public boolean afterInsertEnabled { get; private set; }
        public boolean afterUpdateEnabled { get; private set; }
        public boolean afterDeleteEnabled { get; private set; }
        public boolean afterUndeleteEnabled { get; private set; }

        public TriggerEvent()
        {
            this.enableAll();
        }

        // befores
        public TriggerEvent enableBeforeInsert() {beforeInsertEnabled = true; return this;}
        public TriggerEvent enableBeforeUpdate() {beforeUpdateEnabled = true; return this;}
        public TriggerEvent enableBeforeDelete() {beforeDeleteEnabled = true; return this;}

        public TriggerEvent disableBeforeInsert() {beforeInsertEnabled = false; return this;}
        public TriggerEvent disableBeforeUpdate() {beforeUpdateEnabled = false; return this;}
        public TriggerEvent disableBeforeDelete() {beforeDeleteEnabled = false; return this;}

        // afters
        public TriggerEvent enableAfterInsert() {afterInsertEnabled = true; return this;}
        public TriggerEvent enableAfterUpdate() {afterUpdateEnabled = true; return this;}
        public TriggerEvent enableAfterDelete() {afterDeleteEnabled = true; return this;}
        public TriggerEvent enableAfterUndelete() {afterUndeleteEnabled = true; return this;}

        public TriggerEvent disableAfterInsert() {afterInsertEnabled = false; return this;}
        public TriggerEvent disableAfterUpdate() {afterUpdateEnabled = false; return this;}
        public TriggerEvent disableAfterDelete() {afterDeleteEnabled = false; return this;}
        public TriggerEvent disableAfterUndelete() {afterUndeleteEnabled = false; return this;}

        public TriggerEvent enableAll()
        {
            return this.enableAllBefore().enableAllAfter();
        }

        public TriggerEvent disableAll()
        {
            return this.disableAllBefore().disableAllAfter();
        }

        public TriggerEvent enableAllBefore()
        {
            return this.enableBeforeInsert().enableBeforeUpdate().enableBeforeDelete();
        }

        public TriggerEvent disableAllBefore()
        {
            return this.disableBeforeInsert().disableBeforeUpdate().disableBeforeDelete();
        }

        public TriggerEvent enableAllAfter()
        {
            return this.enableAfterInsert().enableAfterUpdate().enableAfterDelete().enableAfterUndelete();
        }

        public TriggerEvent disableAllAfter()
        {
            return this.disableAfterInsert().disableAfterUpdate().disableAfterDelete().disableAfterUndelete();
        }

        public boolean isEnabled(Boolean isBefore, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete)
        {
            if (isBefore)
            {
                if (isInsert) return beforeInsertEnabled;
                else if (isUpdate) return beforeUpdateEnabled;
                else if (isDelete) return beforeDeleteEnabled;
            }
            else if (isAfter)
            {
                if (isInsert) return afterInsertEnabled;
                else if (isUpdate) return afterUpdateEnabled;
                else if (isDelete) return afterDeleteEnabled;
                else if (isUndelete) return afterUndeleteEnabled;
            }
            return true; // shouldnt ever get here!
        }
    }

    /**
     * Fluent style Configuration system for Domain class creation
     **/
    public class Configuration
    {
        /**
         * Backwards compatability mode for handleAfterUpdate routing to onValidate()
         **/
        public Boolean oldOnUpdateValidateBehaviour { get; private set; }

        /**
         * True if the base class is checking the users CRUD requirements before invoking trigger methods
         **/
        public Boolean enforcingTriggerCRUDSecurity { get; private set; }

        /**
         * Enables reuse of the same Domain instance between before and after trigger phases (subject to recursive scenarios)
         **/
        public Boolean triggerStateEnabled { get; private set; }

        /**
         * Default configuration
         **/
        public Configuration()
        {
            enforcingTriggerCRUDSecurity = true; // Default is true for backwards compatability
            triggerStateEnabled = false;
            oldOnUpdateValidateBehaviour = false; // Breaking change, but felt to better practice
        }

        /**
         * See associated property
         **/
        public Configuration enableTriggerState()
        {
            triggerStateEnabled = true;
            return this;
        }

        /**
         * See associated property
         **/
        public Configuration disableTriggerState()
        {
            triggerStateEnabled = false;
            return this;
        }

        /**
         * See associated property
         **/
        public Configuration enforceTriggerCRUDSecurity()
        {
            enforcingTriggerCRUDSecurity = true;
            return this;
        }

        /**
         * See associated property
         **/
        public Configuration disableTriggerCRUDSecurity()
        {
            enforcingTriggerCRUDSecurity = false;
            return this;
        }

        /**
         * See associated property
         **/
        public Configuration enableOldOnUpdateValidateBehaviour()
        {
            oldOnUpdateValidateBehaviour = true;
            return this;
        }

        /**
         * See associated property
         **/
        public Configuration disableOldOnUpdateValidateBehaviour()
        {
            oldOnUpdateValidateBehaviour = false;
            return this;
        }
    }

    /**
     * General exception class for the domain layer
     **/
    public class DomainException extends Exception { }

    /**
     * Ensures logging of errors in the Domain context for later assertions in tests
     **/
    public String error(String message, SObject record)
    {
        return errors.error(this, message, record);
    }

    /**
     * Ensures logging of errors in the Domain context for later assertions in tests
     **/
    public String error(String message, SObject record, SObjectField field)
    {
        return errors.error(this, message, record, field);
    }

    /**
     * Ensures logging of errors in the Domain context for later assertions in tests
     **/
    public class ErrorFactory
    {
        private List<Error> errorList = new List<Error>();

        private ErrorFactory() { }

        public String error(String message, SObject record)
        {
            return error(null, message, record);
        }

        private String error(ilib_SObjectDomain domain, String message, SObject record)
        {
            ObjectError objectError = new ObjectError();
            objectError.domain = domain;
            objectError.message = message;
            objectError.record = record;
            errorList.add(objectError);
            return message;
        }

        public String error(String message, SObject record, SObjectField field)
        {
            return error(null, message, record, field);
        }

        private String error(ilib_SObjectDomain domain, String message, SObject record, SObjectField field)
        {
            FieldError fieldError = new FieldError();
            fieldError.domain = domain;
            fieldError.message = message;
            fieldError.record = record;
            fieldError.field = field;
            errorList.add(fieldError);
            return message;
        }

        public List<Error> getAll()
        {
            return errorList.clone();
        }

        public void clearAll()
        {
            errorList.clear();
        }
    }

    /**
     * Ensures logging of errors in the Domain context for later assertions in tests
     **/
    public virtual class FieldError extends ObjectError
    {
        public SObjectField field;

        public FieldError() { }
    }

    /**
     * Ensures logging of errors in the Domain context for later assertions in tests
     **/
    public virtual class ObjectError extends Error
    {
        public SObject record;

        public ObjectError() { }
    }

    /**
     * Ensures logging of errors in the Domain context for later assertions in tests
     **/
    public abstract class Error
    {
        public String message;
        public ilib_SObjectDomain domain;
    }

    /**
     * Provides test context mocking facilities to unit tests testing domain classes
     **/
    public class TestFactory
    {
        public MockDatabase database = new MockDatabase();

        private TestFactory() { }
    }

    /**
     * Class used during Unit testing of Domain classes, can be used (not exclusively) to speed up test execution and focus testing
     **/
    public class MockDatabase
    {
        private Boolean isInsert = false;
        private Boolean isUpdate = false;
        private Boolean isDelete = false;
        private Boolean isUndelete = false;
        private List<SObject> records = new List<SObject>();
        private Map<Id, SObject> oldRecords = new Map<Id, SObject>();

        private MockDatabase() { }

        private void testTriggerHandler(Type domainClass)
        {
            // Mock Before
            triggerHandler(domainClass, true, false, isInsert, isUpdate, isDelete, isUndelete, records, oldRecords);

            // Mock After
            triggerHandler(domainClass, false, true, isInsert, isUpdate, isDelete, isUndelete, records, oldRecords);
        }

        public void onInsert(List<SObject> records)
        {
            this.isInsert = true;
            this.isUpdate = false;
            this.isDelete = false;
            this.isUndelete = false;
            this.records = records;
        }

        public void onUpdate(List<SObject> records, Map<Id, SObject> oldRecords)
        {
            this.isInsert = false;
            this.isUpdate = true;
            this.isDelete = false;
            this.records = records;
            this.isUndelete = false;
            this.oldRecords = oldRecords;
        }

        public void onDelete(Map<Id, SObject> records)
        {
            this.isInsert = false;
            this.isUpdate = false;
            this.isDelete = true;
            this.isUndelete = false;
            this.oldRecords = records;
        }

        public void onUndelete(List<SObject> records)
        {
            this.isInsert = false;
            this.isUpdate = false;
            this.isDelete = false;
            this.isUndelete = true;
            this.records = records;
        }

        public Boolean hasRecords()
        {
            return records != null && records.size() > 0 || oldRecords != null && oldRecords.size() > 0;
        }
    }

    /**
     * Test domain class (ideally this would be in the test class, however Type.newInstance does not see such classes)
     **/
    public with sharing class TestSObjectDomain extends ilib_SObjectDomain
    {
        private String someState;

        public TestSObjectDomain(List<Opportunity> sObjectList)
        {
            // Domain classes are initialised with lists to enforce bulkification throughout
            super(sObjectList);
        }

        public TestSObjectDomain(List<Opportunity> sObjectList, SObjectType sObjectType)
        {
            // Domain classes are initialised with lists to enforce bulkification throughout
            super(sObjectList, sObjectType);
        }

        public override void onApplyDefaults()
        {
            // Not required in production code
            super.onApplyDefaults();

            // Apply defaults to Testilib_SObjectDomain
            for (Opportunity opportunity : (List<Opportunity>) records)
                opportunity.CloseDate = System.today().addDays(30);
        }

        public override void onValidate()
        {
            // Not required in production code
            super.onValidate();

            // Validate Testilib_SObjectDomain
            for (Opportunity opp : (List<Opportunity>) records)
                if (opp.Type!=null && opp.Type.startsWith('Existing') && opp.AccountId == null)
                    opp.AccountId.addError( error('You must provide an Account for Opportunities for existing Customers.', opp, Opportunity.AccountId) );
        }

        public override void onValidate(Map<Id, SObject> existingRecords)
        {
            // Not required in production code
            super.onValidate(existingRecords);

            // Validate changes to Testilib_SObjectDomain
            for (Opportunity opp : (List<Opportunity>) records)
            {
                Opportunity existingOpp = (Opportunity) existingRecords.get(opp.Id);
                if (opp.Type != existingOpp.Type)
                    opp.Type.addError( error('You cannot change the Opportunity type once it has been created.', opp, Opportunity.Type) );
            }
        }

        public override void onBeforeDelete()
        {
            // Not required in production code
            super.onBeforeDelete();

            // Validate changes to Testilib_SObjectDomain
            for (Opportunity opp : (List<Opportunity>) records)
                opp.addError( error('You cannot delete this Opportunity.', opp) );
        }

        public override void onAfterUndelete()
        {
            // Not required in production code
            super.onAfterUndelete();
        }

        public override void onBeforeInsert()
        {
            // Assert this variable is null in the after insert (since this domain class is stateless)
            someState = 'This should not survice the trigger after phase';
        }

        public override void onAfterInsert()
        {
            // This is a stateless domain class, so should not retain anything betweet before and after
            System.assertEquals(null, someState);
        }
    }

    /**
     * Typically an inner class to the domain class, supported here for test purposes
     **/
    public class TestSObjectDomainConstructors implements ilib_SObjectDomain.IConstructable
    {
        public ilib_SObjectDomain construct(List<SObject> sObjectList)
        {
            return new TestSObjectDomain(sObjectList);
        }
    }

    /**
     * Test domain class (ideally this would be in the test class, however Type.newInstance does not see such classes)
     **/
    public with sharing class TestSObjectStatefulDomain extends ilib_SObjectDomain
    {
        public String someState;

        public TestSObjectStatefulDomain(List<Opportunity> sObjectList)
        {
            super(sObjectList);

            // Ensure this instance is re-used in the after trigger phase (subject to recursive scenarios)
            Configuration.enableTriggerState();
        }

        public override void onBeforeInsert()
        {
            // This must always be null, as we do not reuse domain instances within recursive scenarios (different record sets)
            System.assertEquals(null, someState);

            // Process records
            List<Opportunity> newOpps = new List<Opportunity>();
            for (Opportunity opp : (List<Opportunity>) records)
            {
                // Set some state sensitive to the incoming records
                someState = 'Error on Record ' + opp.Name;

                // Create a new Opportunity record to trigger recursive code path?
                if (opp.Name.equals('Test Recursive 1'))
                    newOpps.add(new Opportunity ( Name = 'Test Recursive 2', Type = 'Existing Account' ));
            }

            // If testing recursiving emulate an insert
            if (newOpps.size() > 0)
            {
                // This will force recursion and thus validate via the above assert results in a new domain instance
                ilib_SObjectDomain.test.database.onInsert(newOpps);
                ilib_SObjectDomain.triggerHandler(ilib_SObjectDomain.TestSObjectStatefulDomainConstructors.class);
            }
        }

        public override void onAfterInsert()
        {
            // Use the state set in the before insert (since this is a stateful domain class)
            if (someState!=null)
                for (Opportunity opp : (List<Opportunity>) records)
                    opp.addError(error(someState, opp));
        }
    }

    /**
     * Typically an inner class to the domain class, supported here for test purposes
     **/
    public class TestSObjectStatefulDomainConstructors implements ilib_SObjectDomain.IConstructable
    {
        public ilib_SObjectDomain construct(List<SObject> sObjectList)
        {
            return new TestSObjectStatefulDomain(sObjectList);
        }
    }

    /**
     * Test domain class (ideally this would be in the test class, however Type.newInstance does not see such classes)
     **/
    public with sharing class TestSObjectOnValidateBehaviour extends ilib_SObjectDomain
    {
        public TestSObjectOnValidateBehaviour(List<Opportunity> sObjectList)
        {
            super(sObjectList);

            // Enable old behaviour based on the test Opportunity name passed in
            if (sObjectList[0].Name == 'Test Enable Old Behaviour')
                Configuration.enableOldOnUpdateValidateBehaviour();
        }

        public override void onValidate()
        {
            // Throw exception to give the test somethign to assert on
            throw new DomainException('onValidate called');
        }
    }

    /**
     * Typically an inner class to the domain class, supported here for test purposes
     **/
    public class TestSObjectOnValidateBehaviourConstructors implements ilib_SObjectDomain.IConstructable
    {
        public ilib_SObjectDomain construct(List<SObject> sObjectList)
        {
            return new TestSObjectOnValidateBehaviour(sObjectList);
        }
    }

    /**
     * Test domain class (ideally this would be in the test class, however Type.newInstance does not see such classes)
     **/
    public with sharing class TestSObjectDisableBehaviour extends ilib_SObjectDomain
    {
        public TestSObjectDisableBehaviour(List<Opportunity> sObjectList)
        {
            super(sObjectList);
        }

        public override void onAfterInsert()
        {
            // Throw exception to give the test somethign to assert on
            throw new DomainException('onAfterInsert called');
        }

        public override void onBeforeInsert()
        {
            // Throw exception to give the test somethign to assert on
            throw new DomainException('onBeforeInsert called');
        }

        public override void onAfterUpdate(Map<Id, SObject> existing)
        {
            // Throw exception to give the test somethign to assert on
            throw new DomainException('onAfterUpdate called');
        }

        public override void onBeforeUpdate(Map<Id, SObject> existing)
        {
            // Throw exception to give the test somethign to assert on
            throw new DomainException('onBeforeUpdate called');
        }

        public override void onAfterDelete()
        {
            // Throw exception to give the test somethign to assert on
            throw new DomainException('onAfterDelete called');
        }

        public override void onBeforeDelete()
        {
            // Throw exception to give the test somethign to assert on
            throw new DomainException('onBeforeDelete called');
        }

        public override void onAfterUndelete()
        {
            // Throw exception to give the test somethign to assert on
            throw new DomainException('onAfterUndelete called');
        }
    }

    /**
     * Typically an inner class to the domain class, supported here for test purposes
     **/
    public class TestSObjectDisableBehaviourConstructors implements ilib_SObjectDomain.IConstructable
    {
        public ilib_SObjectDomain construct(List<SObject> sObjectList)
        {
            return new TestSObjectDisableBehaviour(sObjectList);
        }
    }

}