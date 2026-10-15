"""Synthetic test fixtures only. None of these observations are research results."""
import copy
import tempfile
import unittest
from pathlib import Path
import numpy as np
import pandas as pd
import yaml
from src.common import ROOT, Audit, sessions, full_session
from src.build_edge import estimate
from src.load_crsp import clean_crsp, monthly_edge
from src.load_iid import clean_iid
from src.build_benchmarks import monthly_benchmark
from src.evaluate import daily_comparison, diagnostics
from src.earnings_events import select_events, link_rdq
from src.load_taq import match_taq, intraday_results
from src.pipeline import run


def config():
    cfg=yaml.safe_load((ROOT/'config/project_config.yaml').read_text())
    cfg['start']='2024-01-01';cfg['end']='2024-01-31'
    for section in ['crsp','iid','taq']:
        cfg[section]['metadata_verified']=True
    cfg['crsp'].update(security_rule='SYNTHETIC test',adjustment_convention='unadjusted synthetic',source='TEST ONLY')
    cfg['iid'].update(field_definition='synthetic percentage spread',source='TEST ONLY',identifier_mapping='synthetic permno',units='percent')
    cfg['iid']['columns']['spread']='spread'
    cfg['taq'].update(source='TEST ONLY',nbbo_definition='synthetic NBBO',identifier_mapping='synthetic permno',condition_rule_source='TEST ONLY',trade_conditions=['R'],trade_corrections=['0'],quote_conditions=['R'])
    cfg['events']['calendar_completeness_verified']=True
    return cfg


def daily_fixture():
    rng=np.random.default_rng(451)
    rows=[]
    for permno in [101,102,103,104,105]:
        for day in sessions('2024-01-01','2024-01-31'):
            prices=100*np.exp(np.cumsum(rng.normal(0,.001,30)))
            rows.append([permno,day.strftime('%Y-%m-%d'),prices[0],max(prices),min(prices),prices[-1],1000,True])
    crsp=pd.DataFrame(rows,columns=['permno','date','open','high','low','close','volume','common_stock'])
    iid=crsp[['permno','date']].copy();iid['spread']=.05+(iid.permno-100)*.01
    return crsp,iid


def intraday_fixture():
    events=pd.DataFrame([['e1',101,'2024-01-10','unknown','TEST ONLY',True]],columns=['event_id','permno','announcement_date','release_timing','source','verified'])
    manifest=pd.DataFrame([[101,'2024-01-10','e1','event_adjacent',True,''],[101,'2024-01-18','e1','control',True,'']],columns=['permno','date','event_id','role','session_reviewed','exclusion_reason'])
    trades=[];quotes=[];rng=np.random.default_rng(887)
    seq=0
    for day in manifest.date:
        for hour in ['09:30','12:00','15:30']:
            start=pd.Timestamp(day+' '+hour,tz='America/New_York')
            for minute in range(30):
                mid=100+float(rng.normal(0,.05))
                for second,sign in [(5,-1),(15,1),(30,-1),(45,1)]:
                    t=start+pd.Timedelta(minutes=minute,seconds=second);seq+=1
                    trades.append([101,t.isoformat(),seq,mid*(1+sign*.0005),100,'R','0'])
                    quotes.append([101,(t-pd.Timedelta(seconds=1)).isoformat(),seq,mid-.05,mid+.05,100,100,'R'])
    trades=pd.DataFrame(trades,columns=['permno','timestamp','sequence','price','size','condition','correction'])
    quotes=pd.DataFrame(quotes,columns=['permno','timestamp','sequence','bid','ask','bid_size','ask_size','condition'])
    return trades,quotes,events,manifest


class PipelineTests(unittest.TestCase):
    def setUp(self):self.cfg=config();self.audit=Audit()

    def test_daily_units_rms_and_month_join(self):
        c,i=daily_fixture();i.loc[0,'spread']=50
        c=clean_crsp(c,self.cfg['crsp'],self.cfg['start'],self.cfg['end'],self.audit)
        i=clean_iid(i,self.cfg['iid'],self.cfg['start'],self.cfg['end'],self.audit)
        self.assertLess(i.adjusted_spread.max(),.5)
        b=monthly_benchmark(i,self.cfg['iid']);e=monthly_edge(c,self.cfg['crsp'])
        self.assertAlmostEqual(b.iloc[0].hf_benchmark,np.sqrt(np.mean(i.loc[i.permno==101].adjusted_spread**2)))
        x=daily_comparison(e,b,c,i,self.cfg['iid'])
        self.assertEqual(diagnostics(x)['matched_stock_months'],5)
        self.assertTrue((x.day_overlap_fraction==1).all())

    def test_bad_ohlc_and_missing_session_are_not_imputed(self):
        c,_=daily_fixture();c.loc[0,'high']=1
        c=clean_crsp(c,self.cfg['crsp'],self.cfg['start'],self.cfg['end'],self.audit)
        x=monthly_edge(c,self.cfg['crsp'])
        self.assertTrue(np.isnan(x.loc[x.permno==101,'edge_spread'].iloc[0]))
        self.assertEqual(x.loc[x.permno==101,'missing_sessions'].iloc[0],1)
        self.assertTrue(any(row['excluded']==1 for row in self.audit.counts))

    def test_duplicates_and_unverified_metadata_stop(self):
        c,_=daily_fixture()
        with self.assertRaisesRegex(ValueError,'duplicate'):
            clean_crsp(pd.concat([c,c.iloc[:1]]),self.cfg['crsp'],self.cfg['start'],self.cfg['end'],self.audit)
        self.cfg['crsp']['metadata_verified']=False
        with self.assertRaisesRegex(ValueError,'Unverified'):
            clean_crsp(c,self.cfg['crsp'],self.cfg['start'],self.cfg['end'],self.audit)

    def test_degenerate_edge_and_calendar(self):
        x=pd.DataFrame({k:[100]*21 for k in ['open','high','low','close']})
        self.assertTrue(np.isnan(estimate(x)))
        self.assertFalse(full_session('2024-11-29'))
        self.assertFalse(full_session('2024-07-04'))
        self.assertTrue(full_session('2024-03-11')) # DST already in effect

    def test_intraday_alignment_rms_and_labels(self):
        t,q,e,m=intraday_fixture()
        _,m=select_events(e,m,self.cfg['events'],self.audit)
        x=match_taq(t,q,m,self.cfg['taq'],self.audit)
        bars,r=intraday_results(x,m,self.cfg['taq'])
        self.assertTrue((x.quote_timestamp<x.timestamp).all())
        self.assertEqual(len(r),6);self.assertEqual(len(bars),180)
        self.assertTrue((r.status=='ok').all())
        np.testing.assert_allclose(r.hf_benchmark,.001,rtol=1e-10)
        self.assertEqual(set(r.event_label),{'earnings-adjacent','control'})
        self.assertTrue((r.n_valid_bars==30).all())

    def test_invalid_quote_barrier_stale_future_and_exact(self):
        t,q,e,m=intraday_fixture();_,m=select_events(e,m,self.cfg['events'],self.audit)
        t=t.iloc[:1].copy();q=q.iloc[:1].copy()
        # Crossed snapshot replaces the good quote before the trade.
        bad=q.copy();bad['timestamp']=(pd.to_datetime(t.timestamp)-pd.Timedelta(milliseconds=500)).astype(str).values
        bad['bid']=102;bad['sequence']=999
        x=match_taq(t,pd.concat([q,bad]),m,self.cfg['taq'],self.audit)
        self.assertFalse(x.quote_matched.iloc[0])
        for shift in [-10,0,1]:
            altered=q.copy();altered['timestamp']=(pd.to_datetime(t.timestamp)+pd.Timedelta(seconds=shift)).astype(str).values
            x=match_taq(t,altered,m,self.cfg['taq'],self.audit)
            self.assertFalse(x.quote_matched.iloc[0])

    def test_missing_bar_and_timezone_guard(self):
        t,q,e,m=intraday_fixture();_,m=select_events(e,m,self.cfg['events'],self.audit)
        t=t.loc[~t.timestamp.str.contains('09:40')]
        x=match_taq(t,q,m,self.cfg['taq'],self.audit);_,r=intraday_results(x,m,self.cfg['taq'])
        self.assertTrue((r.loc[r.window=='open','status']!='ok').all())
        t['timestamp']=pd.to_datetime(t.timestamp).dt.tz_localize(None).astype(str)
        with self.assertRaisesRegex(ValueError,'timezone'):
            match_taq(t,q,m,self.cfg['taq'],self.audit)

    def test_control_buffer_and_ambiguous_ccm(self):
        _,_,e,m=intraday_fixture();m.loc[m.role=='control','date']='2024-01-11'
        with self.assertRaisesRegex(ValueError,'buffer'):
            select_events(e,m,self.cfg['events'],self.audit)
        q=pd.DataFrame({'gvkey':['1'],'rdq':['2024-01-10']})
        l=pd.DataFrame({'gvkey':['1','1'],'lpermno':[101,102],'linkdt':['2020-01-01']*2,'linkenddt':[None]*2,'linktype':['LC']*2,'linkprim':['P']*2})
        with self.assertRaisesRegex(ValueError,'duplicate'):
            link_rdq(q,l)

    def test_end_to_end_private_outputs_and_no_overwrite(self):
        (ROOT/'private_outputs').mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='SYNTHETIC_TEST_',dir=ROOT/'private_outputs') as tmp:
            tmp=Path(tmp);c,i=daily_fixture();t,q,e,m=intraday_fixture()
            for name,frame in [('crsp',c),('iid',i),('trades',t),('quotes',q),('events',e),('manifest',m)]:
                path=tmp/f'{name}.csv';frame.to_csv(path,index=False);self.cfg['inputs'][name]=str(path)
            path=tmp/'config.yaml';path.write_text(yaml.safe_dump(self.cfg))
            out,state=run('daily',path,tmp/'daily');self.assertEqual(state['usable_pairs'],5)
            self.assertTrue((out/'crsp_daily_clean.parquet').exists())
            out,state=run('intraday',path,tmp/'intraday');self.assertEqual(state['usable_pairs'],6)
            self.assertTrue((out/'intraday_spread_comparison.png').exists())
            with self.assertRaisesRegex(ValueError,'already exists'):run('daily',path,tmp/'daily')
            with self.assertRaisesRegex(ValueError,'private_outputs'):run('daily',path,ROOT/'outputs/not_allowed')


if __name__=='__main__':unittest.main()
