import React, { useMemo } from "react";
import ServiceCard from "./ServiceCard.jsx";
import History from "../historyEngine.js";
function groupByInstance(list=[]){ const map=new Map(); for (const m of list){ const g=map.get(m.instance)||[]; g.push(m); map.set(m.instance,g);} return map; }
function metricsFor(g=[]){ const up=g.filter(m=>m.latest?.status===1).length; const down=g.filter(m=>m.latest?.status===0).length; const total=g.length;
  const rts=g.map(m=>m.latest?.responseTime).filter(v=>v!=null); const avg=rts.length?Math.round(rts.reduce((a,b)=>a+b,0)/rts.length):null; return {up,down,total,avg}; }
export default function ServiceGrid({ monitorsAll=[], hiddenSet=new Set(), onHideAll, onUnhideAll, onOpen }) {
  const groups = useMemo(()=>groupByInstance(monitorsAll), [monitorsAll]);
  const items=[]; for (const [instance, arr] of groups.entries()) items.push({ instance, data: metricsFor(arr) });
  items.sort((a,b)=>a.instance.localeCompare(b.instance));
  return (
    <div className="grid">
      {items.map(({instance, data})=>{
        const spark = History.getAvgSeriesByInstance(instance);
        return <ServiceCard key={instance} sede={instance} data={data} spark={spark}
                 onOpen={()=>onOpen?.(instance)}
                 onHideAll={()=>onHideAll?.(instance)}
                 onUnhideAll={()=>onUnhideAll?.(instance)} />;
      })}
    </div>
  );
}
