// Anonymous Apex — seed Account record for AccountSummary FlexCard + DataRaptor
// DataRaptor: AccountSummaryGetDetails (extracts Name, Phone, Industry, Type,
//             BillingCity, BillingState, Website)
// FlexCard:   AccountSummary_Salesforce_1 (displays all of the above)

Account acc = new Account(
    Name         = 'Life Sciences Test Account',
    Phone        = '+61 2 9000 1234',
    Industry     = 'Healthcare',
    Type         = 'Customer',
    BillingStreet= '100 Collins Street',
    BillingCity  = 'Melbourne',
    BillingState = 'VIC',
    BillingPostalCode = '3000',
    BillingCountry    = 'Australia',
    Website      = 'https://lifesciences-test.example.com'
);

insert acc;

System.debug('==============================================');
System.debug('AccountSummary seed record created.');
System.debug('Account Id  : ' + acc.Id);
System.debug('Account Name: ' + acc.Name);
System.debug('');
System.debug('Open this URL in your org to test the FlexCard:');
System.debug('/lightning/r/Account/' + acc.Id + '/view');
System.debug('==============================================');
