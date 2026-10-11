-- =====================================================================
-- Recruiting & Deal Pipeline Database
-- Author: Brandon Cruz | Rutgers Business School
-- Platform: MySQL 8 (runs as-is in MySQL Workbench)
--
-- Purpose: track firms, contacts, applications and networking touchpoints
-- in a normalized (3NF) schema, then answer pipeline questions with SQL.
-- =====================================================================

DROP DATABASE IF EXISTS pipeline_db;
CREATE DATABASE pipeline_db;
USE pipeline_db;

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

CREATE TABLE firm (
    firm_id      INT AUTO_INCREMENT PRIMARY KEY,
    firm_name    VARCHAR(100) NOT NULL UNIQUE,
    firm_type    ENUM('Bulge Bracket','Middle Market','Boutique','Asset Manager',
                      'Private Credit','Insurance','Other') NOT NULL,
    hq_city      VARCHAR(60)
);

CREATE TABLE contact (
    contact_id   INT AUTO_INCREMENT PRIMARY KEY,
    firm_id      INT NOT NULL,
    first_name   VARCHAR(50) NOT NULL,
    last_name    VARCHAR(50) NOT NULL,
    title        VARCHAR(80),
    source       ENUM('Alumni','Fraternity','Cold Outreach','Referral','Event') NOT NULL,
    FOREIGN KEY (firm_id) REFERENCES firm(firm_id)
);

CREATE TABLE application (
    application_id INT AUTO_INCREMENT PRIMARY KEY,
    firm_id        INT NOT NULL,
    role_title     VARCHAR(120) NOT NULL,
    date_applied   DATE NOT NULL,
    stage          ENUM('Applied','Assessment','First Round','Superday',
                        'Offer','Rejected','Withdrawn') NOT NULL DEFAULT 'Applied',
    referral_contact_id INT NULL,
    FOREIGN KEY (firm_id) REFERENCES firm(firm_id),
    FOREIGN KEY (referral_contact_id) REFERENCES contact(contact_id)
);

CREATE TABLE interaction (
    interaction_id INT AUTO_INCREMENT PRIMARY KEY,
    contact_id     INT NOT NULL,
    interaction_date DATE NOT NULL,
    channel        ENUM('Email','LinkedIn','Call','Coffee Chat') NOT NULL,
    got_response   BOOLEAN NOT NULL DEFAULT FALSE,
    follow_up_date DATE NULL,
    notes          VARCHAR(255),
    FOREIGN KEY (contact_id) REFERENCES contact(contact_id)
);

-- ---------------------------------------------------------------------
-- Sample data (fictional firms and contacts for demonstration)
-- ---------------------------------------------------------------------

INSERT INTO firm (firm_name, firm_type, hq_city) VALUES
('Harbor Point Capital',    'Private Credit', 'New York'),
('Summit Ridge Partners',   'Middle Market',  'New York'),
('Ironbridge Advisory',     'Boutique',       'Arlington'),
('Lakeshore Asset Mgmt',    'Asset Manager',  'Chicago'),
('Northgate Insurance Group','Insurance',     'New York'),
('Crestline Securities',    'Bulge Bracket',  'New York');

INSERT INTO contact (firm_id, first_name, last_name, title, source) VALUES
(1, 'Jordan', 'Reyes',   'Associate',      'Alumni'),
(2, 'Priya',  'Shah',    'Vice President', 'Fraternity'),
(3, 'Marcus', 'Bell',    'Managing Director','Cold Outreach'),
(4, 'Elena',  'Park',    'Analyst',        'Event'),
(5, 'Daniel', 'Moore',   'Managing Director','Referral'),
(6, 'Sofia',  'Alvarez', 'Associate',      'Cold Outreach');

INSERT INTO application (firm_id, role_title, date_applied, stage, referral_contact_id) VALUES
(1, '2027 Private Credit Summer Analyst', '2026-08-10', 'First Round', 1),
(2, '2027 IB Summer Analyst',             '2026-08-18', 'Superday',    2),
(3, '2027 M&A Summer Analyst',            '2026-09-02', 'Applied',     NULL),
(4, '2027 Investments Intern',            '2026-09-05', 'Assessment',  NULL),
(5, '2027 Finance Rotational Intern',     '2026-08-25', 'Offer',       5),
(6, '2027 Global Markets Summer Analyst', '2026-08-12', 'Rejected',    NULL);

INSERT INTO interaction (contact_id, interaction_date, channel, got_response, follow_up_date, notes) VALUES
(1, '2026-07-20', 'LinkedIn',    TRUE,  '2026-10-15', 'Intro via alumni network'),
(1, '2026-08-01', 'Call',        TRUE,  NULL,         'Discussed private credit recruiting'),
(2, '2026-07-28', 'Coffee Chat', TRUE,  '2026-10-12', 'Offered to refer'),
(3, '2026-09-01', 'Email',       FALSE, '2026-10-10', 'Cold email, no reply yet'),
(4, '2026-09-04', 'LinkedIn',    TRUE,  NULL,         'Met at campus event'),
(5, '2026-08-20', 'Call',        TRUE,  NULL,         'Advocated with HR'),
(6, '2026-08-05', 'Email',       FALSE, NULL,         'Cold email, no reply'),
(6, '2026-08-19', 'LinkedIn',    FALSE, '2026-10-14', 'Second touch, no reply yet'),
(4, '2026-09-20', 'Email',       FALSE, NULL,         'Thank-you note after event');

-- ---------------------------------------------------------------------
-- Analytical queries
-- ---------------------------------------------------------------------

-- 1. Pipeline summary: how many applications sit in each stage?
SELECT stage, COUNT(*) AS num_applications
FROM application
GROUP BY stage
ORDER BY FIELD(stage,'Applied','Assessment','First Round','Superday','Offer','Rejected','Withdrawn');

-- 2. Do referrals help? Compare how far referred vs. non-referred applications advance.
SELECT
    CASE WHEN referral_contact_id IS NULL THEN 'No Referral' ELSE 'Referral' END AS referral_status,
    COUNT(*) AS apps,
    SUM(stage IN ('First Round','Superday','Offer')) AS advanced_past_screen
FROM application
GROUP BY referral_status;

-- 3. Follow-ups due in the next 7 days (relative to a given date).
SET @today = '2026-10-09';
SELECT c.first_name, c.last_name, f.firm_name, i.channel, i.follow_up_date
FROM interaction i
JOIN contact c ON c.contact_id = i.contact_id
JOIN firm f    ON f.firm_id    = c.firm_id
WHERE i.follow_up_date BETWEEN @today AND DATE_ADD(@today, INTERVAL 7 DAY)
ORDER BY i.follow_up_date;

-- 4. Outreach response rate by contact source.
SELECT c.source,
       COUNT(*) AS touches,
       ROUND(100 * AVG(i.got_response), 1) AS response_rate_pct
FROM interaction i
JOIN contact c ON c.contact_id = i.contact_id
GROUP BY c.source
ORDER BY response_rate_pct DESC, touches DESC;

-- 5. Full view of each active application with its referral contact (if any).
SELECT f.firm_name, f.firm_type, a.role_title, a.stage,
       CONCAT(c.first_name, ' ', c.last_name) AS referral
FROM application a
JOIN firm f          ON f.firm_id = a.firm_id
LEFT JOIN contact c  ON c.contact_id = a.referral_contact_id
WHERE a.stage NOT IN ('Rejected','Withdrawn')
ORDER BY a.date_applied;
