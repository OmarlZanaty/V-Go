-- Run with sqlcmd and an explicitly supplied -v COMMIT_PURGE value.
-- Only the exact, case-sensitive value YES commits; all other values roll back.
-- Assumptions: tables are in dbo; DriverLedgerEntries.Amount is an exact
-- numeric signed balance contribution, and its SUM fits the SQL result type.
-- Run in a dedicated session with no existing transaction.
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @cut datetime2 = '2026-10-21T00:00:00';
DECLARE @rows int;
DECLARE @kept bigint;
DECLARE @removed bigint;

IF @@TRANCOUNT <> 0
    THROW 50000, 'An existing transaction is not allowed.', 1;

-- Keep the selection, balance snapshots, and deletes consistent with each other.
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRY
    BEGIN TRAN;

    SELECT u.Id
    INTO #delUsers
    FROM dbo.AspNetUsers AS u
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.AspNetUserRoles AS ur
        JOIN dbo.AspNetRoles AS r ON r.Id = ur.RoleId
        WHERE ur.UserId = u.Id AND r.Name IN ('Admin', 'Accountant')
    )
      AND (u.CreatedAt < @cut OR u.CreatedAt IS NULL)
      AND (u.LastLogin < @cut OR u.LastLogin IS NULL)
      AND NOT EXISTS (
          SELECT 1 FROM dbo.UserTrips AS ut
          JOIN dbo.Trips AS t ON t.Id = ut.TripId
          WHERE ut.UserId = u.Id AND t.CreatedAt >= @cut
      )
      AND NOT EXISTS (
          SELECT 1 FROM dbo.DriverLedgerEntries AS l
          WHERE l.DriverId = u.Id AND l.CreatedAt >= @cut
      )
      AND NOT EXISTS (
          SELECT 1 FROM dbo.Payments AS p
          WHERE p.UserId = u.Id AND p.CreatedAt >= @cut
      )
      AND NOT EXISTS (
          SELECT 1 FROM dbo.CollectionRequests AS cr
          WHERE cr.DriverId = u.Id AND cr.CreatedAt >= @cut
      );

    SELECT Id INTO #delTrips FROM dbo.Trips WHERE CreatedAt < @cut;

    SELECT @removed = COUNT_BIG(*) FROM #delUsers;
    SELECT @kept = COUNT_BIG(*)
    FROM dbo.AspNetUsers AS u
    WHERE NOT EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = u.Id);
    PRINT CONCAT('Accounts kept: ', @kept);
    PRINT CONCAT('Accounts removed if committed: ', @removed);

    SELECT COALESCE(SUM(l.Amount), 0) AS Balance
    INTO #balanceBefore
    FROM dbo.DriverLedgerEntries AS l
    WHERE NOT EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = l.DriverId);

    -- 1. Preserve every kept driver's ledger row.
    UPDATE l SET TripId = NULL
    FROM dbo.DriverLedgerEntries AS l
    WHERE EXISTS (SELECT 1 FROM #delTrips AS d WHERE d.Id = l.TripId)
      AND NOT EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = l.DriverId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('1. Ledger trip references cleared: ', @rows);

    DELETE l FROM dbo.DriverLedgerEntries AS l
    WHERE EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = l.DriverId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('1. Ledger rows deleted: ', @rows);

    -- 2. Clear payment references before deleting those payments.
    UPDATE l SET PaymentId = NULL
    FROM dbo.DriverLedgerEntries AS l
    JOIN dbo.Payments AS p ON p.Id = l.PaymentId
    WHERE p.CreatedAt < @cut
       OR EXISTS (SELECT 1 FROM #delTrips AS d WHERE d.Id = p.TripId)
       OR EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = p.UserId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('2. Ledger payment references cleared: ', @rows);

    DELETE p FROM dbo.Payments AS p
    WHERE p.CreatedAt < @cut
       OR EXISTS (SELECT 1 FROM #delTrips AS d WHERE d.Id = p.TripId)
       OR EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = p.UserId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('2. Payments deleted: ', @rows);

    -- 3. Rates.
    DELETE r FROM dbo.Rates AS r
    WHERE EXISTS (SELECT 1 FROM #delTrips AS d WHERE d.Id = r.TripId)
       OR EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = r.FromUserId)
       OR EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = r.ToUserId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('3. Rates deleted: ', @rows);

    -- 4. UserTrips.
    DELETE ut FROM dbo.UserTrips AS ut
    WHERE EXISTS (SELECT 1 FROM #delTrips AS d WHERE d.Id = ut.TripId)
       OR EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = ut.UserId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('4. UserTrips deleted: ', @rows);

    -- 5. Chats cascade to Messages and UserChats; then remove trips.
    DELETE c FROM dbo.Chats AS c
    WHERE c.CreatedAt < @cut
       OR EXISTS (SELECT 1 FROM #delTrips AS d WHERE d.Id = c.TripId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('5. Chats deleted: ', @rows);

    DELETE t FROM dbo.Trips AS t
    WHERE EXISTS (SELECT 1 FROM #delTrips AS d WHERE d.Id = t.Id);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('5. Trips deleted: ', @rows);

    -- 6. Notifications, including the non-cascading account reference.
    DELETE n FROM dbo.Notifications AS n
    WHERE n.CreatedAt < @cut
       OR EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = n.UserId)
       OR EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = n.ApplicationUserId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('6. Notifications deleted: ', @rows);

    -- 7. Remaining non-cascading account dependents.
    DELETE pg FROM dbo.PromotionGrants AS pg
    WHERE EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = pg.UserId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('7. PromotionGrants deleted: ', @rows);

    DELETE dd FROM dbo.DriverDocuments AS dd
    WHERE EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = dd.DriverId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('7. DriverDocuments deleted: ', @rows);

    -- 8. Preserve all WalletSms rows and clear references before requests go.
    UPDATE ws SET CollectionRequestId = NULL
    FROM dbo.WalletSms AS ws
    JOIN dbo.CollectionRequests AS cr ON cr.Id = ws.CollectionRequestId
    WHERE EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = cr.DriverId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('8. WalletSms collection request references cleared: ', @rows);

    UPDATE ws SET DriverId = NULL
    FROM dbo.WalletSms AS ws
    WHERE EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = ws.DriverId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('8. WalletSms driver references cleared: ', @rows);

    DELETE cr FROM dbo.CollectionRequests AS cr
    WHERE EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = cr.DriverId);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('8. CollectionRequests deleted: ', @rows);

    -- 9. Account cascades handle the remaining cascading dependents.
    DELETE u FROM dbo.AspNetUsers AS u
    WHERE EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = u.Id);
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('9. AspNetUsers deleted: ', @rows);

    -- 10. Expired test authentication and SMS records.
    DELETE FROM dbo.PhoneOtps WHERE CreatedAt < @cut;
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('10. PhoneOtps deleted: ', @rows);

    DELETE FROM dbo.SmsOutbox WHERE CreatedAt < @cut;
    SET @rows = @@ROWCOUNT;
    PRINT CONCAT('10. SmsOutbox deleted: ', @rows);

    SELECT COALESCE(SUM(l.Amount), 0) AS Balance
    INTO #balanceAfter
    FROM dbo.DriverLedgerEntries AS l
    WHERE NOT EXISTS (SELECT 1 FROM #delUsers AS d WHERE d.Id = l.DriverId);

    DECLARE @beforeText varchar(100);
    DECLARE @afterText varchar(100);
    SELECT @beforeText = CONVERT(varchar(100), Balance) FROM #balanceBefore;
    SELECT @afterText = CONVERT(varchar(100), Balance) FROM #balanceAfter;
    PRINT CONCAT('Kept drivers ledger balance before: ', @beforeText);
    PRINT CONCAT('Kept drivers ledger balance after: ', @afterText);

    IF EXISTS (
        SELECT 1 FROM #balanceBefore AS b CROSS JOIN #balanceAfter AS a
        WHERE b.Balance <> a.Balance
    )
        THROW 50001, 'Kept drivers ledger balance changed; purge rejected.', 1;

    DROP TABLE #balanceBefore, #balanceAfter, #delTrips, #delUsers;

    IF '$(COMMIT_PURGE)' COLLATE Latin1_General_100_BIN2 = 'YES'
       AND DATALENGTH('$(COMMIT_PURGE)') = 3
    BEGIN
        COMMIT;
        PRINT 'Purge committed.';
    END
    ELSE
    BEGIN
        ROLLBACK;
        PRINT 'Purge rolled back.';
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK;
    PRINT 'Purge failed and rolled back.';
    THROW;
END CATCH;
