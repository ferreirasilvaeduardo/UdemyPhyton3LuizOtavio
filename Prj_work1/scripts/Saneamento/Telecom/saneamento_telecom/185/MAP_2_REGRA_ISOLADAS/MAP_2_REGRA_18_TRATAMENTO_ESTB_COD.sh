#!/bin/bash
PARTICAO_NF=${1}
PARTICAO_INF=${2}
ROWID_CP=${3}
sqlplus -S /nolog <<@EOF >> ${SCRIPT}_${PARTICAO_NF}_${PROCESSO}.log 2>> ${SCRIPT}_${PARTICAO_NF}_${PROCESSO}.err
CONNECT ${STRING_CONEXAO}
set define off;
SET SERVEROUTPUT ON SIZE 1000000;
set timing on;
SPOOL  ${SPOOL_FILE} 
var v_st_processamento    VARCHAR2(50)   = 'Em Processamento'
var v_msg_erro            VARCHAR2(4000) = 'MAP_2_REGRA_18_TRATAMENTO_ESTB_COD'
var exit_code             NUMBER         = 0
var v_qtd_processados     NUMBER         = 0
var v_qtd_atu_nf          NUMBER         = 0
var v_qtd_atu_inf         NUMBER         = 0
var v_qtd_ins_inf         NUMBER         = 0
var v_qtd_atu_cli         NUMBER         = 0
var v_qtd_atu_comp        NUMBER         = 0
var v_qtd_reg_paralizacao NUMBER         = 0

WHENEVER OSERROR EXIT 1;
WHENEVER SQLERROR EXIT 2;
PROMPT
PROMPT MAP_2_REGRA_18_TRATAMENTO_ESTB_COD
PROMPT ### Inicio do processo ${0} - ${SERIE}  ###
PROMPT

DECLARE   

 
    CURSOR c_inf
       IS
	SELECT  /*+ parallel(15) */
			inf.rowid             rowid_inf,   
			inf.*	
	FROM    openrisow.item_nftl_serv      PARTITION (${PARTICAO_INF}) inf,  
			openrisow.mestre_nftl_serv    PARTITION (${PARTICAO_NF})  nf   
	WHERE   ${FILTRO}
	      AND UPPER(TRANSLATE(nf.mnfst_serie,'x ','x')) IN ('1', 'UT') 
	      AND UPPER(TRANSLATE(nf.mnfst_serie,'x ','x')) NOT IN ('AS1', 'AS2', 'AS3', 'T1')  
	      AND (UPPER(TRANSLATE(nf.mnfst_serie,'x ','x')) NOT IN ('ASS') OR nf.mnfst_dtemiss >= TO_DATE('01/04/2017','DD/MM/YYYY'))
		  AND nf.mnfst_dtemiss >= TO_DATE('01/01/2015','DD/MM/YYYY') AND nf.mnfst_dtemiss <= TO_DATE('31/12/2016','DD/MM/YYYY')	
		  AND inf.emps_cod                                               = nf.emps_cod
		  AND inf.fili_cod                                               = nf.fili_cod
		  AND inf.infst_serie                                            = nf.mnfst_serie
		  AND inf.infst_num                                              = nf.mnfst_num
		  AND inf.infst_dtemiss                                          = nf.mnfst_dtemiss
		  AND inf.mdoc_cod                                               = nf.mdoc_cod	  
          -- Nro da Regra 18) Tratamento ESTB_COD
		  AND ( NVL(TRIM(inf.ESTB_COD),' ')                        = '0' );
    v_inf                 c_inf%ROWTYPE;
	
    v_ds_etapa            VARCHAR2(4000);
    PROCEDURE prc_tempo(p_ds_ddo IN VARCHAR2) AS 
    BEGIN
      v_ds_etapa := substr(p_ds_ddo || ' >> ' || v_ds_etapa,1,4000); 
      DBMS_OUTPUT.PUT_LINE(substr(TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' ) ' ||  p_ds_ddo ,1,2000));
    EXCEPTION
      WHEN OTHERS THEN
	    NULL;
    END;
   

BEGIN

   prc_tempo('INICIO');
  

   
   OPEN c_inf;
   LOOP
    FETCH c_inf INTO v_inf;
    EXIT WHEN c_inf%NOTFOUND;

	-- Inicializacoes  
	-- prc_tempo('1');
	:v_qtd_processados := :v_qtd_processados+1;

	
	UPDATE openrisow.item_nftl_serv inf
		SET inf.VAR05                                           = SUBSTR('r2015_18:' || inf.ESTB_COD || '>>'|| inf.VAR05,1,150)
          , inf.ESTB_COD                                        = '00'
	WHERE rowid = v_inf.rowid_inf;
	:v_qtd_atu_inf     := :v_qtd_atu_inf + 1;
			
   END LOOP;
   CLOSE c_inf;
   
   ${COMMIT};
   prc_tempo('FIM');
   prc_tempo('Processados ${COMMIT} : ' || :v_qtd_processados || ' >> INF : ' || :v_qtd_atu_inf);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      prc_tempo('ERRO : ' || SUBSTR(SQLERRM,1,500) || ' - rowid_inf >> ' || v_inf.rowid_inf);
      :v_msg_erro := SUBSTR(v_ds_etapa || ' >> ' || :v_msg_erro,1,4000);
      :v_st_processamento := 'Erro';
      :exit_code := 1;
END;
/

PROMPT Processado
ROLLBACK;
UPDATE ${TABELA_CONTROLE} cp
   SET cp.dt_fim_proc          = SYSDATE,
       cp.st_processamento     = :v_st_processamento,
       cp.ds_msg_erro          = substr(substr(nvl(:v_msg_erro,' '),1,1000) || ' >> ' || cp.ds_msg_erro ,1,4000),
       cp.qt_atualizados_nf    = NVL(cp.qt_atualizados_nf,0)   + :v_qtd_atu_nf,
       cp.qt_atualizados_inf   = NVL(cp.qt_atualizados_inf,0)  + :v_qtd_atu_inf,
       cp.qt_atualizados_cli   = NVL(cp.qt_atualizados_cli,0)  + :v_qtd_atu_cli,
       cp.qt_atualizados_comp  = NVL(cp.qt_atualizados_comp,0) + :v_qtd_atu_comp--,
 WHERE cp.rowid = '${ROWID_CP}'
   AND cp.st_processamento = 'Em Processamento'
   AND cp.NM_PROCESSO = '${PROCESSO}';
COMMIT;


PROMPT Processado

exit :exit_code;

@EOF

RETORNO=$?

${WAIT}

exit ${RETORNO}

