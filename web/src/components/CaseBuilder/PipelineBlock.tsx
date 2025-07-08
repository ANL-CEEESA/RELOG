import React, { useEffect, useCallback } from 'react';
import dagre from 'dagre';
import {
  ReactFlow,
  Background,
  Controls,
  Node,
  Edge,
  Connection,
  MarkerType
} from '@xyflow/react';
import { CircularPlant, CircularProduct, CircularCenter } from './CircularData';
import CustomNode, { CustomNodeData } from './NodesAndEdges';
import Section from '../Common/Section';
import Card from '../Common/Card';
import styles from './PipelineBlock.module.css';


interface PipelineBlockProps {
  onAddPlant: () => void;
  onAddProduct: () => void;
  onAddCenter: () => void;
  onMovePlant: (name: string, x: number, y: number) => void;
  onMoveProduct: (name: string, x: number, y: number) => void;
  onMoveCenter: (name: string, x: number, y: number) => void;
  onSetPlantInput: (plantName: string, productName: string) => void;
  onAddPlantOutput: (plantName: string, productName: string) => void;
  onAddCenterInput: (centerName: string, productName: string) => void;
  onAddCenterOutput: (centerName: string, productName: string) => void;
  onRemovePlant: (id: string) => void;
  onRemoveProduct: (id: string) => void;
  onRemoveCenter: (id: string) => void;
  onRenameProduct: (prevName: string, newName: string) => void;
  onRenamePlant: (prevName: string, newName: string) => void;
  onRenameCenter: (prevName: string, newName: string) => void;
  products: Record<string, CircularProduct>;
  plants: Record<string, CircularPlant>;
  centers: Record<string, CircularCenter>;
}

function getLayoutedNodesAndEdges(
  nodes: Node<CustomNodeData>[],
  edges: Edge[]
): { nodes: Node<CustomNodeData>[]; edges: Edge[] } {
  const NODE_WIDTH = 125;
  const NODE_HEIGHT = 45;
  const g = new dagre.graphlib.Graph();
  g.setDefaultEdgeLabel(() => ({}));
  g.setGraph({ rankdir: 'LR' });
  nodes.forEach(n => g.setNode(n.id, { width: NODE_WIDTH, height: NODE_HEIGHT }));
  edges.forEach(e => g.setEdge(e.source, e.target));
  dagre.layout(g);
  const layouted = nodes.map(n => {
    const d = g.node(n.id)!;
    return {
      ...n,
      position: {
        x: d.x - NODE_WIDTH / 2,
        y: d.y - NODE_HEIGHT / 2
      }
    };
  });
  return { nodes: layouted, edges };
}


const PipelineBlock: React.FC<PipelineBlockProps> = props => {
  const nodes: Node<CustomNodeData>[] = [];
  const edges: Edge[] = [];
  const mapNameToType: Record<string, 'plant' | 'product' | 'center'> = {};
  let hasNullPositions = false;
  Object.entries(props.products).forEach(([key, product]) => {
    if (!product.x || !product.y) hasNullPositions = true;
    mapNameToType[key] = 'product';
    nodes.push({
      id: product.uid,
      type: 'default',
      data: { label: product.name, type: 'product' },
      position: { x: product.x, y: product.y },
      className: 'ProductNode'
    });
  });
  Object.entries(props.plants).forEach(([key, plant]) => {
    if (!plant.x || !plant.y) hasNullPositions = true;
    mapNameToType[key] = 'plant';
    nodes.push({
      id: plant.uid,
      type: 'default',
      data: { label: plant.name, type: 'plant' },
      position: { x: plant.x, y: plant.y },
      className: 'PlantNode'
    });
    plant.inputs.forEach(input => {
      edges.push({
        id: `${input}-${key}-in`,
        source: input,
        target: key,
        animated: true,
        style: { stroke: 'black' },
        markerEnd: { type: MarkerType.ArrowClosed }
      });
    });
    plant.outputs.forEach(output => {
      edges.push({
        id: `${key}-${output}-out`,
        source: key,
        target: output,
        animated: true,
        style: { stroke: 'black' },
        markerEnd: { type: MarkerType.ArrowClosed }
      });
    });
  });
  Object.entries(props.centers).forEach(([key, center]) => {
    if (!center.x || !center.y) hasNullPositions = true;
    mapNameToType[key] = 'center';
    nodes.push({
      id: center.uid,
      type: 'default',
      data: { label: center.name, type: 'center' },
      position: { x: center.x, y: center.y },
      className: 'CenterNode'
    });
    if (center.input) {
      edges.push({
        id: `${center.input}-${key}-in`,
        source: center.input,
        target: key,
        animated: true,
        style: { stroke: 'black' },
        markerEnd: { type: MarkerType.ArrowClosed }
      });
    }
    center.output.forEach(out => {
      edges.push({
        id: `${key}-${out}-out`,
        source: key,
        target: out,
        animated: true,
        style: { stroke: 'black' },
        markerEnd: { type: MarkerType.ArrowClosed }
      });
    });
  });
  const onConnect = (params: Connection) => {
    const { source, target } = params;
    if (!source || !target) return;
    const sourceType = mapNameToType[source];
    const targetType = mapNameToType[target];
    if (sourceType === 'product' && targetType === 'plant') props.onSetPlantInput(target, source);
    else if (sourceType === 'plant' && targetType === 'product') props.onAddPlantOutput(source, target);
    else if (sourceType === 'product' && targetType === 'center') props.onAddCenterInput(target, source);
    else if (sourceType === 'center' && targetType === 'product') props.onAddCenterOutput(source, target);
  };

  const onNodeDragStop = (_: any, node: Node<CustomNodeData>) => {
    const { id, position, data } = node;
    if (data.type === 'plant') props.onMovePlant(id, position.x, position.y);
    if (data.type === 'product') props.onMoveProduct(id, position.x, position.y);
    if (data.type === 'center') props.onMoveCenter(id, position.x, position.y);
  };

  const handleNodesDelete = useCallback(
    (deleted: Node<CustomNodeData>[]) => {
      deleted.forEach(n => {
        const type = mapNameToType[n.id];
        if (type === 'plant') props.onRemovePlant(n.id);
        else if (type === 'product') props.onRemoveProduct(n.id);
        else if (type === 'center') props.onRemoveCenter(n.id);
      });
    },
    [props]
  );

  const onNodeDoubleClick = (ev: React.MouseEvent, node: Node<CustomNodeData>) => {
    const oldName = node.data.label;
    const newName = window.prompt("Enter new name", oldName);
    if (!newName|| newName.trim().length === 0) return;
    if (newName in mapNameToType) return;
    if (node.data.type === "plant") {
      props.onRenamePlant(oldName, newName);
    } else if (node.data.type === "product") {
      props.onRenameProduct(oldName, newName);
    }
    else if (node.data.type === "center") {
      props.onRenameCenter(oldName, newName);
    }
  };

  const onLayout = () => {
    const { nodes: ln, edges: le } = getLayoutedNodesAndEdges(nodes, edges);
    ln.forEach(n => {
      const { id, position, data } = n;
      if (data.type === 'plant') props.onMovePlant(id, position.x, position.y);
      else if (data.type === 'product') props.onMoveProduct(id, position.x, position.y);
      else props.onMoveCenter(id, position.x, position.y);
    });
  };

  useEffect(() => {
    if (hasNullPositions) onLayout();
  }, [hasNullPositions]);

  return (
    <>
      <Section title="Pipeline" />
      <Card>
        <div className={styles.PipelineBlock}>
          <ReactFlow
            nodes={nodes}
            edges={edges}
            onConnect={onConnect}
            onNodeDoubleClick={onNodeDoubleClick}
            onNodeDragStop={onNodeDragStop}
            onNodesDelete={handleNodesDelete}
            deleteKeyCode="delete"
            maxZoom={1.25}
            minZoom={0.5}
            snapToGrid
            preventScrolling
            nodeTypes={{ default: CustomNode }}
          >
            <Background />
            <Controls showInteractive={false} />
          </ReactFlow>
        </div>
        <div style={{ textAlign: 'center', marginTop: '1rem' }}>
          <button style={{ margin: '0 8px' }} onClick={props.onAddProduct}>
            Add product
          </button>
          <button style={{ margin: '0 8px' }} onClick={props.onAddPlant}>
            Add plant
          </button>
          <button style={{ margin: '0 8px' }} onClick={props.onAddCenter}>
            Add center
          </button>
          <button style={{ margin: '0 8px' }} onClick={onLayout}>
            Auto Layout
          </button>
          <button
            style={{ margin: '0 8px' }}
            title="Drag from one connector to another to create links. Double click to rename. Click to move. Press Delete to remove."
          >
            ?
          </button>
        </div>
      </Card>
    </>
  );
};
export default PipelineBlock;
 