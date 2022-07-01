libname bb "D:\연구\인공지능\Generalizable model\Preprocessing";
libname main "D:\연구\인공지능\VigiBase Extract Case Level 2022 Mar 1\rawdata_main";
libname sub "D:\연구\인공지능\VigiBase Extract Case Level 2022 Mar 1\rawdata_sub";
libname who "D:\연구\인공지능\VigiBase Extract Case Level 2022 Mar 1\rawdata_who";

data bb.pem1;
	set who.substance;
	where substance_name contains "Pembrolizumab" 
			  or substance_name contains "pembrolizumab";
run;

proc sql;
	create table bb.pem2 as
	select distinct *
	from who.ing
	where substance_id in (select distinct substance_id from bb.pem1);
quit;

proc sql;
	create table bb.pem3 as
	select distinct *
	from who.pp
	where Pharmproduct_Id in (select distinct Pharmproduct_Id from bb.pem2);
quit;

proc sql;
	create table bb.pem4 as
	select distinct drug_name, Drug_record_number
	from who.mp
	where Medicinalprod_Id in (select distinct Medicinalprod_Id from bb.pem3);
quit;

proc sql;
	create table bb.pem5 as
	select distinct umcreportid, drug_id, drecNo, Basis 
	from main.drug
	where drecno in (select distinct Drug_record_number from bb.pem4) and basis ^= "2";
quit;


data adr;
	set main.adr;
	if outcome = "-" then outcome_num = 6; /*outcome=6 결측치*/
	else outcome_num = outcome*1;
	drop outcome;
run;
	
proc sql;
	create table bb.drug_ae_pair as
	select distinct a.*, b.*
	from bb.pem5 as a left join adr as b on a.umcreportid = b.umcreportid;
quit;

data link;
	set main.link;
	if TimeToOnsetMin in (" ", "-") then tto_min = .;
	else tto_min = TimeToOnsetMin;
	if TimeToOnsetMax in (" ", "-") then tto_max = .;
	else tto_max = TimeToOnsetMax;
	
	if tto_min =. and tto_max =. then tto = .;
	else if tto_min =. then tto = .;
	else if tto_max =. then tto = .;
	else if (tto_max + tto_min)/2 = int((tto_max + tto_min)/2) then tto = (tto_max + tto_min)/2;
	else tto = int((tto_max + tto_min)/2) +1;

	if tto ^= . and tto < 0 then delete;

	if rechallenge1 = "1" and rechallenge2 ="1" then rechall_pos = 1;
	else 	rechall_pos = 0;

	if dechallenge1 in ("1", "2") and dechallenge2 = "1" then dechall_pos = 1;
	else dechall_pos = 0;
	
	if tto >= 0 then tto_pos = 1;
	else tto_pos = 0;

	drop tto_min tto_max TimeToOnsetMin TimeToOnsetMax rechallenge1 rechallenge2 
			dechallenge1 dechallenge2 tto;
run;

proc sql;
	create table bb.drug_ae_pair2 as
	select a.*, b.*
	from bb.drug_ae_pair as a inner join link as b on a.adr_id = b.adr_id AND a.drug_id = b.drug_id
	where meddra_id ^= 0;
quit;

proc sql;
	create table bb.drug_ae_pair3 as
	select a.*, b.pt_code
	from bb.drug_ae_pair2 as a left join main.meddra_v24 as b on a.meddra_id = b.llt;
quit;

proc sort data=bb.drug_ae_pair3 out=bb.drug_ae_pair4 nodupkey;
	by umcreportid drug_id basis adr_id meddra_id outcome_num;
run;

data demo;
	set main.demo;

	if gender = "-" then sex = 0; /*sex=0은 결측치*/
	else sex = gender*1;

	agg = agegroup*1;/*agg=9 결측치*/

	
	if type = "-" then report_type = 4;
	else report_type = type*1;

	reporting = substr(FirstDateDatabase,1,4)*1;

	region_num = region*1;

	drop agegroup -- firstdatedatabase;
run;

proc sql;
	create table bb.master as
	select a.*, b.*
	from bb.drug_ae_pair4 as a left join demo as b on a.umcreportid = b.umcreportid;
quit;


data srce;
	set main.srce;
	notifier = type*1;
run;

proc sql;
	create table bb.master1 as
	select a.*, b.notifier
	from bb.master as a left join srce as b on a.umcreportid = b.umcreportid;
quit;

data out;
	set main.out;
	if serious in ("-","Y") then serious_num = 1;
	else serious_num = 0;
	if seriousness = "-" then serious_outcome = 0;
	else serious_outcome = seriousness*1;
	drop seriousness serious;
run;

proc sql;
	create table bb.master2 as
	select a.*, b.*
	from bb.master1 as a left join out as b on a.umcreportid = b.umcreportid;
quit;

proc sql;
	create table bb.prepro as
	select distinct pt_code, count(umcreportid) as num_case
	from bb.master2
	group by pt_code
	having num_case >= 3
	order by calculated num_case desc;
quit;


data notifier;
	set bb.master2;
	if notifier ^= 5;
run;

proc sql;
	create table notifier as
	select distinct pt_code, count(umcreportid) as healthcare_pro
	from notifier
	group by pt_code;
quit;


data report_type_study;
	set bb.master2;
	if report_type in (2,5);
run;

proc sql;
	create table report_type_study as
	select distinct pt_code, count(umcreportid) as study_report
	from report_type_study
	group by pt_code;
quit;


proc sql;
	create table temp_pos as
	select distinct pt_code, count(umcreportid) as temp_pos
	from bb.master2
	where tto_pos = 1
	group by pt_code;
quit;

proc sql;
	create table rechall_pos as
	select distinct pt_code, count(umcreportid) as rechall_pos
	from bb.master2
	where rechall_pos = 1
	group by pt_code;
quit;

proc sql;
	create table dechall_pos as
	select distinct pt_code, count(umcreportid) as dechall_pos
	from bb.master2
	where dechall_pos = 1
	group by pt_code;
quit;

proc sql;
	create table bb.prepro1 as
	select a.*, b.healthcare_pro, c.study_report, d.temp_pos, e.rechall_pos, f.dechall_pos
	from bb.prepro as a left join notifier as b on a.pt_code = b.pt_code
									left join report_type_study as c on a.pt_code = c.pt_code
									left join temp_pos as d on a.pt_code = d.pt_code
									left join rechall_pos as e on a.pt_code = e.pt_code
									left join dechall_pos as f on a.pt_code = f.pt_code
	order by num_case desc;
quit;

data bb.master2;
	set bb.master2;
	if agg in (1,2,3,4) then agegroup = 1;
	else if agg in (5,6) then agegroup = 2;
	else if agg in (7,8) then agegroup = 3;
	else agegroup = 4;
run;

%macro agegroup;
	%do int = 1 %to 4;
	data age&int.;
		set bb.master2;
		if agegroup = &int.;
	run;

	proc sql;
		create table agg&int. as
		select distinct pt_code, count(umcreportid) as agg&int.
		from age&int.
		group by pt_code;
	quit;
	%end;
%mend;
%agegroup;


proc sql;
	create table bb.prepro2 as
	select a.*, b.agg1, c.agg2, d.agg3
	from bb.prepro1 as a left join agg1 as b on a.pt_code = b.pt_code
							 left join agg2 as c on a.pt_code = c.pt_code
							 left join agg3 as d on a.pt_code = d.pt_code
	order by num_case desc;
quit; 


%macro sex;
	%do int = 1 %to 2;
	data sex&int.;
		set bb.master2;
		if sex = &int.;
	run;

	proc sql;
		create table sex&int. as
		select distinct pt_code, count(umcreportid) as sex&int.
		from sex&int.
		group by pt_code;
	quit;
	%end;
%mend;
%sex;

proc sql;
	create table bb.prepro3 as
	select a.*, b.sex1, c.sex2
	from bb.prepro2 as a left join sex1 as b on a.pt_code = b.pt_code
					 				 left join sex2 as c on a.pt_code = c.pt_code
	order by num_case desc;
quit; 


proc sql;
	create table serious as
	select distinct pt_code,  count(umcreportid) as serious_ae
	from bb.master2
	where serious_num = 1
	group by pt_code;
quit;

proc sql;
	create table bb.prepro4 as
	select a.*, b.serious_ae
	from bb.prepro3 as a left join serious as b on a.pt_code = b.pt_code
	order by num_case desc;
quit;


data bb.master2;
	set bb.master2;
	if serious_outcome in (1,2) then seriousness = 1;
	else if serious_outcome in (3,6) then seriousness = 2;
	else seriousness = 3;
run;

%macro seriousness;
	%do int = 1 %to 3;
	data seriousness&int.;
		set  bb.master2;
		if seriousness = &int.;
	run;

	proc sql;
		create table seriousness&int. as
		select distinct pt_code, count(umcreportid) as seriousness&int.
		from seriousness&int.
		group by pt_code;
	quit;
	%end;
%mend;
%seriousness;


proc sql;
	create table bb.prepro5 as
	select distinct a.*, b.seriousness1, c.seriousness2, d.seriousness3
	from bb.prepro4 as a left join seriousness1 as b on a.pt_code = b.pt_code /*Death, Life threatening*/
							 left join seriousness2 as c on a.pt_code = c.pt_code /*Caused/Prolonged Hospitalization, Other*/
							 left join seriousness3 as d on a.pt_code = d.pt_code /*Disabling/Incapacitating/Cogenital anomaly/Birth defect*/
	order by num_case desc;
quit; 

data bb.master2;
	set bb.master2;
	if outcome_num in (1,2) then outcome = 1;
	else if outcome_num in (3,4) then outcome = 2;
	else if outcome_num in (5,7) then outcome = 3;/*outcome=3 Fatal/Death*/
	else outcome = 0;
run;


%macro outcome;
	%do int = 1 %to 3;
	data outcome&int.;
		set bb.master2;
		if outcome = &int.;
	run;

	proc sql;
		create table outcome&int. as
		select distinct pt_code, count(distinct umcreportid) as outcome&int.
		from outcome&int.
		group by pt_code;
	quit;
	%end;
%mend;
%outcome;

proc sql;
	create table bb.prepro6 as
	select distinct a.*, b.outcome1, c.outcome2, d.outcome3
	from bb.prepro5 as a left join outcome1 as b on a.pt_code = b.pt_code 
							 		  left join outcome2 as c on a.pt_code = c.pt_code 
									  left join outcome3 as d on a.pt_code = d.pt_code 
			
	order by num_case desc;
quit; 


proc sql;
	create table ddi as
	select distinct pt_code,  count(umcreportid) as interacting
	from bb.master2
	where basis = "3"
	group by pt_code;
quit;

proc sql;
	create table bb.prepro7 as
	select distinct a.*, b.interacting
	from bb.prepro6 as a left join ddi as b on a.pt_code = b.pt_code
	order by num_case desc;
quit; 


/***Vigigrade 생성***/
data link;
	set main.link;

	if TimeToOnsetMin in (" ","-") then tto_min =.;
	else tto_min = TimeToOnsetMin;
	if TimeToOnsetMax in (" ","-") then tto_max=.;
	else tto_max = TimeToOnsetMax;

	if tto_min =. and tto_max =. then tto=.;
	else if tto_min =. then tto =.;
	else if tto_max =. then tto =.;
	else if (tto_max+tto_min)/2 = int((tto_max+tto_min)/2) then tto = (tto_max+tto_min)/2;
	else tto = int((tto_max+tto_min)/2)+1;

run;

data pem_ae_pair;
	set bb.drug_ae_pair4;
run;

proc sql;
	create table pem_ae_pair2 as
	select a.*, b.amount, b.amountU, b.frequency, b.frequencyU
	from pem_ae_pair as a left join main.drug as b on a.umcreportid = b.umcreportid
																			  AND a.drug_id = b.drug_id
																			  AND a.drecno = b.drecno;
quit; 

proc sql;
	create table pem_ae_pair3 as
	select a.*, b.indication
	from pem_ae_pair2 as a left join main.ind as b on a.drug_id = b.drug_id;
quit; 

proc sql;
	create table pem_ae_pair4 as
	select a.*, b.agegroup, b.gender, b.type, b.region
	from pem_ae_pair3 as a left join main.demo as b on a.umcreportid = b.umcreportid;
quit;

proc freq data=pem_ae_pair4;
	table region;
run;

data pem_ae_pair5;
	set pem_ae_pair4;
	agg = agegroup*1; /*agg=9는 결측*/
	if gender in ("-", "0") then sex = 0;/*gender=0은 결측*/
	else sex = gender*1;
	if type in ("-","4") then report_tp = 4;
	else report_tp = type*1;/*report_tp=4은 결측*/
	country = region*1;
	drop agegroup -- region;
run;

proc sql;
	create table pem_ae_pair6 as
	select a.*, b.type
	from pem_ae_pair5 as a left join main.srce as b on a.umcreportid = b.umcreportid;
quit;

data pem_ae_pair7;
	set pem_ae_pair6;
	notifier = type*1;
	drop type;
run;

data pem_ae_pair8;
	set pem_ae_pair7;
	if notifier =. then notifier = 0; /*notifier=0은 결측*/
run;

proc sql;
	create table pem_ae_pair9 as
	select a.*, b.tto
	from pem_ae_pair8 as a left join link as b on a.adr_id = b.adr_id AND a.drug_id = b.drug_id;
quit;

/****Vigigrade 계산****/
data vigigrade;
   set pem_ae_pair9;

   if tto = . then vigi_tto = 0.5;
   else if 30 <= tto < 120 then vigi_tto = 1;
   else if -30 <= tto < 30 then vigi_tto = 0.9;
   else vigi_tto = 0.7;

   if Indication = " " then vigi_indi = 0.7;
   else vigi_indi = 1;

   if Outcome_num = 6 then vigi_outcome = 0.7;
   else vigi_outcome = 1;

   if sex = 0 then vigi_sex = 0.7;
   else vigi_sex = 1;

   if agg = 9 then vigi_age = 0.7;
   else vigi_age = 1;

   if Amount not in ("-", " ") and AmountU not in ("-", " ") and frequency not in ("-", " ") and frequencyU not in ("-", " ") 
   then vigi_dose = 1;
   else vigi_dose = 0.9;

   vigi_country = 1;

   if notifier = 0 then vigi_reporter = 0.9;
   else vigi_reporter = 1;

   if report_tp = 4 then vigi_report_tp = 0.9;
   else vigi_report_tp = 1;

   vigigrade = vigi_tto*vigi_indi*vigi_outcome*vigi_sex*vigi_age*vigi_dose*vigi_country*vigi_reporter*vigi_report_tp;
   
run;

data vigigrade1;
	set vigigrade;
	if vigigrade >= 0.8 then vigi_qual1 = 1;
	else vigi_qual1 = 0;
	if 0.8 > vigigrade >= 0.5 then vigi_qual2 = 1;
	else vigi_qual2=0;
run;

proc sql;
	create table bb.vigigrade as
	select distinct pt_code, sum(vigi_qual1) as vigi80, sum(vigi_qual2) as vigi50to80
	from vigigrade1
	group by pt_code;
quit; 


/***Pregnancy 생성***/
proc import out = bb.pregnancy
	datafile = 'D:\연구\인공지능\Generalizable model\Preprocessing\Table_pem'
	DBMS = xlsx replace;
	sheet = "Pregnancy";
run;

proc sql;
	create table preg_pem as
	select distinct umcreportid
	from bb.drug_ae_pair4
	where pt_code in (select distinct pt_code from bb.pregnancy);
quit;

proc sql;
	create table preg_pem1 as
	select *
	from bb.drug_ae_pair4
	where umcreportid in (select distinct umcreportid from preg_pem);
quit;

proc sql;
	create table bb.preg_pem as
	select distinct pt_code, count(umcreportid) as preg
	from preg_pem1
	where pt_code not in (select distinct pt_code from bb.pregnancy)
	group by pt_code;
quit;


/***Reactions occurring in different patterns of use***/
proc import out = bb.different_use
	datafile = 'D:\연구\인공지능\Generalizable model\Preprocessing\Table_pem'
	DBMS = xlsx replace;
	sheet = "Different_pattern";
run;

proc sql;
	create table dif_pem as
	select distinct umcreportid
	from bb.drug_ae_pair4
	where pt_code in (select distinct pt_code from bb.different_use);
quit;

proc sql;
	create table dif_pem1 as
	select *
	from bb.drug_ae_pair4
	where umcreportid in (select distinct umcreportid from dif_pem);
quit;

proc sql;
	create table bb.dif_pem as
	select distinct pt_code, count(umcreportid) as dif
	from dif_pem1
	where pt_code not in (select distinct pt_code from dif_pem)
	group by pt_code;
quit;
/*같이 보고된 건이 0*/

/**** ROR 값 계산코드****/
proc sql;
	create table pem_code as
	select distinct drecno
	from bb.pem5;
quit;

data pem_code;
	set pem_code;
	study_drug = 1;
run;

proc sql;
	create table drug as
	select distinct a.umcreportid, a.drug_id, a.drecno, b.study_drug
	from main.drug as a left join pem_code as b on a.drecno = b.drecno
	where basis ^= "2";
quit;

data demo_pem;
	set demo;
	if reporting >= 2015;
run;

proc sql;
	create table drug_demo as
	select distinct a.*, b.*
	from drug as a inner join demo_pem as b on a.umcreportid = b.umcreportid;
quit;

proc sql;
	create table adr as
	select distinct a.*, b.pt_code
	from adr as a left join main.meddra_v24 as b on a.meddra_id = b.llt
	where meddra_id ^= 0;
quit;

proc sql;
	create table ae_list as
	select distinct a.pt_code
	from bb.master2 as a inner join bb.prepro as b on a.pt_code = b.pt_code
	order by pt_code;
quit;

data ae_list;
	set ae_list;
	n+1;
run;

proc sql;
	create table adr_pt_code as
	select a.*, b.n
	from adr as a inner join ae_list as b on a.pt_code = b.pt_code;
quit;

proc sql;
	create table ror_input as
	select a.*, b.adr_id, b.pt_code, b.n
	from drug_demo as a inner join adr_pt_code as b on a.umcreportid = b.umcreportid;
quit;


data pem_comparator;
	set sub.substance;
	where Substance_name contains "fluorouracil" or Substance_name contains "Fluorouracil"
			 or Substance_name contains "Bevacizumab" or Substance_name contains "bevacizumab"
			 or Substance_name contains "Brentuximab" or Substance_name contains "brentuximab"
			 or Substance_name contains "Carboplatin" or Substance_name contains "carboplatin"
			 or Substance_name contains "Cetuximab" or Substance_name contains "cetuximab"
			 or Substance_name contains "Cisplatin" or Substance_name contains "cisplatin"
			 or Substance_name contains "Dacarbazine" or Substance_name contains "dacarbazine"
			 or Substance_name contains "Docetaxel" or Substance_name contains "docetaxel"
			 or Substance_name contains "Doxorubicin" or Substance_name contains "doxorubicin"
			 or Substance_name contains "Gemcitabine" or Substance_name contains "gemcitabine"
			 or Substance_name contains "Ipilimumab" or Substance_name contains "ipilimumab"
			 or Substance_name contains "Irinotecan" or Substance_name contains "irinotecan"
			 or Substance_name contains "Methotrexate" or Substance_name contains "methotrexate"
			 or Substance_name contains "Oxaliplatin" or Substance_name contains "oxaliplatin"
			 or Substance_name contains "Paclitaxel" or Substance_name contains "paclitaxel"
			 or Substance_name contains "Pemetrexed" or Substance_name contains "pemetrexed"
			 or Substance_name contains "Sunitinib" or Substance_name contains "sunitinib"
			 or Substance_name contains "Temozolomide" or Substance_name contains "temozolomide"
			 or Substance_name contains "Vinflunine" or Substance_name contains "vinflunine";
run;


proc sql;
	create table pem_comparator1 as
	select distinct *
	from who.ing
	where substance_id in (select distinct substance_id from pem_comparator);
quit;

proc sql;
	create table pem_comparator2 as
	select distinct *
	from who.pp
	where Pharmproduct_Id in (select distinct Pharmproduct_Id from pem_comparator1);
quit;

proc sql;
	create table pem_comparator3 as
	select distinct  Drug_record_number
	from who.mp
	where Medicinalprod_Id in (select distinct Medicinalprod_Id from pem_comparator2);
quit;

proc sql;
	create table ror_input1 as
	select *
	from ror_input
    where study_drug ^=. or drecno in (select distinct drug_record_number from pem_comparator3);
quit;

proc stdize data=ror_input1 out=ror_input2 reponly missing=0;
run;


%macro ROR;

%do integer=1 %to 500;

data ROR_&integer.;
	set ror_input2;
	if n = &integer. then target =1;
	else target = 0;
	ods output OddsRatios = bb.or_&integer. ;

	proc logistic data=ROR_&integer. desc;
		class study_drug(ref='0');
		model target= study_drug agg sex region_num reporting;
	run; 


data bb.or_&integer.;
	set bb.or_&integer.;
	if Effect ="study_drug 1 vs 0";
	n=&integer.;
run;

proc datasets nolist;
	delete ROR_&integer.;
quit;

%end;

data bb.adjusted_or1;
	set bb.or_1-bb.or_500;
run;

proc datasets nolist lib=bb;
	delete or_1-or_500;
quit;

%mend;

%ROR;

%macro ROR;

%do integer=501 %to 1000;

data ROR_&integer.;
	set ror_input2;
	if n = &integer. then target =1;
	else target = 0;
	ods output OddsRatios = bb.or_&integer. ;

	proc logistic data=ROR_&integer. desc;
		class study_drug(ref='0');
		model target= study_drug agg sex region_num reporting;
	run; 


data bb.or_&integer.;
	set bb.or_&integer.;
	if Effect ="study_drug 1 vs 0";
	n=&integer.;
run;

proc datasets nolist;
	delete ROR_&integer.;
quit;

%end;

data bb.adjusted_or2;
	set bb.or_501-bb.or_1000;
run;

proc datasets nolist lib=bb;
	delete or_501-or_1000;
quit;

%mend;

%ROR;

%macro ROR;

%do integer=1001 %to 1500;

data ROR_&integer.;
	set ror_input2;
	if n = &integer. then target =1;
	else target = 0;
	ods output OddsRatios = bb.or_&integer. ;

	proc logistic data=ROR_&integer. desc;
		class study_drug(ref='0');
		model target= study_drug agg sex region_num reporting;
	run; 


data bb.or_&integer.;
	set bb.or_&integer.;
	if Effect ="study_drug 1 vs 0";
	n=&integer.;
run;

proc datasets nolist;
	delete ROR_&integer.;
quit;

%end;

data bb.adjusted_or3;
	set bb.or_1001-bb.or_1500;
run;

proc datasets nolist lib=bb;
	delete or_1001-or_1500;
quit;

%mend;

%ROR;

%macro ROR;

%do integer=1501 %to 2000;

data ROR_&integer.;
	set ror_input2;
	if n = &integer. then target =1;
	else target = 0;
	ods output OddsRatios = bb.or_&integer. ;

	proc logistic data=ROR_&integer. desc;
		class study_drug(ref='0');
		model target= study_drug agg sex region_num reporting;
	run; 


data bb.or_&integer.;
	set bb.or_&integer.;
	if Effect ="study_drug 1 vs 0";
	n=&integer.;
run;

proc datasets nolist;
	delete ROR_&integer.;
quit;

%end;

data bb.adjusted_or4;
	set bb.or_1501-bb.or_2000;
run;

proc datasets nolist lib=bb;
	delete or_1501-or_2000;
quit;

%mend;

%ROR;

%macro ROR;

%do integer=2001 %to 2429;

data ROR_&integer.;
	set ror_input2;
	if n = &integer. then target =1;
	else target = 0;
	ods output OddsRatios = bb.or_&integer. ;

	proc logistic data=ROR_&integer. desc;
		class study_drug(ref='0');
		model target= study_drug agg sex region_num reporting;
	run; 


data bb.or_&integer.;
	set bb.or_&integer.;
	if Effect ="study_drug 1 vs 0";
	n=&integer.;
run;

proc datasets nolist;
	delete ROR_&integer.;
quit;

%end;

data bb.adjusted_or5;
	set bb.or_2001-bb.or_2429;
run;

proc datasets nolist lib=bb;
	delete or_2001-or_2429;
quit;

%mend;

%ROR;

data bb.adjusted_or;
	set bb.adjusted_or1 - bb.adjusted_or5;
run;

proc sql;
	create table ae_list_ror as
	select a.pt_code, b.LowerCL
	from ae_list as a left join bb.adjusted_or as b on a.n = b.n;
quit;

proc sql;
	create table bb.prepro9 as
	select a.*, b.LowerCL
	from bb.prepro8 as a left join ae_list_ror as b on a.pt_code = b.pt_code;
quit;

proc sql;
	create table bb.prepro10 as
	select a.*, b.*
	from bb.prepro9 as a left join bb.vigigrade as b on a.pt_code = b.pt_code;
quit;

proc sql;
	create table bb.prepro11 as
	select a.*, b.preg
	from bb.prepro10 as a left join bb.preg as b on a.pt_code = b.pt_code;
quit;

proc sql;
	create table bb.prepro12 as
	select a.*, b.dif
	from bb.prepro11 as a left join bb.dif_pem as b on a.pt_code = b.pt_code;
quit;

proc stdize data= bb.prepro12 out=bb.prepro13 reponly missing=0;
run;


/**** EBGM 값 계산코드****/
data bb.ebgm_input;
	set ror_input2;
	keep umcreportid drecno study_drug pt_code;
run;

data egbm_input1;
	set bb.ebgm_input(firstobs=1 obs=500000);
run;

data egbm_input2;
	set bb.ebgm_input(firstobs=500001 obs=1000000);
run;

data egbm_input3;
	set bb.ebgm_input(firstobs=1000001 obs=1500000);
run;

data egbm_input4;
	set bb.ebgm_input(firstobs=1500001 obs=2000000);
run;

data egbm_input5;
	set bb.ebgm_input(firstobs=2000001 obs=2500000);
run;

data egbm_input6;
	set bb.ebgm_input(firstobs=2500001 obs=3000000);
run;

	
proc export data=egbm_input1
	outfile = 'D:\연구\인공지능\Generalizable model\Preprocessing\egbm_input1'
	DBMS = xlsx replace;
run;

proc export data=egbm_input2
	outfile = 'D:\연구\인공지능\Generalizable model\Preprocessing\egbm_input2'
	DBMS = xlsx replace;
run;

proc export data=egbm_input3
	outfile = 'D:\연구\인공지능\Generalizable model\Preprocessing\egbm_input3'
	DBMS = xlsx replace;
run;

proc export data=egbm_input4
	outfile = 'D:\연구\인공지능\Generalizable model\Preprocessing\egbm_input4'
	DBMS = xlsx replace;
run;

proc export data=egbm_input5
	outfile = 'D:\연구\인공지능\Generalizable model\Preprocessing\egbm_input5'
	DBMS = xlsx replace;
run;

proc export data=egbm_input6
	outfile = 'D:\연구\인공지능\Generalizable model\Preprocessing\egbm_input6'
	DBMS = xlsx replace;
run;

