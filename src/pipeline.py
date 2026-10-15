"""Run: python -m src.pipeline daily|intraday --config config/local.yaml."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import yaml
import pandas as pd
from .common import ROOT, read, Audit, save, write_json
from .load_crsp import clean_crsp, monthly_edge
from .load_iid import clean_iid
from .build_benchmarks import monthly_benchmark
from .evaluate import daily_comparison, diagnostics, scatter, interval_plot
from .earnings_events import select_events
from .load_taq import match_taq, intraday_results


def file_hash(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):
            h.update(chunk)
    return h.hexdigest()


def validate_config(cfg):
    if pd.Timestamp(cfg['start'])>pd.Timestamp(cfg['end']):
        raise ValueError('start must precede end')
    for section,key in [('crsp','min_coverage'),('iid','min_overlap_fraction'),('taq','min_quote_match_fraction'),('taq','min_bar_trade_fraction')]:
        if not 0<cfg[section][key]<=1:
            raise ValueError(f'{section}.{key} must lie in (0,1]')
    if not 0<cfg['iid']['winsor_quantile']<=1:
        raise ValueError('winsor_quantile must lie in (0,1]')
    if cfg['crsp']['negative_estimates']!='truncate_zero':
        raise ValueError('Only the documented signed-then-truncate-zero convention is implemented')
    for section,key,minimum in [('crsp','min_days',3),('iid','min_days',1),('taq','min_bars',3),('taq','min_trades_per_bar',1)]:
        if not isinstance(cfg[section][key],int) or cfg[section][key]<minimum:
            raise ValueError(f'{section}.{key} must be an integer >= {minimum}')
    if cfg['taq']['max_quote_age_seconds']<=0:
        raise ValueError('max_quote_age_seconds must be positive')
    if cfg['taq']['allow_exact_quote_match'] is not False:
        raise ValueError('Exact-time matching requires source sequence validation; this baseline uses strictly preceding quotes')
    for name,(start,end) in cfg['taq']['windows'].items():
        if not ('09:30'<=start<end<='16:00'):
            raise ValueError(f'Invalid regular-session window {name}')


def run(mode,config_path,output=None):
    config_path=Path(config_path)
    cfg=yaml.safe_load(config_path.read_text());validate_config(cfg)
    out=Path(output) if output else ROOT/cfg['output_dir']/mode
    out=out.resolve()
    # Public repository stores code/simulation only; all licensed derivatives stay ignored.
    private=(ROOT/'private_outputs').resolve()
    if not out.is_relative_to(private):
        raise ValueError('Empirical outputs must be beneath private_outputs/ to avoid public redistribution')
    if out.exists():
        raise ValueError(f'Output already exists: {out}. Choose a new private --output directory to preserve prior evidence.')
    out.mkdir(parents=True)
    audit=Audit();state={'mode':mode,'status':'running','config':cfg,'inputs':{}}
    write_json(state,out/'run_manifest.json')
    def load(name,mapping=None):
        path=(ROOT/cfg['inputs'][name]).resolve()
        data=read(path,mapping)
        state['inputs'][name]={'sha256':file_hash(path),'rows':len(data),'file':path.name}
        return data
    try:
        if mode=='daily':
            crsp=clean_crsp(load('crsp',cfg['crsp']['columns']),cfg['crsp'],cfg['start'],cfg['end'],audit)
            iid=clean_iid(load('iid',cfg['iid']['columns']),cfg['iid'],cfg['start'],cfg['end'],audit)
            edge=monthly_edge(crsp,cfg['crsp']); benchmark=monthly_benchmark(iid,cfg['iid'])
            result=daily_comparison(edge,benchmark,crsp,iid,cfg['iid'])
            save(crsp,out/'crsp_daily_clean.parquet');save(iid,out/'iid_daily_clean.parquet')
            save(crsp[['open','high','low','close','volume','dollar_volume','daily_range']].describe().rename_axis('statistic').reset_index(),out/'descriptive_statistics.csv')
            save(edge,out/'edge_monthly.csv');save(benchmark,out/'benchmark_monthly.csv');save(result,out/'empirical_comparison.csv')
            write_json(diagnostics(result),out/'diagnostics.json');scatter(result,out/'edge_vs_benchmark.png')
            state['usable_pairs']=int(result.matched.sum())
        else:
            events,manifest=select_events(load('events'),load('manifest'),cfg['events'],audit)
            if not manifest.date.between(cfg['start'],cfg['end']).all():
                raise ValueError('Selected sessions must lie within the configured sample period')
            matched=match_taq(load('trades'),load('quotes'),manifest,cfg['taq'],audit)
            bars,result=intraday_results(matched,manifest,cfg['taq'])
            save(events,out/'earnings_events.csv');save(manifest,out/'sample_manifest.csv')
            save(matched,out/'taq_sample_clean.parquet');save(bars,out/'intraday_ohlc.parquet')
            save(result[['permno','date','window','hf_benchmark','arithmetic_hf_spread','n_matched_trades']],out/'intraday_benchmark.csv')
            save(result,out/'extension_results.csv')
            summary=result.loc[result.status=='ok'].groupby(['event_label','window']).agg(
                n_intervals=('absolute_error_bps','size'),median_absolute_error_bps=('absolute_error_bps','median'),
                median_hf_spread=('hf_benchmark','median'),total_trades=('n_trades','sum')).reset_index()
            save(summary,out/'extension_summary.csv');interval_plot(result,out/'intraday_spread_comparison.png')
            state['usable_pairs']=int((result.status=='ok').sum())
        state['status']='complete' if state['usable_pairs'] else 'no_usable_pairs'
        return out,state
    except Exception as e:
        state['status']='failed';state['error']=str(e)
        raise
    finally:
        audit.save(out);write_json(state,out/'run_manifest.json')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=['daily','intraday'])
    parser.add_argument('--config',default=str(ROOT/'config/project_config.yaml'))
    parser.add_argument('--output')
    args=parser.parse_args()
    try:
        out,state=run(args.mode,args.config,args.output)
        print(json.dumps({'output':str(out),'status':state['status'],'usable_pairs':state['usable_pairs']}))
        return 0 if state['status']=='complete' else 2
    except (ValueError,FileNotFoundError,KeyError) as exc:
        print(f'Cannot run: {exc}',file=sys.stderr);return 2


if __name__=='__main__':
    raise SystemExit(main())
