CREATE DATABASE bank_db;
USE bank_db;


CREATE TABLE bank_customers (
    cust_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    dob DATE,
    pan_number VARCHAR(10) UNIQUE,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(15),
    kyc_status ENUM('pending','verified','rejected') DEFAULT 'pending',
    created_at DATETIME DEFAULT NOW()
);

CREATE TABLE account_types (
    type_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50),
    interest_rate DECIMAL(5,2),
    min_balance DECIMAL(10,2)
);

CREATE TABLE accounts (
    account_no VARCHAR(20) PRIMARY KEY,
    cust_id INT NOT NULL,
    type_id INT NOT NULL,
    balance DECIMAL(12,2) DEFAULT 0,
    status ENUM('active','inactive','frozen','closed') DEFAULT 'active',
    opened_at DATETIME DEFAULT NOW(),
    FOREIGN KEY (cust_id) REFERENCES bank_customers(cust_id),
    FOREIGN KEY (type_id) REFERENCES account_types(type_id)
);

CREATE TABLE transactions (
    txn_id VARCHAR(30) PRIMARY KEY,
    account_no VARCHAR(20),
    type ENUM('deposit','withdrawal','transfer_in','transfer_out','interest'),
    amount DECIMAL(12,2) NOT NULL,
    balance_after DECIMAL(12,2),
    description VARCHAR(200),
    txn_date DATETIME DEFAULT NOW(),
    FOREIGN KEY (account_no) REFERENCES accounts(account_no)
);

CREATE TABLE loans (
    loan_id INT AUTO_INCREMENT PRIMARY KEY,
    cust_id INT,
    loan_type ENUM('home','personal','vehicle','education'),
    principal DECIMAL(12,2),
    interest_rate DECIMAL(5,2),
    tenure_months INT,
    emi_amount DECIMAL(10,2),
    disbursed_on DATE,
    status ENUM('active','closed','defaulted') DEFAULT 'active',
    FOREIGN KEY (cust_id) REFERENCES bank_customers(cust_id)
);

CREATE TABLE emi_payments (
    emi_id INT AUTO_INCREMENT PRIMARY KEY,
    loan_id INT,
    due_date DATE,
    paid_date DATE,
    amount DECIMAL(10,2),
    status ENUM('paid','due','overdue'),
    FOREIGN KEY (loan_id) REFERENCES loans(loan_id)
);

CREATE TABLE transaction_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    account_no VARCHAR(20),
    old_balance DECIMAL(12,2),
    new_balance DECIMAL(12,2),
    changed_at DATETIME DEFAULT NOW()
);


-- ??? SAMPLE DATA ???????????????????????????????????????????

INSERT INTO account_types(name, interest_rate, min_balance) VALUES
('Savings', 4.00, 1000),
('Current', 0.00, 10000),
('Fixed Deposit', 7.50, 5000);

INSERT INTO bank_customers(full_name, dob, pan_number, email, phone, kyc_status) VALUES
('Rahul Sharma','1985-04-12','ABCPS1234A','rahul@bank.com','9810001111','verified'),
('Pooja Nair','1990-07-18','DEFPN5678B','pooja@bank.com','9820002222','verified'),
('Sanjay Mehta','1978-01-30','GHISM9012C','sanjay@bank.com','9830003333','verified'),
('Ritu Agarwal','1995-12-05','JKLRA3456D','ritu@bank.com','9840004444','pending'),
('Farhan Khan','1988-08-22','MNOFA7890E','farhan@bank.com','9850005555','verified');

INSERT INTO accounts(account_no, cust_id, type_id, balance, status, opened_at) VALUES
('ACC0000000001',1,1,85000.00,'active',NOW()),
('ACC0000000002',2,1,42000.00,'active',NOW()),
('ACC0000000003',3,2,250000.00,'active',NOW()),
('ACC0000000004',4,1,5000.00,'active',NOW()),
('ACC0000000005',5,3,100000.00,'active',NOW());

INSERT INTO transactions(txn_id, account_no, type, amount, balance_after, description) VALUES
('TXN001','ACC0000000001','deposit',50000.00,85000.00,'Initial deposit'),
('TXN002','ACC0000000001','withdrawal',10000.00,75000.00,'ATM withdrawal'),
('TXN003','ACC0000000002','deposit',42000.00,42000.00,'Salary credit'),
('TXN004','ACC0000000001','transfer_out',5000.00,70000.00,'Transfer to Pooja'),
('TXN005','ACC0000000002','transfer_in',5000.00,47000.00,'From Rahul');

INSERT INTO loans(cust_id,loan_type,principal,interest_rate,tenure_months,emi_amount,disbursed_on) VALUES
(1,'home',    5000000.00,8.50,240,43391.22,'2023-06-01'),
(2,'personal',  200000.00,12.00,36, 6643.18,'2024-01-01'),
(3,'vehicle',   800000.00, 9.00,60,16594.21,'2023-12-01');

INSERT INTO emi_payments(loan_id, due_date, paid_date, amount, status) VALUES
(2,'2024-02-01','2024-01-30', 6643.18,'paid'),
(2,'2024-03-01','2024-03-01', 6643.18,'paid'),
(2,'2024-04-01', NULL,        6643.18,'overdue'),
(3,'2024-02-01','2024-02-01',16594.21,'paid'),
(3,'2024-03-01','2024-03-03',16594.21,'paid');

-- ??? UPDATE ????????????????????????????????????????????????
UPDATE bank_customers
SET kyc_status='verified'
WHERE cust_id=4;

UPDATE accounts
SET status='frozen'
WHERE balance < 1000 AND type_id=1;


-- ??? SELECT Q1: Net worth vs loan exposure ?????????????????
SELECT
    bc.full_name,
    at2.name AS account_type,
    a.balance,
    IFNULL(SUM(l.principal),0) AS total_loans,
    a.balance - IFNULL(SUM(l.principal),0) AS net_worth
FROM bank_customers bc
JOIN accounts a
    ON bc.cust_id = a.cust_id
JOIN account_types at2
    ON a.type_id = at2.type_id
LEFT JOIN loans l
    ON bc.cust_id = l.cust_id
    AND l.status = 'active'
WHERE bc.kyc_status = 'verified'
GROUP BY bc.cust_id, bc.full_name, at2.name, a.balance
ORDER BY net_worth DESC;

-- ??? SUBQUERY 1: Accounts above branch average ?????????????

SELECT account_no, balance FROM accounts
WHERE balance > (SELECT AVG(balance) FROM accounts WHERE status='active')
ORDER BY balance DESC;

-- ??? SUBQUERY 2: Customers with savings + active loan ??????

SELECT full_name, email FROM bank_customers
WHERE cust_id IN (SELECT cust_id FROM accounts WHERE type_id = 1)
  AND cust_id IN (SELECT cust_id FROM loans WHERE status = 'active');


-- ??? STORED PROCEDURE: Atomic Fund Transfer ????????????????

DELIMITER //

CREATE PROCEDURE FundTransfer(
    IN from_acc VARCHAR(20),
    IN to_acc VARCHAR(20),
    IN amt DECIMAL(12,2)
)
BEGIN

    START TRANSACTION;

    UPDATE accounts
    SET balance = balance - amt
    WHERE account_no = from_acc;

    UPDATE accounts
    SET balance = balance + amt
    WHERE account_no = to_acc;

    COMMIT;

END //

DELIMITER ;



-- ??? VIEW  Account Dasboard??????????????????????????????????????????????????

CREATE VIEW vw_account_dashboard AS
SELECT
    bc.full_name, bc.email,
    a.account_no, at2.name AS account_type,
    a.balance, a.status, at2.interest_rate,
    COUNT(t.txn_id) AS total_transactions
FROM bank_customers bc
JOIN accounts a
    ON bc.cust_id = a.cust_id

JOIN account_types at2
    ON a.type_id = at2.type_id

LEFT JOIN transactions t
    ON a.account_no = t.account_no

GROUP BY
    bc.cust_id,
    bc.full_name,
    bc.email,
    a.account_no,
    at2.name,
    a.balance,
    a.status,
    at2.interest_rate;
    
-- ??? TRIGGER: Balance change audit ?????????????????????????

DELIMITER //

CREATE TRIGGER trg_balance_audit

AFTER UPDATE
ON accounts

FOR EACH ROW

BEGIN

    INSERT INTO transaction_audit(
        account_no,
        old_balance,
        new_balance
    )

    VALUES(
        OLD.account_no,
        OLD.balance,
        NEW.balance
    );

END //

DELIMITER ;

-- ??? INDEXES ???????????????????????????????????????????????

CREATE INDEX idx_txn_account ON transactions(account_no);
CREATE INDEX idx_txn_date ON transactions(txn_date);
CREATE INDEX idx_loan_cust ON loans(cust_id);


-- ??? CTE: Monthly cash flow per account ????????????????????
WITH monthly AS
(
    SELECT

        account_no,

        DATE_FORMAT(txn_date,'%Y-%m') AS month,

        COUNT(*) AS txn_count,

        SUM(
            CASE
                WHEN type IN ('deposit','transfer_in')
                THEN amount
                ELSE 0
            END
        ) AS credits,

        SUM(
            CASE
                WHEN type IN ('withdrawal','transfer_out')
                THEN amount
                ELSE 0
            END
        ) AS debits

    FROM transactions

    GROUP BY
        account_no,
        DATE_FORMAT(txn_date,'%Y-%m')
)

SELECT *,
       (credits - debits) AS net_flow

FROM monthly

ORDER BY
    account_no,
    month;