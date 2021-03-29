/*
truncate table mailtest.banner_import;

ALTER TABLE mailtest.banner_import
	ADD COLUMN GOREMAL_EMAIL_ADDRESS varchar(128) DEFAULT NULL,
	ADD COLUMN MOBILE_NUMBER varchar(22) DEFAULT NULL;

ALTER TABLE mailtest.person
	ADD COLUMN personal_email varchar(128) DEFAULT NULL,
	ADD COLUMN mobile_number varchar(22) DEFAULT NULL;
*/

INSERT INTO mailtest.banner_import
(
	SPRIDEN_PIDM, SPRIDEN_ID, SPRIDEN_LAST_NAME, SPRIDEN_FIRST_NAME, SPRIDEN_MI,
	SPBPERS_BIRTH_DATE, SPBPERS_SEX, SPBPERS_NAME_PREFIX,
	SGBSTDN_TERM_CODE_EFF, SGBSTDN_STST_CODE, SGBSTDN_LEVL_CODE, SGBSTDN_STYP_CODE, SGBSTDN_DEGC_CODE_1,
	SGBSTDN_MAJR_CODE_1, SGBSTDN_BLCK_CODE, SGBSTDN_DEPT_CODE, SGBSTDN_PROGRAM_1,
	SFBETRM_AR_IND, SFBETRM_ADD_DATE, SFBETRM_ESTS_CODE,
	SKBHINS_ENDDATE,
	SHRDGMR_DEGS_CODE, SHRDGMR_GRAD_DATE,
	GOREMAL_EMAIL_ADDRESS, MOBILE_NUMBER
) VALUES (
	350904, '@00318273', 'Al-Musalahi', 'Amjed Shawqi', null,
	'1979-05-08', 'M', 'Mr',
	'201610', 'AS', 'PG', 'N', 'MSR',
	'C790', 'MSR/BC1/F1', 'EL', 'MSR/BC1/F',
	'Y', '2015-11-16', 'RE', 
	null,
	'SO', null,
	null, '07460701011'
	
);

select * from mailtest.banner_import;

select * from mailtest.person_change 
where importid = 25946 -- and personid = 180058 
order by field_name asc;

select * from mailtest.person where rollnumber like '%318273%'; -- 180058
select * from mailtest.transactions where trid = 9986340;
select * from mailtest.transaction_params where trid = 9986340;
