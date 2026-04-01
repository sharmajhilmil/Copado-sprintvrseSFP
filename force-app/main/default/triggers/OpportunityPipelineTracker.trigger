trigger OpportunityPipelineTracker on Opportunity (
    after insert, after update, after delete, after undelete
) {
    Set<Id> accountIds = new Set<Id>();

    List<Opportunity> opps = Trigger.isDelete
        ? Trigger.old : Trigger.new;

    for (Opportunity opp : opps) {
        if (opp.AccountId != null) {
            accountIds.add(opp.AccountId);
        }
    }

    if (accountIds.isEmpty()) return;

    // Aggregate open pipeline per account
    Map<Id, Decimal> pipelineMap = new Map<Id, Decimal>();

    for (AggregateResult ar : [
        SELECT AccountId, SUM(Amount) total
        FROM Opportunity
        WHERE AccountId IN :accountIds
          AND IsClosed = false
        GROUP BY AccountId
    ]) {
        pipelineMap.put(
            (Id) ar.get('AccountId'),
            (Decimal) ar.get('total')
        );
    }

    // Update accounts
    List<Account> toUpdate = new List<Account>();
    for (Id accId : accountIds) {
        toUpdate.add(new Account(
            Id = accId,
            Total_Open_Pipeline__c = pipelineMap.containsKey(accId)
                ? pipelineMap.get(accId) : 0
        ));
    }

    if (!toUpdate.isEmpty()) {
        update toUpdate;
    }
}