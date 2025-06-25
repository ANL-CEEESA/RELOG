import React from 'react';
import { Position, NodeProps, Handle } from '@xyflow/react';

export interface CustomNodeData {
    label: string;
    type: 'plant' | 'product';
}

export default function CustomNode({ data }: NodeProps<any>) {
  const nodeStyle =
    data.type === 'plant'
      ? { background: '#b0e0e6', padding: 10, borderRadius: 5 }
      : { background: '#ffd700', padding: 10, borderRadius: 5 };
 
  return (
<div style={nodeStyle}>
<Handle type="target" position={Position.Left} style={{ background: '#555' }} />
<div>{data.label}</div>
<Handle type="source" position={Position.Right} style={{ background: '#555' }} />
</div>
  );
}; 