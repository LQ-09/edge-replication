"""Point-in-time NBBO matching; invalid quote updates remain barriers to stale quotes."""
import numpy as np
import pandas as pd
from .common import require, identifiers, unique, verified
from .build_edge import estimate


def timestamps(frame,label):
    frame=identifiers(frame)
    values=pd.to_datetime(frame.timestamp,errors='raise',format='mixed')
    # Reject naive timestamps: guessing UTC/ET shifts the research windows.
    if not isinstance(values.dtype,pd.DatetimeTZDtype):
        raise ValueError(f'{label}: timestamps must carry one explicit timezone/UTC offset')
    frame['timestamp']=values.dt.tz_convert('America/New_York')
    frame['date']=frame.timestamp.dt.tz_localize(None).dt.normalize()
    frame['sequence']=pd.to_numeric(frame.sequence,errors='raise')
    if frame.sequence.isna().any() or not np.isfinite(frame.sequence).all():
        raise ValueError(f'{label}: missing/invalid sequence')
    unique(frame,['permno','date','timestamp','sequence'],label)
    return frame.sort_values(['permno','timestamp','sequence'])


def match_taq(trades,quotes,manifest,cfg,audit):
    verified(cfg,['source','nbbo_definition','identifier_mapping','condition_rule_source'])
    if any(not cfg[k] for k in ['trade_conditions','trade_corrections','quote_conditions']):
        raise ValueError('Explicit verified condition and correction code allowlists are required')
    require(trades,['permno','timestamp','sequence','price','size','condition','correction'],'trades')
    require(quotes,['permno','timestamp','sequence','bid','ask','bid_size','ask_size','condition'],'NBBO quotes')
    trades=timestamps(trades,'trades'); quotes=timestamps(quotes,'quotes')
    keys=manifest[['permno','date']]
    selected=pd.MultiIndex.from_frame(keys)
    trades=audit.keep(trades,pd.MultiIndex.from_frame(trades[['permno','date']]).isin(selected),'trades','outside_selected_sessions')
    quotes=audit.keep(quotes,pd.MultiIndex.from_frame(quotes[['permno','date']]).isin(selected),'quotes','outside_selected_sessions')
    trades[['price','size']]=trades[['price','size']].apply(pd.to_numeric,errors='coerce')
    valid=np.isfinite(trades[['price','size']]).all(axis=1) & (trades.price>0) & (trades['size']>0)
    valid &= trades.condition.astype(str).isin(cfg['trade_conditions']) & trades.correction.astype(str).isin(cfg['trade_corrections'])
    trades=audit.keep(trades,valid,'trades','invalid_price_size_condition_or_correction')
    tod=trades.timestamp.dt.strftime('%H:%M:%S')
    trades=audit.keep(trades,(tod>='09:30:00') & (tod<'16:00:00'),'trades','outside_regular_session')
    cols=['bid','ask','bid_size','ask_size']
    quotes[cols]=quotes[cols].apply(pd.to_numeric,errors='coerce')
    quotes['quote_valid']=np.isfinite(quotes[cols]).all(axis=1) & (quotes[cols]>0).all(axis=1) & (quotes.ask>quotes.bid)
    quotes['quote_valid'] &= quotes.condition.astype(str).isin(cfg['quote_conditions'])
    # Audit invalid snapshots, but do not remove them: a crossed update invalidates the old NBBO.
    audit.keep(quotes,quotes.quote_valid,'quotes','invalid_nbbo_snapshot_retained_as_barrier')
    result=[]
    for (permno,day),t in trades.groupby(['permno','date'],sort=True):
        q=quotes.loc[(quotes.permno==permno)&(quotes.date==day)].sort_values(['timestamp','sequence'])
        q=q.drop_duplicates('timestamp',keep='last').rename(columns={'timestamp':'quote_timestamp'})
        q=q[['quote_timestamp','bid','ask','bid_size','ask_size','quote_valid']]
        x=pd.merge_asof(t.sort_values(['timestamp','sequence']),q,left_on='timestamp',right_on='quote_timestamp',
                        direction='backward',allow_exact_matches=cfg['allow_exact_quote_match'],
                        tolerance=pd.Timedelta(seconds=cfg['max_quote_age_seconds']))
        x['quote_matched']=x.quote_valid.eq(True)
        x['quote_age_seconds']=(x.timestamp-x.quote_timestamp).dt.total_seconds()
        midpoint=(x.bid+x.ask)/2
        x['effective_spread']=(2*(x.price-midpoint).abs()/midpoint).where(x.quote_matched)
        result.append(x)
    if not result:
        raise ValueError('No valid trades in selected full sessions; inspect exclusions')
    result=pd.concat(result,ignore_index=True)
    audit.keep(result,result.quote_matched,'quote_match','missing_stale_or_invalid_nbbo')
    return result


def intraday_results(trades,manifest,cfg):
    bars_all=[]; rows=[]
    for session in manifest.itertuples():
        t=trades.loc[(trades.permno==session.permno)&(trades.date==session.date)]
        for window,(start,end) in cfg['windows'].items():
            a=pd.Timestamp(f'{session.date.date()} {start}',tz='America/New_York')
            b=pd.Timestamp(f'{session.date.date()} {end}',tz='America/New_York')
            g=t.loc[(t.timestamp>=a)&(t.timestamp<b)].copy()
            g['minute']=g.timestamp.dt.floor('min')
            bars=g.groupby('minute',sort=True).agg(open=('price','first'),high=('price','max'),low=('price','min'),
                                                   close=('price','last'),n_trades=('price','size'),volume=('size','sum')).reset_index()
            bars['valid_bar']=bars.n_trades>=cfg['min_trades_per_bar']
            bars['permno']=session.permno;bars['date']=session.date;bars['window']=window
            bars_all.append(bars)
            valid=bars.loc[bars.valid_bar]
            sample=g.loc[g.minute.isin(valid.minute)]
            matched=sample.loc[sample.quote_matched]
            fraction=len(matched)/len(sample) if len(sample) else 0.
            bar_fraction=len(sample)/len(g) if len(g) else 0.
            # Do not silently compress holes into adjacent 1-minute observations.
            contiguous=len(valid)>0 and valid.minute.diff().dropna().eq(pd.Timedelta(minutes=1)).all()
            sufficient=len(valid)>=cfg['min_bars'] and contiguous and fraction>=cfg['min_quote_match_fraction'] and bar_fraction>=cfg['min_bar_trade_fraction']
            edge=estimate(valid,cfg['min_bars']) if sufficient else np.nan
            hf=np.sqrt(np.mean(matched.effective_spread**2)) if sufficient and len(matched) else np.nan
            status='ok' if np.isfinite(edge) and np.isfinite(hf) else 'insufficient_coverage_or_undefined'
            rows.append(dict(permno=session.permno,date=session.date,window=window,event_id=session.event_id,event_label=session.event_label,
                edge_spread=edge,hf_benchmark=hf,arithmetic_hf_spread=matched.effective_spread.mean() if len(matched) else np.nan,
                absolute_error_bps=10000*abs(edge-hf),n_trades=len(g),n_estimation_trades=len(sample),n_matched_trades=len(matched),
                volume=g['size'].sum(),n_valid_bars=len(valid),expected_bars=int((b-a)/pd.Timedelta(minutes=1)),
                quote_match_fraction=fraction,bar_trade_fraction=bar_fraction,contiguous_bars=contiguous,status=status))
    return pd.concat(bars_all,ignore_index=True),pd.DataFrame(rows)
