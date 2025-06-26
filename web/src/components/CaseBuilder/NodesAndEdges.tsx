import React from 'react';
import { Position, NodeProps, Handle } from '@xyflow/react';
import styles from './PipelineBlock.module.css';

export interface CustomNodeData {
    label: string;
    type: 'plant' | 'product';
}

export default function CustomNode({ data }: NodeProps<any>) {
  const nodeStyle =
    data.type === 'plant'
      ? styles.PlantNode: styles.ProductNode;
 
  return (
<div className={`${styles.node} ${nodeStyle}`}>
      {data.type === 'plant' && (
<Handle type="target" position={Position.Left} style={{ background: '#555' }} />
      )}
<div>{data.label}</div>
<Handle type="source" position={Position.Right} style={{ background: '#555' }} />
</div>
  );
}; 