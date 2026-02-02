import React, { useMemo, useState } from "react";
import { getLogoCandidates, initialsFor } from "../lib/logoUtil.js";
export default function Logo({ monitor, size=20, className="k-logo", href }) {
  const candidates = useMemo(()=>getLogoCandidates(monitor), [monitor]);
  const [idx, setIdx] = useState(0);
  const Img = (
    <img className={className} style={{width:size,height:size}}
         src={candidates[idx] || ""} alt=""
         onError={()=> setIdx(i => i+1)} />
  );
  const Fallback = (
    <div className={className+" k-logo--fallback"} style={{width:size,height:size}}>
      {initialsFor(monitor)}
    </div>
  );
  const content = (idx < candidates.length) ? Img : Fallback;
  if (href) return <a href={href} target="_blank" rel="noopener noreferrer" onClick={(e)=>e.stopPropagation()}>{content}</a>;
  return content;
}
