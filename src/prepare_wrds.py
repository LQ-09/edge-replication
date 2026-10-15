"""Normalize the documented CRSP CIZ and WRDS millisecond IID web extracts.

python -m src.prepare_wrds --crsp data/raw/crsp_2024_h1.csv --iid data/raw/iid_2024_h1.csv
"""
import argparse
import numpy as np
import pandas as pd
from .common import ROOT, require, unique, Audit, write_json


def prepare(crsp, iid, audit):
    require(crsp, ['PERMNO','DlyCalDt','TradingSymbol','SecurityType','SecuritySubType',
                  'ShareType','USIncFlg','IssuerType','TradingStatusFlg','DlyCumFacPr',
                  'DlyOpen','DlyHigh','DlyLow','DlyClose','DlyVol'], 'CRSP CIZ')
    require(iid, ['DATE','SYM_ROOT','SYM_SUFFIX','EffectiveSpread_Percent_Ave'], 'WRDS IID')
    unique(crsp, ['PERMNO','DlyCalDt'], 'CRSP CIZ')
    crsp=crsp.copy()
    eligible=(crsp.SecurityType.eq('EQTY') & crsp.SecuritySubType.eq('COM') &
              crsp.ShareType.eq('NS') & crsp.USIncFlg.eq('Y') &
              crsp.IssuerType.eq('CORP') & crsp.TradingStatusFlg.eq('A'))
    crsp=audit.keep(crsp,eligible,'prepare_crsp','not_active_us_common_share')
    factor=pd.to_numeric(crsp.DlyCumFacPr, errors='raise')
    if not (np.isfinite(factor) & factor.gt(0)).all():
        raise ValueError('Missing or nonpositive cumulative price factor')
    mapping=crsp[['PERMNO','DlyCalDt','TradingSymbol']].rename(
        columns={'PERMNO':'permno','DlyCalDt':'date','TradingSymbol':'symbol'})
    unique(mapping,['symbol','date'],'point-in-time symbol mapping')
    out=mapping.copy()
    for dest,source in [('open','DlyOpen'),('high','DlyHigh'),('low','DlyLow'),('close','DlyClose')]:
        out[dest]=pd.to_numeric(crsp[source],errors='raise')/factor
    out['volume']=pd.to_numeric(crsp.DlyVol,errors='raise')
    # Keep actual dollar turnover even though estimator prices are split adjusted.
    out['dollar_volume']=pd.to_numeric(crsp.DlyClose,errors='raise')*out.volume
    out['common_stock']=True
    iid=audit.keep(iid, iid.SYM_SUFFIX.fillna('').str.strip().eq(''),
                   'prepare_iid','nonblank_security_suffix')
    iid=iid[['DATE','SYM_ROOT','EffectiveSpread_Percent_Ave']].rename(
        columns={'DATE':'date','SYM_ROOT':'symbol','EffectiveSpread_Percent_Ave':'spread'})
    unique(iid,['symbol','date'],'IID common shares')
    iid=iid.merge(mapping,on=['symbol','date'],how='left',validate='one_to_one',indicator=True)
    iid=audit.keep(iid,iid._merge.eq('both'),'prepare_iid','no_crsp_symbol_date_match')
    return out, iid[['permno','date','symbol','spread']]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--crsp',required=True);p.add_argument('--iid',required=True)
    p.add_argument('--output',default='data/prepared')
    args=p.parse_args();out=(ROOT/args.output).resolve()
    if not out.is_relative_to((ROOT/'data').resolve()) or out.exists():
        raise ValueError('Choose a new output directory under data/')
    crsp=pd.read_csv(ROOT/args.crsp,dtype=str);iid=pd.read_csv(ROOT/args.iid,dtype=str)
    audit=Audit();c,i=prepare(crsp,iid,audit)
    out.mkdir(parents=True);c.to_csv(out/'crsp.csv',index=False);i.to_csv(out/'iid.csv',index=False)
    audit.save(out)
    from .pipeline import file_hash
    write_json({'crsp':{'file':args.crsp,'sha256':file_hash(ROOT/args.crsp),'rows':len(crsp)},
                'iid':{'file':args.iid,'sha256':file_hash(ROOT/args.iid),'rows':len(iid)},
                'output_rows':{'crsp':len(c),'iid':len(i)}},out/'source_manifest.json')


if __name__=='__main__':
    main()
