-- CREATE OR REPLACE 
PROCEDURE prcts_regra_49(p_inf         IN OUT NOCOPY c_inf%rowtype)
AS
BEGIN
    IF 
			NVL(p_inf.INFST_VAL_CONT,0)    = 0
		AND NVL(p_inf.INFST_VAL_SERV,0)    <> 0
		AND NVL(p_inf.INFST_VAL_DESC,0)    <> 0
		AND NVL(p_inf.INFST_ISENTA_ICMS,0) <> 0
		AND NVL(p_inf.INFST_VAL_SERV,0)    = NVL(p_inf.INFST_ISENTA_ICMS,0) + NVL(p_inf.INFST_VAL_DESC,0)
		AND NVL(p_inf.INFST_BASE_ICMS,0)   = 0
		AND NVL(p_inf.INFST_VAL_ICMS,0)    = 0
		AND NVL(p_inf.INFST_OUTRAS_ICMS,0) = 0	

	THEN
      p_inf.update_reg         := 1;
      p_inf.var05              := SUBSTR('prcts_regra_49:' || p_inf.infst_val_cont || '|' || p_inf.INFST_ISENTA_ICMS || '>>' ||p_inf.var05,1,150);
      p_inf.INFST_VAL_CONT     := p_inf.INFST_ISENTA_ICMS;
	  v_inf_rules                 := fncts_add_var(p_ds_rules      =>  v_inf_rules, 
													 p_nm_var01      =>  p_inf.emps_cod,
													 p_nm_var02      =>  p_inf.fili_cod,
													 p_nm_var03      =>  p_inf.infst_serie,
													 p_nm_var04      =>  TO_CHAR(p_inf.infst_dtemiss,'YYYY-MM-DD'),
													 p_nm_var05      =>  '|R2015_49|',
													 p_nr_var02      =>  1);  	  
    END IF;
END;
--/