/*
select * from mail.dept  order by dept_name;

select * from mail.hr_departments;

select * from mail.Banner_dept;

select * from mail.sap_dept order by dept_desc;

select * from mail.Person where sap_dept_code is not null;


select 
sapdept.dept as 'SAP CODE', sapdept.dept_code as 'SAP MAPPING', 
sapDeptInfo.description as 'SAP NAME',
bannerdept.SGBSTDN_DEPT_CODE as 'BANNER CODE', bannerdept.dept_code as 'BANNER MAPPING',
bannerDeptInfo.dept_name as 'BANNER NAME', bannerDeptInfo.full_name as 'BANNER NAME 2'
from sap_dept as sapdept
left outer join banner_dept as bannerdept
on sapdept.dept_code = bannerdept.dept_code
left outer join dept as bannerDeptInfo
on bannerdept.dept_code = bannerDeptInfo.dept_code
left outer join hr_departments as sapDeptInfo
on sapdept.dept = sapDeptInfo.sap_dept_code
order by sapdept.dept
*/


-- Add new HU code to banner_dept
-- Used to map from Banner to Accman codes
-- SGBSTDN_DEPT_CODE used for mapping in StudentPerson.parseCourse
-- Also used for comparison with $SYRACCS_DEPT_CODE in assign.pl
-- is inserted/updated into Person table by studentPerson.pl
INSERT INTO mail.banner_dept 
(SGBSTDN_DEPT_CODE, dept_code)
VALUES
('HU', 'HU');

-- Add new HU code to sap_dept
-- Used to map from SAP to Accman codes
-- SGBSTDN_DEPT_CODE used for mapping in StudentPerson.parseCourse
-- Also used for comparison with $SYRACCS_DEPT_CODE in assign.pl
-- is inserted/updated into Person table by studentPerson.pl

-- NB NEED VALUES

/*

NOT RUNNING SAP UPDATES AT THIS TIME

INSERT INTO mail.sap_dept 
(DEPT, dept_code, DEPT_desc)
VALUES
('AFEP', 'HU', 'Humanities, Languages & Social Sciences');

*/

/* Ran these updates to get the SAP_DEPT and HR_DEPARTMENTS tables in line with the DEPT table */
update hr_departments set description = 'Humanities, Languages & Social Sciences' where sap_dept_code = 'AFEP' limit 1;
update sap_dept set dept_code = 'HU', dept_desc = 'Humanities, Languages & Social Sciences' where dept = 'AFEP' limit 1;


-- DELETE CX code?
-- Don't think this is necessary as Banner will just stop sendin CX records...?
-- DELETE FROM mail.banner_dept WHERE SGBSTDN_DEPT_CODE = 'CX'


-- INSERT HU code into MAIL.DEPT 
-- used to set the AD department in 
-- ActiveDirectoryBaseProcessor.CreateExchangeMailbox
-- ActiveDirectoryBaseProcessor.updateADDetails
-- ActiveDirectoryUpdateUser.ProcessTransaction
-- NB NEED TO KNOW REAL VALUES
INSERT INTO mail.dept
(dept_code, aisDept_code, dept_name, full_name, deptType, active, site_code, defaultCredit, defaultquota)
VALUES
('HU', 'HU', 'Humanities, Languages & Social Sciences', 'Humanities, Languages & Social Sciences', 'school', 'Y', 'CW', '0', '0');


-- INSERT 'HU' into MAIL.HR_DEPARTMENT
-- used in to set userExt.Department and userExt.PhysicalDeliveryOfficeName
-- ActiveDirectoryBaseProcessor.updateADDepartment
--      HRDepartmentDAO.GetHRDepartment
-- ActiveDirectoryBaseProcessor.updateADDetails
--      HRDepartmentDAO.GetHRDepartment
-- if it cannot be matched use the mail.dept.dept_name instead

-- NB NEED VALUES

/*

NOT RUNNING SAP UPDATES AT THIS TIME

INSERT INTO mail.Hr_departments
(sap_dept_code,description, cost_code_area, cost_code)
VALUES
('AFEP', 'Humanities, Languages & Social Sciences', 'Staff Cost to School', 'EPGZ40')

*/

-- Update Mail.dept names based on the hr_departments table entries where available
-- or set here if not.

-- NB NEED CONFIRMATION OF THIS MAPPING

UPDATE mail.dept
SET dept_name = 'Salford Business School', 
full_name = 'Salford Business School'
WHERE
full_name = 'Salford Business School';

-- NB no SAP hr_departments entry taken from Matt's "paper of power"
UPDATE mail.dept
SET dept_name = 'Law School', 
full_name = 'Law School'
WHERE
full_name = 'Salford Law School';

UPDATE mail.dept
SET dept_name = 'Art & Design', 
full_name = 'Art & Design'
WHERE
full_name = 'School of Art and Design';

UPDATE mail.dept
SET dept_name = 'School of Env&LifeScience', 
full_name = 'School of Env&LifeScience'
WHERE
full_name = 'School of Environment and Life Sciences';

UPDATE mail.dept
SET dept_name = 'School of Health, Sport & Rehab', 
full_name = 'School of Health, Sport & Rehab'
WHERE
full_name = 'School of Health Care Professions';

UPDATE mail.dept
SET dept_name = 'Languages', 
full_name = 'Languages'
WHERE
full_name = 'School of Languages';

UPDATE mail.dept
SET dept_name = 'MediaMusic&Perf', 
full_name = 'MediaMusic&Perf'
WHERE
full_name = 'School of Media, Music and Performance';

UPDATE mail.dept
SET dept_name = 'School of Nursing & Midwifery', 
full_name = 'School of Nursing & Midwifery'
WHERE
full_name = 'School of Nursing';

UPDATE mail.dept
SET dept_name = 'School of the Built Environment', 
full_name = 'School of the Built Environment'
WHERE
full_name = 'School of the Built Environment';

UPDATE mail.dept
SET dept_name = 'School of ComScience&Eng', 
full_name = 'School of ComScience&Eng'
WHERE
full_name = 'School of Computing, Science and Engineering';


-- Update department_status to reflect status types available

-- A	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUA', 'HU', 'A', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- B	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUB', 'HU', 'B', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- C	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUC', 'HU', 'C', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- D	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUD', 'HU', 'D', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- E	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUE', 'HU', 'E', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- F	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUF', 'HU', 'F', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- G	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUG', 'HU', 'G', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- H	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUH', 'HU', 'H', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- I	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUI', 'HU', 'I', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- J	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUJ', 'HU', 'J', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- K	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUK', 'HU', 'K', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- L	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUL', 'HU', 'L', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- P	Postgraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUP', 'HU', 'P', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- S	Staff
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUS', 'HU', 'S', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- N	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUN', 'HU', 'N', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- R	Admin Account
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUR', 'HU', 'R', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- X	Departmental Account
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUX', 'HU', 'X', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- Q	Postgraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUQ', 'HU', 'Q', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- O	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUO', 'HU', 'O', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- M	Undergraduate
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUM', 'HU', 'M', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');
-- T	Temporary
INSERT INTO mail.department_status
(department_status_code, dept_code, status_code, active, defaultcontext, defaultserver, defaultvolume, defaultquota, viewlevel)
VALUES
( 'HUT', 'HU', 'T', 'Y', 'uis.ui.services.salford','ISD-IDMTESTING-1', 'STFA1',	'50',	'6');

-- Update the SAP-related department details (we guessed a bit at this)
update hr_departments set description = 'Humanities, Languages & Social Sciences' where sap_dept_code = 'AFEP' limit 1;
update sap_dept set dept_code = 'HU', dept_desc = 'Humanities, Languages & Social Sciences' where dept = 'AFEP' limit 1;

-- We need these new columns in banner_import for EmailForLife
alter table mail.banner_import add column SHRDGMR_DEGS_CODE varchar(2);
alter table mail.banner_import add column SHRDGMR_GRAD_DATE date;