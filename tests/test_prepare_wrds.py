import unittest
import pandas as pd
from src.common import Audit
from src.prepare_wrds import prepare

class PrepareTests(unittest.TestCase):
    def test_split_suffix_and_point_in_time_mapping(self):
        c=pd.DataFrame(dict(PERMNO=['1','1'],DlyCalDt=['2024-06-07','2024-06-10'],TradingSymbol=['X','X'],SecurityType=['EQTY']*2,SecuritySubType=['COM']*2,ShareType=['NS']*2,USIncFlg=['Y']*2,IssuerType=['CORP']*2,TradingStatusFlg=['A']*2,DlyCumFacPr=['10','1'],DlyOpen=['1000','100'],DlyHigh=['1100','110'],DlyLow=['900','90'],DlyClose=['1000','100'],DlyVol=['100','1000']))
        i=pd.DataFrame(dict(DATE=['2024-06-07']*2,SYM_ROOT=['X']*2,SYM_SUFFIX=[None,'PRA'],EffectiveSpread_Percent_Ave=['0.001','0.1'],symbol=['X','X PRA']))
        a=Audit();out,bench=prepare(c,i,a)
        self.assertEqual(out.close.tolist(),[100,100]);self.assertEqual(out.dollar_volume.tolist(),[100000,100000])
        self.assertEqual(bench.spread.tolist(),['0.001']);self.assertEqual(a.counts[1]['excluded'],1)
        c.loc[0,'DlyCumFacPr']='0'
        with self.assertRaises(ValueError):prepare(c,i,Audit())

    def test_taq_nanoseconds_and_ambiguous_quotes(self):
        from src.prepare_taq import normalize
        m=pd.DataFrame({'permno':['1'],'date':['2024-01-31'],'symbol':['X']})
        q=pd.DataFrame(dict(DATE=['2024-01-31']*2,TIME_M=['9:30:00.123456789']*2,SYM_ROOT=['X']*2,SYM_SUFFIX=[None]*2,source_row=['1','2'],BEST_BID=['99','98'],BEST_ASK=['101']*2,Best_BidSizeShares=['100']*2,Best_AskSizeShares=['100']*2,QU_COND=['R']*2))
        out=normalize(q,'quotes',m,Audit())
        self.assertTrue(out.condition.eq('AMBIGUOUS_TIMESTAMP').all())
        self.assertEqual(out.timestamp.iloc[0].nanosecond,789)
        self.assertEqual(out.timestamp.iloc[0].microsecond,123456)
