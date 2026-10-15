"""Verified event/session selection. RDQ alone never implies an intraday release time."""
import pandas as pd
from .common import require, dates, identifiers, unique, full_session, sessions


def select_events(events, manifest, cfg, audit):
    require(events,['event_id','permno','announcement_date','release_timing','source','verified'],'events')
    require(manifest,['permno','date','event_id','role','session_reviewed','exclusion_reason'],'manifest')
    events=dates(identifiers(events),'announcement_date')
    manifest=dates(identifiers(manifest))
    unique(events,['event_id'],'events')
    unique(manifest,['permno','date'],'manifest')
    if not events.verified.astype(str).str.lower().isin(['true','1']).all() or events.source.fillna('').str.strip().eq('').any():
        raise ValueError('Every earnings date needs a verified source')
    if not events.release_timing.isin(['before_open','during_session','after_close','unknown']).all():
        raise ValueError('Invalid release_timing; use unknown for RDQ-only dates')
    if cfg['calendar_completeness_verified'] is not True:
        raise ValueError('Verify the earnings calendar covers the sample and control buffer before labeling controls')
    if not manifest.role.isin(['event_adjacent','control']).all():
        raise ValueError('Manifest roles must be event_adjacent or control')
    if not manifest.session_reviewed.astype(str).str.lower().isin(['true','1']).all():
        raise ValueError('Review full-session coverage and severe halts for every selected stock-day')
    manifest=audit.keep(manifest,manifest.exclusion_reason.fillna('').str.strip().eq(''),'manifest','reviewed_session_exclusion')
    manifest=audit.keep(manifest,manifest.date.map(full_session),'manifest','non_session_or_half_day')
    joined=manifest.merge(events,on=['event_id','permno'],how='left',validate='many_to_one',indicator=True)
    if (joined._merge!='both').any():
        raise ValueError('Manifest event_id and permno must match a verified event')
    for row in joined.itertuples():
        lo,hi=sorted([row.date,row.announcement_date])
        distance=max(0,len(sessions(lo,hi))-1)
        if row.role=='event_adjacent' and distance>2:
            raise ValueError('Event-adjacent session is more than two exchange sessions from announcement')
        if row.role=='control':
            if distance>cfg['max_control_distance_sessions']:
                raise ValueError('Control exceeds configured session distance')
            for day in events.loc[events.permno==row.permno,'announcement_date']:
                lo,hi=sorted([row.date,day])
                if max(0,len(sessions(lo,hi))-1)<=cfg['control_event_buffer_sessions']:
                    raise ValueError('Control falls within the earnings exclusion buffer')
    for event_id,g in joined.groupby('event_id'):
        if set(g.role)!= {'event_adjacent','control'}:
            raise ValueError(f'{event_id}: need both an event-adjacent session and a control')
    joined['event_label']=joined.role.map({'event_adjacent':'earnings-adjacent','control':'control'})
    return events,joined.drop(columns='_merge')


def link_rdq(quarters, links):
    """CCM LC/LU primary P/C links, point-in-time validity, rejecting ambiguous matches."""
    require(quarters,['gvkey','rdq'],'Compustat')
    require(links,['gvkey','lpermno','linkdt','linkenddt','linktype','linkprim'],'CCM')
    q=quarters.copy(); q['gvkey']=q.gvkey.astype(str).str.zfill(6)
    l=links.copy(); l['gvkey']=l.gvkey.astype(str).str.zfill(6)
    q['rdq']=pd.to_datetime(q.rdq,errors='raise')
    l['linkdt']=pd.to_datetime(l.linkdt,errors='raise')
    l['linkenddt']=pd.to_datetime(l.linkenddt,errors='raise').fillna(pd.Timestamp('2099-12-31'))
    l=l.loc[l.linktype.isin(['LC','LU']) & l.linkprim.isin(['P','C'])]
    x=q.merge(l,on='gvkey',how='left')
    x=x.loc[x.rdq.between(x.linkdt,x.linkenddt)].rename(columns={'lpermno':'permno'})
    unique(x,['gvkey','rdq'],'CCM event match')
    return identifiers(x)
