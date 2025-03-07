DELIMITER $$

USE `GOAUDITS`$$

DROP PROCEDURE IF EXISTS `SP_RPT_SUMMARY_147_DETAILS`$$

CREATE DEFINER=`dev`@`%` PROCEDURE `SP_RPT_SUMMARY_147_DETAILS`(IN pGUID BINARY(36),IN pUSER_NAME VARCHAR(60),IN pCLIENT_ID VARCHAR(100),IN pAUDIT_TYPE_ID VARCHAR(200),pLOCATION TEXT,IN pFROM_DATE VARCHAR(10),IN pTO_DATE VARCHAR(10),pReport_Type INT)
BEGIN
DECLARE pStatus VARCHAR(10);
DECLARE pAREA_ID INT DEFAULT 3;
DECLARE pCOMPANY_AVG DOUBLE(6,2) DEFAULT 0.00;
DECLARE TOP_BAKERY VARCHAR(50);
DECLARE TOP_SCORE DOUBLE(6,2) DEFAULT 0.00;
DECLARE BOTTOM_BAKERY VARCHAR(50);
DECLARE BOTTOM_SCORE DOUBLE(6,2) DEFAULT 0.00;
-- SELECT ANSWER INTO pAREA_ID FROM GA_DB_SETUP_ACCOUNT WHERE GUID=pGUID AND NAME="AreaManager" LIMIT 1;
  
IF pTO_DATE IS NULL OR pTO_DATE='' THEN
   SET pTO_DATE=CURRENT_DATE();
END IF;
IF pFROM_DATE IS NULL OR pFROM_DATE='' THEN
   SELECT DATE_ADD(pTO_DATE,INTERVAL -6 MONTH) INTO pFROM_DATE;
END IF;
IF pStatus IS NULL OR pStatus='' THEN
   SET pStatus = '2,3';
END IF;
IF pCLIENT_ID IS NULL OR pCLIENT_ID = '' OR pCLIENT_ID = '*'  THEN
   SELECT GROUP_CONCAT(CLIENT_ID) AS CLIENT_ID INTO pCLIENT_ID FROM GA_CLIENT_MT WHERE GUID = pGUID;
END IF;
IF pAUDIT_TYPE_ID IS NULL OR pAUDIT_TYPE_ID = '' OR pAUDIT_TYPE_ID = '*'  THEN   
   SELECT GROUP_CONCAT(CONCAT(CLIENT_ID,"|",AUDIT_TYPE_ID)) AS AUDIT_TYPE_ID INTO pAUDIT_TYPE_ID FROM GA_AUDITTYPE_MT 
   WHERE GUID = pGUID AND FIND_IN_SET(CLIENT_ID,pCLIENT_ID) AND ACTIVE=1; 
END IF;

IF pLOCATION IS NULL OR pLOCATION = '' OR pLOCATION = '*'  THEN
   SELECT GROUP_CONCAT(CONCAT(CLIENT_ID,"|",STORE_ID)) AS STORE_ID INTO pLOCATION FROM GA_STORE_MT 
   WHERE GUID = pGUID AND FIND_IN_SET(CLIENT_ID,pCLIENT_ID) AND ACTIVE=1; 
END IF;

DROP TEMPORARY TABLE IF EXISTS TMP_OPS_AUDIT_DETAILS;
CREATE TEMPORARY TABLE TMP_OPS_AUDIT_DETAILS AS
SELECT  AD.GUID,
		CM.CLIENT_ID,
		CM.CLIENT_NAME,
		AD.AUDIT_TYPE_ID,
		LM.STORE_ID,
		LM.STORE_NAME,
		AD.AUDIT_DATE,
		IFNULL(TM.AUDIT_TYPE_TITLE,TM.AUDIT_TYPE_NAME) AS AUDIT_TYPE_NAME,
		IFNULL(ASD.FINAL_SCORE,100) AS SCORE,
		CASE 
			WHEN AD.AUTO_FAIL=1 
					THEN "#FF0000" 
			ELSE IFNULL((SELECT GRADE_COLOR FROM GA_SCORERANGE_MST SM WHERE SM.GUID =ASD.GUID AND SM.CLIENT_ID =ASD.CLIENT_ID
					AND SM.AUDIT_GROUP_ID =1 AND SM.AUDIT_TYPE_ID=ASD.AUDIT_TYPE_ID AND ASD.FINAL_SCORE BETWEEN SM.MIN_VALUE AND SM.MAX_VALUE),CASE WHEN ASD.FINAL_SCORE< 90 THEN '#D91E18' ELSE '#00e640' END) END AS SCORE_COLOR,
					CASE WHEN AD.AUTO_FAIL=1 THEN "AUTO_FAIL" ELSE IFNULL((SELECT GRADE_TEXT FROM GA_SCORERANGE_MST SM WHERE SM.GUID =ASD.GUID AND SM.CLIENT_ID =ASD.CLIENT_ID
					AND SM.AUDIT_GROUP_ID =1 AND SM.AUDIT_TYPE_ID=ASD.AUDIT_TYPE_ID AND ASD.FINAL_SCORE BETWEEN SM.MIN_VALUE AND SM.MAX_VALUE),CASE WHEN ASD.FINAL_SCORE< 90 THEN '#D91E18' ELSE '#00e640' END) END AS GRADE_TEXT			
			,IFNULL((SELECT GTM.TAG_NAME FROM GA_LOCATION_TAG_MAP LTM 
			INNER JOIN GA_TAG_MT GTM ON GTM.GUID=LTM.GUID 
					AND GTM.CATEGORY_ID=LTM.CATEGORY_ID 
					AND GTM.TAG_ID = LTM.TAG_ID
		WHERE LTM.GUID=ASD.GUID AND LTM.CLIENT_ID=ASD.CLIENT_ID AND LTM.STORE_ID=ASD.STORE_ID
		AND LTM.CATEGORY_ID=pAREA_ID LIMIT 1),"None") AS REGION_NAME,
		IFNULL((SELECT GTM.TAG_ID FROM GA_LOCATION_TAG_MAP LTM 
			INNER JOIN GA_TAG_MT GTM ON GTM.GUID=LTM.GUID 
					AND GTM.CATEGORY_ID=LTM.CATEGORY_ID 
					AND GTM.TAG_ID = LTM.TAG_ID
		WHERE LTM.GUID=ASD.GUID AND LTM.CLIENT_ID=ASD.CLIENT_ID AND LTM.STORE_ID=ASD.STORE_ID
		AND LTM.CATEGORY_ID=pAREA_ID LIMIT 1),"None") AS REGION_ID
			 FROM GA_AUDITINF_DT AD 
			 INNER JOIN GA_AUDSTAT_DT ASD ON AD.GUID = ASD.GUID AND AD.UID=ASD.UID AND AD.CLIENT_ID= ASD.CLIENT_ID AND AD.AUDIT_GROUP_ID = ASD.AUDIT_GROUP_ID AND AD.AUDIT_TYPE_ID = ASD.AUDIT_TYPE_ID AND AD.STORE_ID=ASD.STORE_ID AND AD.AUDIT_DATE=ASD.AUDIT_DATE AND AD.SEQ_NO=ASD.SEQ_NO AND ASD.IS_DELETED=0  
			 INNER JOIN GA_CLIENT_MT CM ON AD.GUID = CM.GUID AND AD.CLIENT_ID= CM.CLIENT_ID AND CM.ACTIVE =1 
			 INNER JOIN  GA_AUDITGRP_MT GM  ON AD.GUID = GM.GUID AND AD.CLIENT_ID= GM.CLIENT_ID AND AD.AUDIT_GROUP_ID = GM.AUDIT_GROUP_ID AND GM.ACTIVE=1
			 INNER JOIN  GA_AUDITTYPE_MT TM ON AD.GUID = TM.GUID AND AD.CLIENT_ID= TM.CLIENT_ID AND AD.AUDIT_GROUP_ID = TM.AUDIT_GROUP_ID AND AD.AUDIT_TYPE_ID = TM.AUDIT_TYPE_ID  AND TM.ACTIVE=1
			 INNER JOIN  GA_STORE_MT LM ON AD.GUID = LM.GUID AND AD.CLIENT_ID= LM.CLIENT_ID AND AD.STORE_ID = LM.STORE_ID AND LM.SHOW_IN_ANALYTICS =1  AND LM.IS_TEST_LOCATION=0
			 WHERE AD.AUDIT_DATE  >= pFROM_DATE AND AD.AUDIT_DATE  <= pTO_DATE  
				AND  AD.GUID =pGUID 
				AND FIND_IN_SET(AD.CLIENT_ID,pCLIENT_ID)   
				AND FIND_IN_SET(CONCAT(AD.CLIENT_ID,"|",AD.AUDIT_TYPE_ID),pAUDIT_TYPE_ID)			
				AND FIND_IN_SET(CONCAT(ASD.CLIENT_ID,"|",ASD.STORE_ID),pLOCATION) 
				AND FIND_IN_SET(ASD.STATUS_ID,pStatus)
-- ORDER BY AVG(SCORE) DESC
; 	 
DROP TEMPORARY TABLE IF EXISTS TMP_OPS_AUDIT_DETAILS_TOTALS;
CREATE TEMPORARY TABLE TMP_OPS_AUDIT_DETAILS_TOTALS(GROUP_ID INT,GROUP_SORT_ORDER INT,SORT_ORDER INT,GROUP_NAME VARCHAR(100),AUDIT_TYPE_ID INT,AUDIT_TYPE_NAME VARCHAR(200),AUDIT_VALUE VARCHAR(100),NEW_ORDER INT);
SET @ORDER=0;
SET @NORDER=0;
INSERT INTO TMP_OPS_AUDIT_DETAILS_TOTALS(GROUP_ID,GROUP_SORT_ORDER,SORT_ORDER ,GROUP_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AUDIT_VALUE,NEW_ORDER)
SELECT 1,1,@ORDER:=@ORDER+1,"Totals of audits",AUDIT_TYPE_ID,AUDIT_TYPE_NAME,COUNT(*) AS AUDITS_COUNT,1 FROM TMP_OPS_AUDIT_DETAILS GROUP BY AUDIT_TYPE_ID,AUDIT_TYPE_NAME;
INSERT INTO TMP_OPS_AUDIT_DETAILS_TOTALS(GROUP_ID,GROUP_SORT_ORDER,SORT_ORDER ,GROUP_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AUDIT_VALUE,NEW_ORDER)
SELECT 1,1,@ORDER:=@ORDER+1,"Totals of audits",AUDIT_TYPE_ID,IFNULL(AD.AUDIT_TYPE_TITLE,AD.AUDIT_TYPE_NAME) AS AUDIT_TYPE_NAME,0,1 
		FROM GA_AUDITTYPE_MT AD
			WHERE AD.GUID=pGUID
			AND FIND_IN_SET(CONCAT(AD.CLIENT_ID,"|",AD.AUDIT_TYPE_ID),pAUDIT_TYPE_ID)
			AND NOT FIND_IN_SET(AD.AUDIT_TYPE_ID,(SELECT GROUP_CONCAT(DISTINCT AUDIT_TYPE_ID) FROM TMP_OPS_AUDIT_DETAILS))
			;
SET @ORDER=0;
SET @NORDER=0;
INSERT INTO TMP_OPS_AUDIT_DETAILS_TOTALS(GROUP_ID,GROUP_SORT_ORDER,SORT_ORDER ,GROUP_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AUDIT_VALUE,NEW_ORDER)
SELECT 2,2,@ORDER:=@ORDER+1,"Average Score",AUDIT_TYPE_ID,AUDIT_TYPE_NAME,CONCAT(ROUND(AVG(SCORE),0),"%") AS AVG,1 FROM TMP_OPS_AUDIT_DETAILS GROUP BY AUDIT_TYPE_ID,AUDIT_TYPE_NAME;
INSERT INTO TMP_OPS_AUDIT_DETAILS_TOTALS(GROUP_ID,GROUP_SORT_ORDER,SORT_ORDER ,GROUP_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AUDIT_VALUE,NEW_ORDER)
SELECT 2,2,@ORDER:=@ORDER+1,"Average Score",AUDIT_TYPE_ID,IFNULL(AD.AUDIT_TYPE_TITLE,AD.AUDIT_TYPE_NAME) AS AUDIT_TYPE_NAME,"" AS AVG,1
	FROM GA_AUDITTYPE_MT AD
			WHERE AD.GUID=pGUID
			AND FIND_IN_SET(CONCAT(AD.CLIENT_ID,"|",AD.AUDIT_TYPE_ID),pAUDIT_TYPE_ID)
			AND NOT FIND_IN_SET(AD.AUDIT_TYPE_ID,(SELECT GROUP_CONCAT(DISTINCT AUDIT_TYPE_ID) FROM TMP_OPS_AUDIT_DETAILS))
			;
			
-- TOP 5 Locations
SET @NORDER=0;
SET @ORDER=0;
INSERT INTO TMP_OPS_AUDIT_DETAILS_TOTALS(GROUP_ID,GROUP_SORT_ORDER,SORT_ORDER ,GROUP_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AUDIT_VALUE,NEW_ORDER)
SELECT 3,3,CASE WHEN NEW_ORDER=1 THEN @NORDER:=@NORDER+1 ELSE @NORDER END ,"Top 5 Locations",AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AUDIT_VALUE,NEW_ORDER  FROM
(
SELECT CASE WHEN @TMP_AUDIT_TYPE_ID=AUDIT_TYPE_ID THEN @ORDER:=@ORDER+1 ELSE @ORDER:=1 END AS NEW_ORDER
,@TMP_AUDIT_TYPE_ID:=AUDIT_TYPE_ID AS NEW_AUDIT_ID,A.* FROM 
(
SELECT "Top 5 Locations",AUDIT_TYPE_ID,AUDIT_TYPE_NAME,STORE_NAME AS AUDIT_VALUE FROM TMP_OPS_AUDIT_DETAILS 
GROUP BY AUDIT_TYPE_ID,AUDIT_TYPE_NAME,STORE_NAME ORDER BY AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AVG(SCORE) DESC 
) A
) B WHERE NEW_ORDER<=5
;

-- INSERT INTO TMP_OPS_AUDIT_DETAILS_TOTALS(GROUP_ID,GROUP_SORT_ORDER,SORT_ORDER ,GROUP_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AUDIT_VALUE,NEW_ORDER)
-- SELECT 3,3,@NORDER,"Top 5 Bakeries",AUDIT_TYPE_ID,AUDIT_TYPE_NAME,"" AS AUDIT_VALUE,0 AS NEW_ORDER
-- 	FROM GA_AUDITTYPE_MT AD
-- 			WHERE AD.GUID=pGUID
-- 			AND FIND_IN_SET(CONCAT(AD.CLIENT_ID,"|",AD.AUDIT_TYPE_ID),pAUDIT_TYPE_ID)
-- 			AND NOT FIND_IN_SET(AD.AUDIT_TYPE_ID,(SELECT GROUP_CONCAT(DISTINCT AUDIT_TYPE_ID) FROM TMP_OPS_AUDIT_DETAILS))
-- 			;
-- END OF TOP 5 BAKERIES
-- Lowest 5 Locations
SET @NORDER=0;
SET @ORDER=0;
INSERT INTO TMP_OPS_AUDIT_DETAILS_TOTALS(GROUP_ID,GROUP_SORT_ORDER,SORT_ORDER ,GROUP_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AUDIT_VALUE,NEW_ORDER)
SELECT 4,4,CASE WHEN NEW_ORDER=1 THEN @NORDER:=@NORDER+1 ELSE @NORDER END ,"Lowest 5 Locations",AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AUDIT_VALUE,NEW_ORDER  FROM
(
SELECT CASE WHEN @TMP_AUDIT_TYPE_ID=AUDIT_TYPE_ID THEN @ORDER:=@ORDER+1 ELSE @ORDER:=1 END AS NEW_ORDER
,@TMP_AUDIT_TYPE_ID:=AUDIT_TYPE_ID AS NEW_AUDIT_ID,A.* FROM 
(
SELECT "Lowest 5 Locations",AUDIT_TYPE_ID,AUDIT_TYPE_NAME,STORE_NAME AS AUDIT_VALUE FROM TMP_OPS_AUDIT_DETAILS 
GROUP BY AUDIT_TYPE_ID,AUDIT_TYPE_NAME,STORE_NAME ORDER BY AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AVG(SCORE) ASC 
) A
) B WHERE NEW_ORDER<=5 ORDER BY AUDIT_TYPE_ID,AUDIT_TYPE_NAME,NEW_ORDER DESC
;

-- INSERT INTO TMP_OPS_AUDIT_DETAILS_TOTALS(GROUP_ID,GROUP_SORT_ORDER,SORT_ORDER ,GROUP_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AUDIT_VALUE,NEW_ORDER)
-- SELECT 4,4,@NORDER,"Lowest 5 Bakeries",AUDIT_TYPE_ID,AUDIT_TYPE_NAME,"" AS AUDIT_VALUE,0 AS NEW_ORDER
-- 	FROM GA_AUDITTYPE_MT AD
-- 			WHERE AD.GUID=pGUID
-- 			AND FIND_IN_SET(CONCAT(AD.CLIENT_ID,"|",AD.AUDIT_TYPE_ID),pAUDIT_TYPE_ID)
-- 			AND NOT FIND_IN_SET(AD.AUDIT_TYPE_ID,(SELECT GROUP_CONCAT(DISTINCT AUDIT_TYPE_ID) FROM TMP_OPS_AUDIT_DETAILS))
-- 			;
-- END OF Lowest 5 BAKERIES
-- REGION 
-- SET @NORDER=0;
-- SET @ORDER=0;
-- SET @GORDER=0;
-- INSERT INTO TMP_OPS_AUDIT_DETAILS_TOTALS(GROUP_ID,GROUP_SORT_ORDER,SORT_ORDER ,GROUP_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AUDIT_VALUE,NEW_ORDER)
-- SELECT 5,REGION_ID+5,CASE WHEN NEW_ORDER=1 THEN @NORDER:=@NORDER+1 ELSE @NORDER END,REGION_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME,AUDIT_VALUE,1 FROM
-- (
-- SELECT CASE WHEN @TMP_AUDIT_TYPE_ID=AUDIT_TYPE_ID THEN @ORDER:=@ORDER+1 ELSE @ORDER:=1 END AS NEW_ORDER
-- ,@TMP_AUDIT_TYPE_ID:=AUDIT_TYPE_ID AS NEW_AUDIT_ID
-- ,REGION_ID
-- ,REGION_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME,CONCAT(ROUND(AVG(SCORE),0),"%") AS AUDIT_VALUE FROM TMP_OPS_AUDIT_DETAILS GROUP BY REGION_ID,REGION_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME
-- ORDER BY REGION_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME
-- ) A ORDER BY REGION_ID,REGION_NAME,AUDIT_TYPE_ID,AUDIT_TYPE_NAME
-- ;
-- REGION END

SELECT * FROM TMP_OPS_AUDIT_DETAILS_TOTALS;
END$$

DELIMITER ;