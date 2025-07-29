// NodesAndEdges.tsx

import React from 'react';

import { Handle, Position, NodeProps } from '@xyflow/react';

import styles from './PipelineBlock.module.css';
 
export interface CustomNodeData {

  [key:string]: unknown;
  
  label: string;

  type: 'plant' | 'product' | 'center';

}
 

export default function CustomNode({ data, isConnectable }: NodeProps<Node<CustomNodeData>>) {
  const typeClass =
    data.type === 'plant'   ? styles.PlantNode  :
    data.type === 'product' ? styles.ProductNode:
                              styles.CenterNode;
 
  return (
<div className={`${styles.node} ${typeClass}`}>
<Handle

        type="target"

        position={Position.Left}

        isConnectable={isConnectable}

        style={{ background: '#555' }}

      />
 
      <div>{data.label}</div>
 
<Handle

        type="source"

        position={Position.Right}

        isConnectable={isConnectable}

        style={{ background: '#555' }}

      />
</div>

  );

}

 