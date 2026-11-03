-- Azure SQL initialization for hello-world acceptance test.
-- Run via sqlcmd with AAD auth after infrastructure is deployed.

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'hello')
BEGIN
    CREATE TABLE hello (
        id INT IDENTITY(1,1) PRIMARY KEY,
        message NVARCHAR(255) NOT NULL,
        created_at DATETIME2 DEFAULT GETDATE()
    );

    INSERT INTO hello (message) VALUES ('hello-from-sql');
END
GO
