import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def daily_comparison(edge,benchmark,crsp,iid,cfg):
    x=edge.merge(benchmark,on=['permno','month'],how='outer',validate='one_to_one',indicator=True)
    common=crsp[['permno','date','month']].merge(iid[['permno','date']],on=['permno','date'],validate='one_to_one')
    counts=common.groupby(['permno','month']).size().rename('n_common_days').reset_index()
    x=x.merge(counts,on=['permno','month'],how='left',validate='one_to_one')
    x['n_common_days']=x.n_common_days.fillna(0).astype(int)
    x['day_overlap_fraction']=x.n_common_days/x[['n_ohlc_days','n_benchmark_days']].max(axis=1)
    x['matched']=(x._merge=='both') & np.isfinite(x.edge_spread) & np.isfinite(x.hf_benchmark) & (x.day_overlap_fraction>=cfg['min_overlap_fraction'])
    return x


def diagnostics(frame):
    x=frame.loc[frame.matched]
    n=len(x)
    corr=x.edge_spread.corr(x.hf_benchmark) if n>=3 and x.edge_spread.nunique()>1 and x.hf_benchmark.nunique()>1 else np.nan
    return {'matched_stock_months':n,'total_stock_months':len(frame),
            'pearson_correlation':float(corr) if np.isfinite(corr) else None,
            'rmse_bps':float(np.sqrt(np.mean((x.edge_spread-x.hf_benchmark)**2))*10000) if n else None,
            'scope':'Descriptive pilot; linear-spread RMSE, not paper log-spread RMSE.'}


def scatter(frame,path):
    x=frame.loc[frame.matched]
    fig,ax=plt.subplots(figsize=(6,5),layout='constrained')
    ax.scatter(x.hf_benchmark*10000,x.edge_spread*10000,alpha=.75)
    limit=max(x[['hf_benchmark','edge_spread']].max().max()*10000,1) if len(x) else 1
    ax.plot([0,limit],[0,limit],color='gray',linestyle='--')
    ax.set(xlabel='Monthly HF benchmark (bps)',ylabel='Monthly EDGE (bps)',title=f'Matched stock-months: {len(x)}')
    fig.savefig(path,dpi=180);plt.close(fig)


def interval_plot(frame,path):
    fig,ax=plt.subplots(figsize=(7,4),layout='constrained')
    order=['open','midday','close']
    for label,g in frame.loc[frame.status=='ok'].groupby('event_label'):
        med=g.groupby('window').absolute_error_bps.median().reindex(order)
        ax.plot(order,med,marker='o',label=label)
    ax.set(ylabel='Median absolute error (bps)',title='Interval EDGE vs matched RMS effective spread')
    if ax.lines: ax.legend()
    fig.savefig(path,dpi=180);plt.close(fig)
