"""Independent checks for the documented licensed baseline inputs and outputs."""
from pathlib import Path
import pandas as pd,numpy as np,json
r=Path(__file__).resolve().parents[1]; d=r/'private_outputs/daily'; intr=r/'private_outputs/intraday_verified'
raw=pd.read_csv(r/'data/raw/iid_2024_h1.csv');raw=raw.loc[raw.SYM_SUFFIX.isna()].copy();raw['month']=raw.DATE.str[:7]
ids=pd.read_csv(r/'data/raw/crsp_2024_h1.csv')[['TradingSymbol','DlyCalDt','PERMNO']]
raw=raw.merge(ids,left_on=['SYM_ROOT','DATE'],right_on=['TradingSymbol','DlyCalDt'],validate='one_to_one')
raw['capped']=raw.EffectiveSpread_Percent_Ave
for month,g in raw.groupby('month'):
 cap=np.quantile(g.EffectiveSpread_Percent_Ave,.995,method='linear');raw.loc[g.index,'capped']=np.minimum(g.EffectiveSpread_Percent_Ave,cap)
ref=pd.read_csv(d/'benchmark_monthly.csv')
for row in ref.itertuples():
 g=raw.loc[(raw.PERMNO==row.permno)&(raw.month==row.month),'capped'];expected=np.sqrt(np.dot(g,g)/len(g));assert abs(expected-row.hf_benchmark)<1e-15
comp=pd.read_csv(d/'empirical_comparison.csv');diag=json.loads((d/'diagnostics.json').read_text());assert abs(np.corrcoef(comp.edge_spread,comp.hf_benchmark)[0,1]-diag['pearson_correlation'])<1e-12
assert abs(np.sqrt(np.mean((comp.edge_spread-comp.hf_benchmark)**2))*10000-diag['rmse_bps'])<1e-10
x=pd.read_parquet(intr/'taq_sample_clean.parquet',columns=['permno','timestamp','price','quote_timestamp','bid','ask','quote_matched','effective_spread'])
valid=x.loc[x.quote_matched];assert (valid.quote_timestamp<valid.timestamp).all();assert (valid.timestamp-valid.quote_timestamp).le(pd.Timedelta(seconds=5)).all()
assert np.allclose(valid.effective_spread,2*np.abs(valid.price-(valid.bid+valid.ask)/2)/((valid.bid+valid.ask)/2))
results=pd.read_csv(intr/'extension_results.csv');ok=results.loc[results.status=='ok']
assert len(results)==45 and len(ok)==44 and results.n_valid_bars.eq(30).all()
windows={'open':('09:30','10:00'),'midday':('12:00','12:30'),'close':('15:30','16:00')}
for row in ok.itertuples():
 a,b=[pd.Timestamp(row.date+' '+v,tz='America/New_York') for v in windows[row.window]]
 g=valid.loc[(valid.permno==row.permno)&(valid.timestamp>=a)&(valid.timestamp<b),'effective_spread']
 assert abs(np.sqrt(np.dot(g,g)/len(g))-row.hf_benchmark)<1e-15
# Independent raw-quote timestamp lookup for a deterministic sample of 100 MSFT trades.
q=pd.read_csv(r/'data/raw/event_windows/nbbo_MSFT_20240131_windows.csv')
qt=pd.to_datetime(q.DATE+' '+q.TIME_M.str.strip(),format='%Y-%m-%d %H:%M:%S.%f').dt.tz_localize('America/New_York')
order=np.argsort(qt.array.asi8,kind='stable');q=q.iloc[order].reset_index(drop=True);ns=qt.array.asi8[order]
sample=valid.loc[valid.permno.eq(10107)&valid.timestamp.dt.strftime('%Y-%m-%d').eq('2024-01-31')].sample(100,random_state=7)
for row in sample.itertuples():
 j=np.searchsorted(ns,row.timestamp.value,side='left')-1;assert j>=0
 assert ns[j]==row.quote_timestamp.value
 assert q.BEST_BID.iloc[j]==row.bid and q.BEST_ASK.iloc[j]==row.ask
payload=dict(status='share_with_caveats',monthly_benchmarks_independently_recomputed=30,interval_RMS_independently_recomputed=44,raw_quote_match_spot_checks=100,all_matched_quotes_strictly_preceding=True,all_matched_quotes_within_five_seconds=True,all_45_intervals_have_30_bars=True,excluded_intervals=1,scope='Spot-check raw matching on one stock-day; all saved benchmark formulas checked. No causal or population validation.')
(r/'docs/analysis_validation.json').write_text(json.dumps(payload,indent=2));print(json.dumps(payload))
